import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/services.dart';
import 'package:googlecast/CastController.dart';
import 'package:googlecast/googlecast.dart';
import 'package:intl/intl.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'db_helper.dart';
import 'prayer_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// TOP-LEVEL background callback — must be a plain static/free function so
// Flutter can invoke it in a background isolate when a notification fires.
// This is the ONLY way to auto-trigger Cast when a scheduled notification
// is delivered (not just tapped).
// ─────────────────────────────────────────────────────────────────────────────
@pragma('vm:entry-point')
Future<void> onDidReceiveBackgroundNotificationResponse(
  NotificationResponse response,
) async {
  // Re-initialise timezone data because this runs in a fresh isolate.
  tz.initializeTimeZones();
  await NotificationService.instance._triggerNetworkSpeakerIfConfigured(
    payload: response.payload,
  );
}

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  static const int _batchDays = 3;
  static const String _batchEndKey = 'notification_batch_end';
  static const String _lastLatKey = 'notification_last_lat';
  static const String _lastLngKey = 'notification_last_lng';
  static const String _speakerRouteKey = 'notification_speaker_route';
  static const String googleCastMediaUrlKey = 'google_cast_media_url';
  static const List<String> _supportedPrayers = [
    'Fajr',
    'Dhuhr',
    'Asr',
    'Maghrib',
    'Isha',
  ];

  static const String _toneBeep = 'Beep';
  static const String _toneMuezzin1 = 'Muezzin Voice 1';
  static const String _toneMuezzin2 = 'Muezzin Voice 2';
  static const String toneCustomFile = 'Custom File';
  static const String speakerPhoneSpeaker = 'Phone Speaker (Alarm Stream)';
  static const String speakerGoogleCast = 'Google/Chromecast Speaker';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  AudioPlayer? _testAudioPlayer;
  HttpServer? _castToneServer;
  InternetAddress? _castToneServerAddress;
  int _castToneTokenSeed = 0;
  final Map<String, _ServedCastTone> _servedCastTones = {};

  bool _initialized = false;

  // ───────────────────────────────────────────────────────────────────────────
  // Initialisation
  // ───────────────────────────────────────────────────────────────────────────

  Future<void> initialize() async {
    if (kIsWeb || _initialized) return;

    tz.initializeTimeZones();

    const androidInit = AndroidInitializationSettings('@mipmap/launcher_icon');
    const iosInit = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );

    await _plugin.initialize(
      initSettings,
      // Foreground tap handler (user manually taps the notification).
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        _triggerNetworkSpeakerIfConfigured(payload: response.payload);
      },
      // *** KEY FIX #1 ***
      // Background delivery handler — fires automatically when a scheduled
      // notification is delivered, even while the app is terminated.
      // Must point at the top-level function defined above.
      onDidReceiveBackgroundNotificationResponse:
          onDidReceiveBackgroundNotificationResponse,
    );

    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    await androidPlugin?.requestNotificationsPermission();
    await androidPlugin?.requestExactAlarmsPermission();
    await _ensureAndroidToneChannels();

    _initialized = true;
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Android notification channels
  // ───────────────────────────────────────────────────────────────────────────

  static const int _channelVersion = 3;
  static const String _channelVersionKey = 'notification_channel_version';

  Future<void> _ensureAndroidToneChannels() async {
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin == null) return;

    final storedVersion = int.tryParse(
      await DBHelper.getSetting(_channelVersionKey) ?? '',
    );

    const channels = [
      AndroidNotificationChannel(
        'athan_tone_beep',
        'Athan Tone: Beep',
        description: 'Prayer reminders with Beep tone',
        importance: Importance.max,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('athan_beep'),
      ),
      AndroidNotificationChannel(
        'athan_tone_muezzin_1',
        'Athan Tone: Muezzin Voice 1',
        description: 'Prayer reminders with Muezzin Voice 1 tone',
        importance: Importance.max,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('athan_muezzin_1'),
      ),
      AndroidNotificationChannel(
        'athan_tone_muezzin_2',
        'Athan Tone: Muezzin Voice 2',
        description: 'Prayer reminders with Muezzin Voice 2 tone',
        importance: Importance.max,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('athan_muezzin_2'),
      ),
    ];

    if (storedVersion != _channelVersion) {
      for (final ch in channels) {
        try {
          await androidPlugin.deleteNotificationChannel(ch.id);
        } catch (_) {}
      }
    }

    for (final ch in channels) {
      try {
        await androidPlugin.createNotificationChannel(ch);
      } catch (_) {}
    }

    await DBHelper.setSetting(_channelVersionKey, _channelVersion.toString());
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Scheduling
  // ───────────────────────────────────────────────────────────────────────────

  Future<void> scheduleRollingPrayerNotifications({
    required double latitude,
    required double longitude,
  }) async {
    if (kIsWeb) return;
    await initialize();

    await _plugin.cancelAll();

    final toneMap = await _loadPrayerTonePreferences();
    final speakerRoute = await _loadSpeakerRoutePreference();
    final now = DateTime.now();
    final formatter = DateFormat('h:mm a');

    for (int dayOffset = 0; dayOffset < _batchDays; dayOffset++) {
      final date =
          DateTime(now.year, now.month, now.day).add(Duration(days: dayOffset));
      final times = PrayerService.getTimesForDate(latitude, longitude, date);
      final prayers = PrayerService.getObligatoryPrayers(times);

      for (final prayer in prayers) {
        if (!prayer.time.isAfter(now)) continue;

        final tone = toneMap[prayer.name] ?? _toneBeep;
        final details = await _buildNotificationDetailsForPrayer(
          prayerName: prayer.name,
          tone: tone,
          speakerRoute: speakerRoute,
        );

        await _plugin.zonedSchedule(
          _notificationIdFor(prayer.name, prayer.time),
          '${prayer.name} Prayer Time',
          'It is ${formatter.format(prayer.time)}. Time for ${prayer.name}.',
          tz.TZDateTime.from(prayer.time, tz.local),
          details,
          androidScheduleMode: AndroidScheduleMode.alarmClock,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          payload: '${prayer.name}|${prayer.time.toIso8601String()}',
        );
      }
    }

    final batchEnd = DateTime(now.year, now.month, now.day)
        .add(const Duration(days: _batchDays));
    await DBHelper.setSetting(_batchEndKey, batchEnd.toIso8601String());
    await DBHelper.setSetting(_lastLatKey, latitude.toString());
    await DBHelper.setSetting(_lastLngKey, longitude.toString());
  }

  Future<void> refreshBatchIfNeeded() async {
    if (kIsWeb) return;
    await initialize();

    final storedBatchEnd = await DBHelper.getSetting(_batchEndKey);
    if (storedBatchEnd == null) return;

    final parsedBatchEnd = DateTime.tryParse(storedBatchEnd);
    if (parsedBatchEnd == null) return;

    final now = DateTime.now();
    if (!parsedBatchEnd.isAfter(now.add(const Duration(hours: 12)))) {
      final latText = await DBHelper.getSetting(_lastLatKey);
      final lngText = await DBHelper.getSetting(_lastLngKey);
      if (latText != null && lngText != null) {
        await scheduleRollingPrayerNotifications(
          latitude: double.parse(latText),
          longitude: double.parse(lngText),
        );
      }
    }
  }

  Future<void> rescheduleUsingStoredLocation() async {
    if (kIsWeb) return;
    await initialize();

    final latText = await DBHelper.getSetting(_lastLatKey);
    final lngText = await DBHelper.getSetting(_lastLngKey);
    final latitude = double.tryParse(latText ?? '');
    final longitude = double.tryParse(lngText ?? '');
    if (latitude == null || longitude == null) return;

    await scheduleRollingPrayerNotifications(
      latitude: latitude,
      longitude: longitude,
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Public speaker helpers (used by Settings UI)
  // ───────────────────────────────────────────────────────────────────────────

  Future<void> triggerSelectedSpeakerNow({String? routeOverride}) async {
    if (kIsWeb) return;
    await initialize();
    await _triggerSelectedSpeakerForRoute(routeOverride);
  }

  Future<String> testSelectedSpeakerNow({
    String? routeOverride,
    String? prayerOverride,
  }) async {
    if (kIsWeb) return 'Speaker routing test is not supported on web.';

    await initialize();
    final route = routeOverride ?? await _loadSpeakerRoutePreference();
    final prayerName = await _resolvePrayerNameForTrigger(prayerOverride);
    final toneSelection = await _resolveToneSelection(prayerName);

    if (route == speakerGoogleCast) {
      if (defaultTargetPlatform != TargetPlatform.android) {
        return 'Google Cast testing is currently supported on Android only.';
      }

      final connected = await _ensureCastConnected();
      if (!connected) {
        return 'No active Cast session. Connect a Google/Chromecast speaker first '
            'and make sure the receiver is still on the same Wi-Fi network.';
      }

      try {
        await _triggerGoogleCastIfConfigured(prayerName: prayerName);
        return 'Playing ${toneSelection.label} for $prayerName on Google/Chromecast.';
      } catch (e) {
        return 'Cast command failed: $e';
      }
    }

    if (route == speakerPhoneSpeaker) {
      try {
        await _playToneLocallyForTest(toneSelection);
        return 'Playing ${toneSelection.label} for $prayerName on this phone.';
      } catch (e) {
        return 'Phone playback failed: $e';
      }
    }

    return 'Current route is "$route". No external command is sent for this route.';
  }

  // ───────────────────────────────────────────────────────────────────────────
  // *** KEY FIX #2 ***
  // Robust Cast connection helper.
  //
  // Your original code returned immediately when not connected. Now we:
  //   1. Check if already connected — if so, done.
  //   2. Try to start discovery and reconnect to the persisted device IP.
  //   3. Wait up to 8 s for a session to become active.
  // ───────────────────────────────────────────────────────────────────────────

  Future<bool> _ensureCastConnected() async {
    try {
      if (await GoogleChromeCast.isConnected()) return true;

      // Attempt to reconnect via discovery.
      // Some versions of the googlecast package expose startDiscovery() —
      // call it to begin scanning the local network.
      try {
        await GoogleChromeCast.startDiscovery();
      } catch (_) {
        // Package may not expose this method; swallow and continue.
      }

      // Poll for up to 8 seconds in case the session auto-reconnects.
      for (int i = 0; i < 8; i++) {
        await Future<void>.delayed(const Duration(seconds: 1));
        if (await GoogleChromeCast.isConnected()) return true;
      }

      return false;
    } catch (e) {
      debugPrint('_ensureCastConnected error: $e');
      return false;
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Internal Cast trigger — called from both the foreground tap handler
  // AND the background delivery handler.
  // ───────────────────────────────────────────────────────────────────────────

  Future<void> _triggerGoogleCastIfConfigured({String? prayerName}) async {
    if (defaultTargetPlatform != TargetPlatform.android) return;

    try {
      final connected = await _ensureCastConnected();
      if (!connected) {
        debugPrint(
          'Google Cast: could not establish a session. '
          'Ensure the device is on the same Wi-Fi network.',
        );
        return;
      }

      final resolvedPrayerName = await _resolvePrayerNameForTrigger(prayerName);
      final mediaUrl = await _resolveCastUrlForPrayer(resolvedPrayerName);
      if (mediaUrl == null || mediaUrl.trim().isEmpty) {
        debugPrint('Google Cast: no tone or fallback media URL available.');
        return;
      }

      final toneSelection = await _resolveToneSelection(resolvedPrayerName);
      final castController = CastController();

      await castController
          .setMedia(
            url: mediaUrl.trim(),
            title: '$resolvedPrayerName Prayer Time',
            subtitle: toneSelection.label,
          )
          .timeout(const Duration(seconds: 5));

      await castController.loadAudio().timeout(const Duration(seconds: 10));
      await castController.play().timeout(const Duration(seconds: 10));

      debugPrint('Google Cast: command sent successfully.');
    } catch (e) {
      debugPrint('Google Cast error: $e');
      rethrow;
    }
  }

  Future<void> _triggerSelectedSpeakerForRoute(
    String? routeOverride, {
    String? prayerName,
  }) async {
    final route = routeOverride ?? await _loadSpeakerRoutePreference();
    if (route == speakerGoogleCast) {
      await _triggerGoogleCastIfConfigured(prayerName: prayerName);
    }
    // speakerPhoneSpeaker — sound already plays via the notification channel;
    // nothing extra to do here.
  }

  Future<void> _triggerNetworkSpeakerIfConfigured({
    String? payload,
    String? prayerName,
  }) async {
    await _triggerSelectedSpeakerForRoute(
      null,
      prayerName: prayerName ?? _prayerNameFromPayload(payload),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Preferences helpers
  // ───────────────────────────────────────────────────────────────────────────

  Future<String> _loadSpeakerRoutePreference() async {
    final stored = await DBHelper.getSetting(_speakerRouteKey);
    return (stored == speakerGoogleCast) ? speakerGoogleCast : speakerPhoneSpeaker;
  }

  Future<Map<String, String>> _loadPrayerTonePreferences() async {
    final map = <String, String>{};
    for (final prayer in _supportedPrayers) {
      final key = 'alarm_tone_${prayer.toLowerCase()}';
      map[prayer] = await DBHelper.getSetting(key) ?? _toneBeep;
    }
    return map;
  }

  Future<String> _resolvePrayerNameForTrigger(String? prayerOverride) async {
    final normalizedOverride = _normalizePrayerName(prayerOverride);
    if (normalizedOverride != null) {
      return normalizedOverride;
    }

    final latitude = double.tryParse(await DBHelper.getSetting(_lastLatKey) ?? '');
    final longitude = double.tryParse(await DBHelper.getSetting(_lastLngKey) ?? '');
    if (latitude != null && longitude != null) {
      return PrayerService.getNextPrayer(latitude, longitude).name;
    }

    return _supportedPrayers.first;
  }

  String? _prayerNameFromPayload(String? payload) {
    if (payload == null || payload.trim().isEmpty) return null;
    final parts = payload.split('|');
    if (parts.isEmpty) return null;
    return _normalizePrayerName(parts.first);
  }

  String? _normalizePrayerName(String? prayerName) {
    if (prayerName == null) return null;
    for (final prayer in _supportedPrayers) {
      if (prayer.toLowerCase() == prayerName.trim().toLowerCase()) {
        return prayer;
      }
    }
    return null;
  }

  Future<_ToneSelection> _resolveToneSelection(String prayerName) async {
    final tone = await DBHelper.getSetting('alarm_tone_${prayerName.toLowerCase()}') ??
        _toneBeep;

    switch (tone) {
      case _toneMuezzin1:
        return const _ToneSelection.asset(
          label: _toneMuezzin1,
          assetKey: 'assets/audio/athan_muezzin_1.wav',
          contentType: 'audio/wav',
          fileName: 'athan_muezzin_1.wav',
        );
      case _toneMuezzin2:
        return const _ToneSelection.asset(
          label: _toneMuezzin2,
          assetKey: 'assets/audio/athan_muezzin_2.wav',
          contentType: 'audio/wav',
          fileName: 'athan_muezzin_2.wav',
        );
      case toneCustomFile:
        final customPath = await DBHelper.getSetting(
          'alarm_tone_custom_path_${prayerName.toLowerCase()}',
        );
        if (customPath != null && customPath.trim().isNotEmpty) {
          final file = File(customPath.trim());
          if (await file.exists()) {
            final fileName = file.uri.pathSegments.isEmpty
                ? 'custom-tone'
                : file.uri.pathSegments.last;
            return _ToneSelection.file(
              label: toneCustomFile,
              filePath: file.path,
              contentType: _contentTypeForFileName(fileName),
              fileName: fileName,
            );
          }
        }
        return const _ToneSelection.asset(
          label: _toneBeep,
          assetKey: 'assets/audio/athan_beep.wav',
          contentType: 'audio/wav',
          fileName: 'athan_beep.wav',
        );
      case _toneBeep:
      default:
        return const _ToneSelection.asset(
          label: _toneBeep,
          assetKey: 'assets/audio/athan_beep.wav',
          contentType: 'audio/wav',
          fileName: 'athan_beep.wav',
        );
    }
  }

  Future<void> _playToneLocallyForTest(_ToneSelection selection) async {
    final previousPlayer = _testAudioPlayer;
    if (previousPlayer != null) {
      await previousPlayer.stop();
      await previousPlayer.dispose();
    }

    final player = AudioPlayer();
    _testAudioPlayer = player;
    player.onPlayerComplete.listen((_) {
      if (identical(_testAudioPlayer, player)) {
        _testAudioPlayer = null;
      }
      unawaited(player.dispose());
    });

    if (selection.assetKey != null) {
      await player.play(AssetSource(selection.assetPathForPlayer));
      return;
    }

    final filePath = selection.filePath;
    if (filePath == null || filePath.trim().isEmpty) {
      throw StateError('No playable file was available for the selected tone.');
    }

    await player.play(DeviceFileSource(filePath));
  }

  Future<String?> _resolveCastUrlForPrayer(String prayerName) async {
    final toneSelection = await _resolveToneSelection(prayerName);
    try {
      if (toneSelection.assetKey != null) {
        final byteData = await rootBundle.load(toneSelection.assetKey!);
        final bytes = byteData.buffer.asUint8List();
        return _publishCastToneBytes(bytes, toneSelection);
      }

      final filePath = toneSelection.filePath;
      if (filePath != null && filePath.trim().isNotEmpty) {
        return _publishCastToneFile(File(filePath), toneSelection);
      }
    } catch (e) {
      debugPrint('Google Cast tone resolution failed for $prayerName: $e');
    }

    final fallbackUrl = await DBHelper.getSetting(googleCastMediaUrlKey);
    if (fallbackUrl == null || fallbackUrl.trim().isEmpty) {
      return null;
    }
    return fallbackUrl.trim();
  }

  Future<String> _publishCastToneBytes(
    Uint8List bytes,
    _ToneSelection selection,
  ) async {
    await _ensureCastToneServer();
    final token = '${DateTime.now().microsecondsSinceEpoch}_${_castToneTokenSeed++}';
    _servedCastTones[token] = _ServedCastTone.bytes(
      bytes: bytes,
      contentType: selection.contentType,
      fileName: selection.fileName,
    );
    return _buildCastToneUrl(token, selection.fileName);
  }

  Future<String> _publishCastToneFile(
    File file,
    _ToneSelection selection,
  ) async {
    if (!await file.exists()) {
      throw StateError('Selected tone file no longer exists: ${file.path}');
    }

    await _ensureCastToneServer();
    final token = '${DateTime.now().microsecondsSinceEpoch}_${_castToneTokenSeed++}';
    _servedCastTones[token] = _ServedCastTone.file(
      filePath: file.path,
      contentType: selection.contentType,
      fileName: selection.fileName,
    );
    return _buildCastToneUrl(token, selection.fileName);
  }

  String _buildCastToneUrl(String token, String fileName) {
    final address = _castToneServerAddress;
    final server = _castToneServer;
    if (address == null || server == null) {
      throw StateError('Cast tone server is not running.');
    }

    final encodedFileName = Uri.encodeComponent(fileName);
    return 'http://${address.address}:${server.port}/tone/$token/$encodedFileName';
  }

  Future<void> _ensureCastToneServer() async {
    if (_castToneServer != null && _castToneServerAddress != null) {
      return;
    }

    final localAddress = await _findLocalIpv4Address();
    if (localAddress == null) {
      throw StateError('Could not determine this phone\'s Wi-Fi address for Cast playback.');
    }

    final server = await HttpServer.bind(InternetAddress.anyIPv4, 0);
    server.idleTimeout = const Duration(minutes: 10);
    server.listen(
      _handleCastToneRequest,
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('Cast tone server error: $error');
      },
    );
    _castToneServer = server;
    _castToneServerAddress = localAddress;
  }

  Future<void> _handleCastToneRequest(HttpRequest request) async {
    try {
      final segments = request.uri.pathSegments;
      if (segments.length < 2 || segments.first != 'tone') {
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
        return;
      }

      final token = segments[1];
      final tone = _servedCastTones[token];
      if (tone == null) {
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
        return;
      }

      request.response.headers.set(HttpHeaders.cacheControlHeader, 'no-store');
      request.response.headers.contentType = ContentType.parse(tone.contentType);

      if (tone.bytes != null) {
        request.response.add(tone.bytes!);
        await request.response.close();
        return;
      }

      final filePath = tone.filePath;
      if (filePath == null) {
        request.response.statusCode = HttpStatus.internalServerError;
        await request.response.close();
        return;
      }

      final file = File(filePath);
      if (!await file.exists()) {
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
        return;
      }

      await request.response.addStream(file.openRead());
      await request.response.close();
    } catch (e) {
      request.response.statusCode = HttpStatus.internalServerError;
      await request.response.close();
      debugPrint('Cast tone request failed: $e');
    }
  }

  Future<InternetAddress?> _findLocalIpv4Address() async {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLinkLocal: false,
      includeLoopback: false,
    );

    for (final interface in interfaces) {
      for (final address in interface.addresses) {
        if (_isPrivateIpv4(address)) {
          return address;
        }
      }
    }

    return null;
  }

  bool _isPrivateIpv4(InternetAddress address) {
    final octets = address.address.split('.');
    if (octets.length != 4) return false;

    final first = int.tryParse(octets[0]);
    final second = int.tryParse(octets[1]);
    if (first == null || second == null) return false;

    if (first == 10) return true;
    if (first == 192 && second == 168) return true;
    if (first == 172 && second >= 16 && second <= 31) return true;
    return false;
  }

  String _contentTypeForFileName(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.mp3')) return 'audio/mpeg';
    if (lower.endsWith('.wav')) return 'audio/wav';
    if (lower.endsWith('.m4a') || lower.endsWith('.mp4')) return 'audio/mp4';
    if (lower.endsWith('.aac')) return 'audio/aac';
    if (lower.endsWith('.ogg') || lower.endsWith('.opus')) return 'audio/ogg';
    if (lower.endsWith('.flac')) return 'audio/flac';
    if (lower.endsWith('.3gp')) return 'audio/3gpp';
    if (lower.endsWith('.amr')) return 'audio/amr';
    if (lower.endsWith('.wma')) return 'audio/x-ms-wma';
    if (lower.endsWith('.mkv')) return 'audio/x-matroska';
    return 'application/octet-stream';
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Notification details builders
  // ───────────────────────────────────────────────────────────────────────────

  Future<NotificationDetails> _buildNotificationDetailsForPrayer({
    required String prayerName,
    required String tone,
    required String speakerRoute,
  }) async {
    final (channelId, channelName, androidSound, _) = _tonePlatformConfig(tone);

    return NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        sound: androidSound,
        audioAttributesUsage: AudioAttributesUsage.alarm,
        fullScreenIntent: true,
      ),
      iOS: const DarwinNotificationDetails(presentSound: true),
    );
  }

  (String, String, RawResourceAndroidNotificationSound?, String?)
      _tonePlatformConfig(String tone) {
    switch (tone) {
      case _toneMuezzin1:
        return (
          'athan_tone_muezzin_1',
          'Muezzin 1',
          const RawResourceAndroidNotificationSound('athan_muezzin_1'),
          null
        );
      case _toneMuezzin2:
        return (
          'athan_tone_muezzin_2',
          'Muezzin 2',
          const RawResourceAndroidNotificationSound('athan_muezzin_2'),
          null
        );
      default:
        return (
          'athan_tone_beep',
          'Beep',
          const RawResourceAndroidNotificationSound('athan_beep'),
          null
        );
    }
  }

  int _notificationIdFor(String prayer, DateTime time) {
    final prayerOffset = switch (prayer) {
      'Fajr' => 1,
      'Dhuhr' => 2,
      'Asr' => 3,
      'Maghrib' => 4,
      'Isha' => 5,
      _ => 9,
    };
    return ((time.year * 10000) + (time.month * 100) + time.day) * 10 +
        prayerOffset;
  }
}

class _ToneSelection {
  const _ToneSelection.asset({
    required this.label,
    required this.assetKey,
    required this.contentType,
    required this.fileName,
  }) : filePath = null;

  const _ToneSelection.file({
    required this.label,
    required this.filePath,
    required this.contentType,
    required this.fileName,
  }) : assetKey = null;

  final String label;
  final String? assetKey;
  final String? filePath;
  final String contentType;
  final String fileName;

  String get assetPathForPlayer {
    final key = assetKey;
    if (key == null) {
      throw StateError('Asset path requested for a file-based tone.');
    }
    return key.replaceFirst('assets/', '');
  }
}

class _ServedCastTone {
  const _ServedCastTone.bytes({
    required this.bytes,
    required this.contentType,
    required this.fileName,
  }) : filePath = null;

  const _ServedCastTone.file({
    required this.filePath,
    required this.contentType,
    required this.fileName,
  }) : bytes = null;

  final Uint8List? bytes;
  final String? filePath;
  final String contentType;
  final String fileName;
}