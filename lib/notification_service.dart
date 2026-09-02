import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:ui';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:googlecast/CastController.dart';
import 'package:googlecast/googlecast.dart';
import 'package:http/http.dart' as http;
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:intl/intl.dart';

import 'db_helper.dart';
import 'prayer_service.dart';
import 'wear_service.dart';

import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';

// ─────────────────────────────────────────────────────────────────────────────
// TOP-LEVEL background callbacks
// ─────────────────────────────────────────────────────────────────────────────

@pragma('vm:entry-point')
Future<void> onDidReceiveBackgroundNotificationResponse(
  NotificationResponse response,
) async {
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint(
    '[ATHAN_BG_SERVICE] Background notification response: action=${response.actionId}, payload=${response.payload}',
  );

  try {
    await NotificationService.instance.initialize();

    if (response.actionId == NotificationService.actionStopAthan) {
      await NotificationService.instance.stopAllPlayback();
    } else if (response.actionId == NotificationService.actionSnooze) {
      await NotificationService.instance.snoozeAthan(response.payload);
    } else if (response.actionId == NotificationService.actionOpenApp || response.actionId == null) {
      // App will be launched by the system.
      // We don't trigger the speaker here to avoid duplicate triggers if the alarm already fired.
      debugPrint('[ATHAN_BG_SERVICE] Notification tapped, launching app...');
    } else {
      // Wrap in a timeout to keep the isolate alive long enough for streaming
      await NotificationService.instance
          ._triggerNetworkSpeakerIfConfigured(
            payload: response.payload,
            isBackground: true,
          )
          .timeout(const Duration(minutes: 5));
    }
  } catch (e) {
    debugPrint('[ATHAN_BG_SERVICE] Background handler error: $e');
  }
}

@pragma('vm:entry-point')
Future<void> onDidReceiveAlarm(int id, Map<String, dynamic> params) async {
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('[ATHAN_BG_SERVICE] Background alarm triggered: id=$id');

  try {
    await NotificationService.instance.initialize();
    final payload = params['payload'] as String?;
    await NotificationService.instance
        ._triggerNetworkSpeakerIfConfigured(
          payload: payload,
          isBackground: true,
        )
        .timeout(const Duration(minutes: 5));
  } catch (e) {
    debugPrint('[ATHAN_BG_SERVICE] Background alarm error: $e');
  }
}

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  // Constants for DB keys and routes
  static const String preferredCastSpeakerNameKey =
      'preferred_cast_speaker_name';
  static const String preferredCastSpeakerIpKey =
      'preferred_cast_speaker_ip';
  static const String _speakerRouteKey = 'notification_speaker_route';
  static const String speakerGoogleCast = 'Google/Chromecast Speaker';
  static const String speakerGoogleCastIp = 'Google Cast (Static IP)';
  static const String speakerPhoneAndCast = 'Phone + Google Cast';
  static const String speakerPhoneSpeaker = 'Phone Speaker (Alarm Stream)';
  static const String overrideMuteKey = 'settings_override_mute';
  static const String actionStopAthan = 'stop_athan_action';
  static const String actionSnooze = 'snooze_athan_action';
  static const String actionOpenApp = 'open_app_action';
  static const String googleCastMediaUrlKey = 'google_cast_media_url';
  static const String popupNotificationKey = 'settings_popup_notification';
  static const String alexaAccessTokenKey = 'alexa_access_token';
  static const String alexaRefreshTokenKey = 'alexa_refresh_token';
  static const String alexaClientId = 'YOUR_ALEXA_CLIENT_ID';
  static const String alexaClientSecret = 'YOUR_ALEXA_CLIENT_SECRET';
  static const String toneCustom = 'CUSTOM_FILE';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static const _deeplinkChannel = MethodChannel('com.example.athan/deeplink');
  
  AudioPlayer? _testAudioPlayer;
  bool _initialized = false;
  Future<void>? _initializationFuture;
  HttpServer? _assetServer;
  static const int _assetServerPort = 8765;
  
  final ValueNotifier<bool> isPlayingNotifier = ValueNotifier<bool>(false);
  bool get isPlaying => isPlayingNotifier.value;

  static const int _notificationIdStart = 1000;
  static const int _alarmIdStart = 2000;

  static String? get toneCustomFile => toneCustom;

  Future<void> initialize() async {
    if (kIsWeb || _initialized) return;
    _initializationFuture ??= _doInitialize();
    return _initializationFuture;
  }

  Future<void> _doInitialize() async {
    try {
      await _configureLocalTimezone();

      // AUTO-RECONNECT ON STARTUP
      // If we are on Android and the preferred route involves Cast, try to reconnect
      // in the background as soon as the app/service starts.
      if (defaultTargetPlatform == TargetPlatform.android) {
        final route = await _loadSpeakerRoutePreference();
        if (route == speakerGoogleCast ||
            route == speakerGoogleCastIp ||
            route == speakerPhoneAndCast) {
          unawaited(_ensureCastConnected().catchError((_) => false));
        }
      }

      const androidInit = AndroidInitializationSettings(
        '@mipmap/launcher_icon',
      );
      const initSettings = InitializationSettings(
        android: androidInit,
        iOS: DarwinInitializationSettings(),
      );

      await _plugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (response) {
          if (response.actionId == actionStopAthan) {
            stopAllPlayback();
          } else if (response.actionId == actionSnooze) {
            snoozeAthan(response.payload);
          } else if (response.actionId == actionOpenApp) {
            _deeplinkChannel.invokeMethod('navigateToTab', 0);
          } else {
            _deeplinkChannel.invokeMethod('navigateToTab', 0);
            _triggerNetworkSpeakerIfConfigured(payload: response.payload);
          }
        },
        onDidReceiveBackgroundNotificationResponse:
            onDidReceiveBackgroundNotificationResponse,
      );

      _initialized = true;
    } catch (e) {
      _initializationFuture = null;
      rethrow;
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // STABLE CAST CONNECTION LOGIC
  // ───────────────────────────────────────────────────────────────────────────

  Future<bool> _ensureCastConnected() async {
    debugPrint('[ATHAN_BG_SERVICE] Google Cast: Ensuring connection...');
    try {
      // 1. Initial check: Is the SDK already reporting a connected session?
      if (await GoogleChromeCast.isConnected()) {
        debugPrint('[ATHAN_BG_SERVICE] Already connected to Cast.');
        // Ensure remote client is ready in native side
        await GoogleChromeCast.debugState();
        return true;
      }

      final savedIp = await DBHelper.getSetting(preferredCastSpeakerIpKey);
      final savedName = await DBHelper.getSetting(preferredCastSpeakerNameKey);

      if ((savedIp == null || savedIp.isEmpty) && (savedName == null || savedName.isEmpty)) {
        debugPrint('[ATHAN_BG_SERVICE] No preferred speaker IP or Name found.');
        return false;
      }

      // 2. Refresh discovery to populate MediaRouter
      await GoogleChromeCast.startDiscovery();
      // Discovery takes a moment to warm up, especially in background isolates
      // Increased from 3s to 5s to improve reliability in high-interference or wake-up scenarios
      await Future.delayed(const Duration(seconds: 5));

      // 3. PRIORITY 1: Connect by IP (Most reliable in background)
      if (savedIp != null && savedIp.isNotEmpty) {
        debugPrint('[ATHAN_BG_SERVICE] Attempting IP connection to $savedIp');
        final found = await GoogleChromeCast.connectToIp(savedIp);
        if (found) {
          // Polling wait for session establishment
          for (int j = 0; j < 10; j++) {
            if (await GoogleChromeCast.isConnected()) {
              debugPrint('[ATHAN_BG_SERVICE] Connected successfully by IP to $savedIp');
              return true;
            }
            await Future.delayed(const Duration(seconds: 1));
          }
        }
        debugPrint('[ATHAN_BG_SERVICE] IP connection to $savedIp failed or timed out.');
      }

      // 4. PRIORITY 2: Reconnect by Name (mDNS fallback)
      if (savedName != null && savedName.isNotEmpty) {
        debugPrint('[ATHAN_BG_SERVICE] Attempting mDNS reconnection to $savedName');
        final found = await GoogleChromeCast.reconnectToDevice(savedName);
        if (found) {
          for (int j = 0; j < 10; j++) {
            if (await GoogleChromeCast.isConnected()) {
              debugPrint('[ATHAN_BG_SERVICE] Reconnected successfully to $savedName');
              return true;
            }
            await Future.delayed(const Duration(seconds: 1));
          }
        }
      }

      return false;
    } catch (e) {
      debugPrint('[ATHAN_BG_SERVICE] Cast connection error: $e');
      return false;
    }
  }

  Future<void> _showFallbackNotification(String? prayerName, String message) async {
    try {
      final title = prayerName != null ? '$prayerName Athan' : 'Athan';
      await _plugin.show(
        _notificationIdStart - 1,
        title,
        message,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'athan_alerts_v2',
            'Athan Alerts',
            channelDescription: 'Prayer time notifications and Athan playback',
            importance: Importance.max,
            priority: Priority.high,
            fullScreenIntent: true,
            category: AndroidNotificationCategory.alarm,
            visibility: NotificationVisibility.public,
          ),
        ),
      );
    } catch (e) {
      debugPrint('[ATHAN_BG_SERVICE] Fallback notification error: $e');
    }
  }

  Future<void> _triggerGoogleCastIfConfigured({
    String? prayerName,
    bool isBackground = false,
    bool enableFallback = true,
  }) async {
    if (defaultTargetPlatform != TargetPlatform.android) return;

    debugPrint('[ATHAN_SIGNAL] START_TRIGGER: $prayerName (Background: $isBackground)');
    try {
      final connected = await _ensureCastConnected();

      if (!connected) {
        debugPrint(
          '[ATHAN_BG_SERVICE] Cast connection failed. ${enableFallback ? "Falling back to phone speaker." : "Fallback disabled."}',
        );
        if (enableFallback) {
          if (isBackground) {
            await _showFallbackNotification(
              prayerName,
              'Cast unavailable — athan playing on phone.',
            );
          }
          await _triggerPhoneSpeakerNow(prayerName: prayerName);
        }
        return;
      }

      final resolvedName = await _resolvePrayerNameForTrigger(prayerName);

      // Resolve Cast URL: prayer-specific → local asset server → global URL (last resort)
      String? castUrl = await _resolvePrayerSpecificCastUrl(resolvedName);
      if (castUrl == null || castUrl.isEmpty) {
        final tone = await _loadTonePreference(prayerName);
        final assetPath = _mapToneToAsset(tone);
        castUrl = await _buildLocalAssetUrl(assetPath);
        debugPrint('[ATHAN_BG_SERVICE] Using local asset server URL: $castUrl');
      }
      if (castUrl == null || castUrl.isEmpty) {
        castUrl = await DBHelper.getSetting(googleCastMediaUrlKey);
        debugPrint('[ATHAN_BG_SERVICE] Falling back to global Cast URL: $castUrl');
      }

      if (castUrl == null || castUrl.isEmpty) {
        debugPrint('[ATHAN_BG_SERVICE] No Cast URL available for $resolvedName. ${enableFallback ? "Falling back." : "Fallback disabled."}');
        if (enableFallback) {
          if (isBackground) {
            await _showFallbackNotification(
              prayerName,
              'No Cast media URL set — athan playing on phone.',
            );
          }
          await _triggerPhoneSpeakerNow(prayerName: prayerName);
        }
        return;
      }

      final castController = CastController();
      await castController.setMedia(
        url: castUrl.trim(),
        title: '$resolvedName Athan',
      );

      await castController.loadAudio();
      _updatePlayingStatus(true);
      if (resolvedName != 'Prayer') {
        unawaited(WearService.instance.sendAthanNotification(resolvedName));
      }
      await castController.play();

    } catch (e) {
      debugPrint('[ATHAN_BG_SERVICE] Cast Trigger Error: $e');
      if (enableFallback) {
        if (isBackground) {
          await _showFallbackNotification(
            prayerName,
            'Cast error — athan playing on phone.',
          );
        }
        await _triggerPhoneSpeakerNow(prayerName: prayerName);
      }
    }
  }

  Future<void> _triggerNetworkSpeakerIfConfigured({
    String? payload,
    bool isBackground = false,
  }) async {
    final route = await _loadSpeakerRoutePreference();
    final prayerName = _prayerNameFromPayload(payload);

    if (route == speakerGoogleCast || route == speakerGoogleCastIp) {
      await _triggerGoogleCastIfConfigured(
        prayerName: prayerName,
        isBackground: isBackground,
      );
    } else if (route == speakerPhoneAndCast) {
      debugPrint('[ATHAN_BG_SERVICE] Dual Route: Triggering Phone + Cast');
      final castFuture = _triggerGoogleCastIfConfigured(
        prayerName: prayerName,
        isBackground: isBackground,
        enableFallback: false,
      );
      final phoneFuture = _triggerPhoneSpeakerNow(prayerName: prayerName);
      await Future.wait([castFuture, phoneFuture]);
    } else {
      // Direct local playback if route is Phone Speaker or as fallback
      await _triggerPhoneSpeakerNow(prayerName: prayerName);
    }

    // Consolidated background delay to keep isolate alive
    if (isBackground) {
      debugPrint('[ATHAN_BG_SERVICE] Isolate active for playback duration...');
      await Future.delayed(const Duration(seconds: 300));
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // PHONE SPEAKER & CLEANUP
  // ───────────────────────────────────────────────────────────────────────────

  void _updatePlayingStatus(bool value) {
    isPlayingNotifier.value = value;
    final port = IsolateNameServer.lookupPortByName('athan_ui_port');
    port?.send(value);
  }

  Future<void> _triggerPhoneSpeakerNow({String? prayerName}) async {
    debugPrint('[ATHAN_BG_SERVICE] Triggering Phone Speaker local playback...');
    try {
      final tone = await _loadTonePreference(prayerName);
      final isOverrideMute =
          (await DBHelper.getSetting(overrideMuteKey)) == 'true';

      // [Settings-page-fixes] Await stop/dispose so old audio fully stops before new source plays
      await _testAudioPlayer?.stop();
      await _testAudioPlayer?.dispose();
      _testAudioPlayer = AudioPlayer();

      if (isOverrideMute) {
        // On Android, using the Alarm stream often bypasses "Do Not Disturb" or "Mute"
        // depending on system settings and how the player is configured.
        // For audioplayers 6.x, we use AudioContext.
        await _testAudioPlayer!.setAudioContext(AudioContext(
          android: AudioContextAndroid(
            usageType: AndroidUsageType.alarm,
            contentType: AndroidContentType.music,
            audioFocus: AndroidAudioFocus.gainTransient,
          ),
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.playback,
            options: {
              AVAudioSessionOptions.duckOthers,
              AVAudioSessionOptions.defaultToSpeaker,
            },
          ),
        ));
      }

      Source source;
      if (tone == toneCustom) {
        final customPath = await DBHelper.getSetting(
          'alarm_tone_custom_path_${prayerName?.toLowerCase() ?? "fajr"}',
        );
        if (customPath != null && customPath.isNotEmpty) {
          source = DeviceFileSource(customPath);
        } else {
          source = AssetSource('audio/athan_beep.wav');
        }
      } else {
        final assetPath = _mapToneToAsset(tone);
        source = AssetSource(assetPath);
      }

      await _testAudioPlayer!.play(source);
      _updatePlayingStatus(true);
      if (prayerName != null) {
        unawaited(WearService.instance.sendAthanNotification(prayerName));
      }
    } catch (e) {
      debugPrint('[ATHAN_BG_SERVICE] Phone speaker trigger error: $e');
    }
  }

  String _mapToneToAsset(String tone) {
    switch (tone) {
      case 'Fajr Athan by Mishary Rashid':
      case 'Muezzin Voice 1 with Fajr Athan':
        return 'audio/Fajr Athan by Mishary Rashid.mp3';
      case 'Athan by Mishary Rashid':
      case 'Muezzin Voice 2 with Mishary Alafasi':
        return 'audio/Athan by Mishary Rashid.mp3';
      case 'Athan by Wakilur R Chowdhury':
      case 'Abbu_Athan':
        return 'audio/Athan by Wakilur R Chowdhury.mp3';
      case 'Beep':
      default:
        return 'audio/athan_beep.wav';
    }
  }

  Future<String> _loadTonePreference(String? prayerName) async {
    if (prayerName == null) return 'Beep';
    final stored = await DBHelper.getSetting(
      'alarm_tone_${prayerName.toLowerCase()}',
    );
    return stored ?? 'Beep';
  }

  Future<bool> reconnectCast() => _ensureCastConnected();

  Future<void> _startAssetServerIfNeeded() async {
    if (_assetServer != null) return;
    try {
      _assetServer = await HttpServer.bind(
        InternetAddress.anyIPv4,
        _assetServerPort,
      );
      _assetServer!.listen((req) async {
        final filename = Uri.decodeComponent(req.uri.path.replaceFirst('/', ''));
        debugPrint('[ASSET_SERVER] Request: ${req.method} ${req.uri.path} (decoded: $filename) from ${req.connectionInfo?.remoteAddress.address}');
        try {
          // Attempt to find the asset
          final assetKey = 'assets/audio/$filename';
          final data = await rootBundle.load(assetKey);
          final bytes = data.buffer.asUint8List();
          final subtype = filename.toLowerCase().endsWith('.wav') ? 'wav' : 'mpeg';
          req.response.headers
            ..contentType = ContentType('audio', subtype)
            ..contentLength = bytes.length
            ..set('Accept-Ranges', 'bytes')
            ..set('Access-Control-Allow-Origin', '*');
          req.response.add(bytes);
          await req.response.close();
          debugPrint('[ASSET_SERVER] Served $filename (${bytes.length} bytes)');
        } catch (e) {
          debugPrint('[ASSET_SERVER] Failed to serve $filename: $e');
          req.response.statusCode = HttpStatus.notFound;
          await req.response.close();
        }
      });
      debugPrint('[ASSET_SERVER] Started on port $_assetServerPort');
    } catch (e) {
      debugPrint('[ASSET_SERVER] Failed to start: $e');
    }
  }

  Future<String?> _getLocalIp() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      );
      final allAddrs = <String>[];
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (!addr.isLoopback) allAddrs.add(addr.address);
        }
      }
      debugPrint('[ASSET_SERVER] All discovered IPs: $allAddrs');
      if (allAddrs.isEmpty) return null;

      // Prefer IP on same /24 subnet as the saved Cast device IP
      final castIp = await DBHelper.getSetting(preferredCastSpeakerIpKey);
      if (castIp != null && castIp.isNotEmpty) {
        final castPrefix = castIp.split('.').take(3).join('.');
        for (final addr in allAddrs) {
          if (addr.startsWith('$castPrefix.')) return addr;
        }
      }
      // Prefer RFC 1918 private ranges (192.168.x.x, 10.x.x.x, 172.16-31.x.x)
      for (final addr in allAddrs) {
        if (addr.startsWith('192.168.') || addr.startsWith('10.') ||
            RegExp(r'^172\.(1[6-9]|2\d|3[01])\.').hasMatch(addr)) {
          return addr;
        }
      }
      return allAddrs.first;
    } catch (_) {}
    return null;
  }

  Future<String?> _buildLocalAssetUrl(String assetPath) async {
    await _startAssetServerIfNeeded();
    final ip = await _getLocalIp();
    debugPrint('[ASSET_SERVER] Selected phone IP: $ip');
    if (ip == null) return null;
    final filename = assetPath.split('/').last;
    // URL-encode the filename to handle spaces and special characters which
    // can cause the Cast SDK or device to fail to fetch the media.
    final encodedFilename = Uri.encodeComponent(filename);
    return 'http://$ip:$_assetServerPort/$encodedFilename';
  }

  Future<void> cancelAllNotifications() async {
    if (kIsWeb) return;
    await initialize();
    await _plugin.cancelAll();
  }

  Future<void> stopAllPlayback() async {
    try {
      _updatePlayingStatus(false);
      _testAudioPlayer?.stop();
      if (defaultTargetPlatform == TargetPlatform.android) {
        if (await GoogleChromeCast.isConnected()) {
          final castController = CastController();
          await castController.stop();
        }
      }
    } catch (e) {
      debugPrint('Error stopping playback: $e');
    }
  }

  Future<void> snoozeAthan(String? payload) async {
    await stopAllPlayback();
    final prayerName = _prayerNameFromPayload(payload) ?? 'Prayer';
    final snoozeTime = DateTime.now().add(const Duration(minutes: 5));

    if (defaultTargetPlatform == TargetPlatform.android) {
      await AndroidAlarmManager.oneShotAt(
        snoozeTime,
        9998, // Dedicated snooze alarm ID
        onDidReceiveAlarm,
        exact: true,
        wakeup: true,
        rescheduleOnReboot: true,
        params: {'payload': 'SNOOZE_$prayerName'},
      );
    }
    debugPrint('[ATHAN_BG_SERVICE] Snoozed $prayerName for 5 minutes until $snoozeTime');
  }

  // ───────────────────────────────────────────────────────────────────────────
  // HELPERS
  // ───────────────────────────────────────────────────────────────────────────

  String? _prayerNameFromPayload(String? payload) {
    if (payload == null) return null;
    final cleanPayload = payload.replaceFirst('TEST_', '');
    if (cleanPayload.contains('Fajr')) return 'Fajr';
    if (cleanPayload.contains('Dhuhr')) return 'Dhuhr';
    if (cleanPayload.contains('Asr')) return 'Asr';
    if (cleanPayload.contains('Maghrib')) return 'Maghrib';
    if (cleanPayload.contains('Isha')) return 'Isha';
    return null;
  }

  Future<String> _resolvePrayerNameForTrigger(String? prayerName) async {
    if (prayerName != null) return prayerName;
    return 'Prayer';
  }

  Future<void> _configureLocalTimezone() async {
    tz.initializeTimeZones();
    final String timeZoneName = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(timeZoneName));
  }

  Future<String> _loadSpeakerRoutePreference() async {
    final stored = await DBHelper.getSetting(_speakerRouteKey);
    return stored ?? speakerPhoneSpeaker;
  }

  Future<String?> _resolvePrayerSpecificCastUrl(String resolvedName) async {
    final prayerUrl = await DBHelper.getSetting(
      'google_cast_media_url_${resolvedName.toLowerCase()}',
    );
    if (prayerUrl != null && prayerUrl.trim().isNotEmpty) {
      return prayerUrl.trim();
    }
    return null;
  }

  // ───────────────────────────────────────────────────────────────────────────
  // SCHEDULING LOGIC
  // ───────────────────────────────────────────────────────────────────────────

  Future<void> refreshBatchIfNeeded() async {
    // Check if we have scheduled notifications for the next 24 hours
    // If not, reschedule. This is a simple way to keep them rolling.
    // For now, we can just call rescheduleUsingStoredLocation if the app is opened.
    await rescheduleUsingStoredLocation();
  }

  Future<void> rescheduleUsingStoredLocation() async {
    final pinned = await DBHelper.getPinnedMasjid();
    if (pinned != null) {
      await scheduleRollingPrayerNotifications(
        latitude: pinned['lat'] as double,
        longitude: pinned['lng'] as double,
      );
      return;
    }

    final latStr = await DBHelper.getSetting('last_known_lat');
    final lngStr = await DBHelper.getSetting('last_known_lng');
    if (latStr != null && lngStr != null) {
      await scheduleRollingPrayerNotifications(
        latitude: double.parse(latStr),
        longitude: double.parse(lngStr),
      );
    }
  }

  Future<void> scheduleRollingPrayerNotifications({
    required double latitude,
    required double longitude,
  }) async {
    if (kIsWeb) return;
    await initialize();

    // Save location for rescheduling
    await DBHelper.setSetting('last_known_lat', latitude.toString());
    await DBHelper.setSetting('last_known_lng', longitude.toString());

    // Cancel all existing to avoid duplicates (especially for Alarms)
    await _plugin.cancelAll();
    if (defaultTargetPlatform == TargetPlatform.android) {
      // Note: AndroidAlarmManager doesn't have a cancelAll,
      // but we overwrite by ID.
      // We'll manage IDs carefully.
    }

    final now = DateTime.now();
    int count = 0;

    final isPopupEnabled =
        (await DBHelper.getSetting(popupNotificationKey)) != 'false';
    final alertMode = await DBHelper.getSetting(DBHelper.kAlertMode) ?? 'Reminder';
    final isAlarmMode = alertMode == 'Alarm';

    // Schedule for next 7 days
    for (int i = 0; i < 7; i++) {
      final date = now.add(Duration(days: i));
      final times = PrayerService.getTimesForDate(latitude, longitude, date);
      final prayers = PrayerService.getObligatoryPrayers(times);

      for (final prayer in prayers) {
        if (prayer.time.isBefore(now)) continue;

        final id = _notificationIdStart + count;
        final alarmId = _alarmIdStart + count;
        count++;

        // 1. Local Notification
        await _plugin.zonedSchedule(
          id,
          prayer.name,
          'Time for ${prayer.name} Athan',
          tz.TZDateTime.from(prayer.time, tz.local),
          NotificationDetails(
            android: AndroidNotificationDetails(
              'athan_alerts_v2',
              'Athan Alerts',
              channelDescription: 'Prayer time notifications and Athan playback',
              importance: Importance.max,
              priority: Priority.max,
              fullScreenIntent: true,
              category: AndroidNotificationCategory.alarm,
              visibility: NotificationVisibility.public,
              actions: const [
                AndroidNotificationAction(
                  actionStopAthan,
                  'Stop Athan',
                  showsUserInterface: true,
                  cancelNotification: true,
                ),
                AndroidNotificationAction(
                  actionSnooze,
                  'Snooze (5m)',
                  showsUserInterface: true,
                ),
                AndroidNotificationAction(
                  actionOpenApp,
                  'Open App',
                  showsUserInterface: true,
                ),
              ],
            ),
            iOS: const DarwinNotificationDetails(
              presentAlert: true,
              presentBadge: true,
              presentSound: true,
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          payload: 'PRAYER_${prayer.name}',
        );

        // 2. Android Alarm for Background Processing (Casting/Phone Speaker)
        if (defaultTargetPlatform == TargetPlatform.android) {
          await AndroidAlarmManager.oneShotAt(
            prayer.time,
            alarmId,
            onDidReceiveAlarm,
            exact: true,
            wakeup: true,
            rescheduleOnReboot: true,
            params: {'payload': 'PRAYER_${prayer.name}'},
          );
        }
      }
    }
    debugPrint('[ATHAN_BG_SERVICE] Scheduled $count rolling notifications/alarms');

    // 3. Sync with Alexa if connected
    unawaited(syncRemindersToAlexa(latitude: latitude, longitude: longitude));
  }

  Future<void> scheduleTestPrayer({
    required DateTime time,
    required String prayerName,
  }) async {
    if (kIsWeb) return;
    await initialize();

    const id = 9999;
    const alarmId = 9999;

    final isPopupEnabled =
        (await DBHelper.getSetting(popupNotificationKey)) != 'false';
    final alertMode = await DBHelper.getSetting(DBHelper.kAlertMode) ?? 'Reminder';
    final isAlarmMode = alertMode == 'Alarm';

    // 1. Local Notification
    await _plugin.zonedSchedule(
      id,
      'Test Prayer: $prayerName',
      'This is a test notification for $prayerName athan',
      tz.TZDateTime.from(time, tz.local),
      NotificationDetails(
        android: AndroidNotificationDetails(
          'athan_alerts_v2',
          'Athan Alerts',
          channelDescription: 'Prayer time notifications and Athan playback',
          importance: Importance.max,
          priority: Priority.max,
          fullScreenIntent: true,
          category: AndroidNotificationCategory.alarm,
          visibility: NotificationVisibility.public,
          actions: const [
            AndroidNotificationAction(
              actionStopAthan,
              'Stop Athan',
              showsUserInterface: true,
              cancelNotification: true,
            ),
            AndroidNotificationAction(
              actionSnooze,
              'Snooze (5m)',
              showsUserInterface: true,
            ),
            AndroidNotificationAction(
              actionOpenApp,
              'Open App',
              showsUserInterface: true,
            ),
          ],
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: 'TEST_PRAYER_$prayerName',
    );

    // 2. Android Alarm
    if (defaultTargetPlatform == TargetPlatform.android) {
      await AndroidAlarmManager.oneShotAt(
        time,
        alarmId,
        onDidReceiveAlarm,
        exact: true,
        wakeup: true,
        rescheduleOnReboot: true,
        params: {'payload': 'TEST_PRAYER_$prayerName'},
      );
    }
    debugPrint('[ATHAN_BG_SERVICE] Scheduled test notification/alarm at $time');
  }

  Future<void> triggerSelectedSpeakerNow({required String prayerName}) async {
    await _triggerNetworkSpeakerIfConfigured(
      payload: 'PRAYER_$prayerName',
      isBackground: false,
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // ALEXA INTEGRATION
  // ───────────────────────────────────────────────────────────────────────────

  Future<void> exchangeAlexaCodeForToken(String code) async {
    final url = Uri.parse('https://api.amazon.com/auth/o2/token');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'grant_type': 'authorization_code',
          'code': code,
          'client_id': alexaClientId,
          'client_secret': alexaClientSecret,
          'redirect_uri': 'athan-app://alexa-auth',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final accessToken = data['access_token'] as String;
        final refreshToken = data['refresh_token'] as String;

        await DBHelper.setSetting(alexaAccessTokenKey, accessToken);
        await DBHelper.setSetting(alexaRefreshTokenKey, refreshToken);
        debugPrint('[ALEXA] Token exchange successful.');
      } else {
        debugPrint('[ALEXA] Token exchange failed: ${response.statusCode} ${response.body}');
        throw Exception('Failed to exchange Alexa code');
      }
    } catch (e) {
      debugPrint('[ALEXA] Token exchange error: $e');
      rethrow;
    }
  }

  Future<void> syncRemindersToAlexa({
    required double latitude,
    required double longitude,
  }) async {
    final token = await DBHelper.getSetting(alexaAccessTokenKey);
    if (token == null || token.isEmpty) {
      debugPrint('[ALEXA] No access token found. Skipping sync.');
      return;
    }

    final now = DateTime.now();
    final times = PrayerService.getTimesForDate(latitude, longitude, now);
    final prayers = PrayerService.getObligatoryPrayers(times);

    for (final prayer in prayers) {
      if (prayer.time.isBefore(now)) continue;
      await _createAlexaReminder(token, prayer.name, prayer.time);
    }
  }

  Future<void> _createAlexaReminder(
    String token,
    String prayerName,
    DateTime time,
  ) async {
    final url = Uri.parse('https://api.amazonalexa.com/v1/alerts/reminders');
    final scheduledTime = DateFormat("yyyy-MM-dd'T'HH:mm:ss").format(time);

    final body = jsonEncode({
      "displayInformation": {
        "content": [
          {
            "locale": "en-US",
            "text": "Time for $prayerName Athan",
          }
        ]
      },
      "trigger": {
        "type": "SCHEDULED_ABSOLUTE",
        "scheduledTime": scheduledTime,
        "timeZoneId": tz.local.name,
      },
      "alertInfo": {
        "spokenInfo": {
          "content": [
            {
              "locale": "en-US",
              "text": "It is time for $prayerName Athan",
            }
          ]
        }
      },
      "pushNotification": {"status": "ENABLED"}
    });

    try {
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: body,
      );

      if (response.statusCode == 201) {
        debugPrint('[ALEXA] Reminder created for $prayerName at $scheduledTime');
      } else {
        debugPrint(
          '[ALEXA] Failed to create reminder: ${response.statusCode} ${response.body}',
        );
      }
    } catch (e) {
      debugPrint('[ALEXA] Error creating reminder: $e');
    }
  }

  Future<String> testSelectedSpeakerNow({
    required String routeOverride,
    String? prayerOverride,
  }) async {
    String prayerName = prayerOverride ?? 'Fajr';

    if (prayerOverride == null) {
      // "Auto" logic: find next prayer if possible
      try {
        final latStr = await DBHelper.getSetting('last_known_lat');
        final lngStr = await DBHelper.getSetting('last_known_lng');
        if (latStr != null && lngStr != null) {
          final lat = double.parse(latStr);
          final lng = double.parse(lngStr);
          final next = PrayerService.getNextPrayer(lat, lng);
          if (next != null) {
            prayerName = next.name;
          }
        }
      } catch (_) {}
    }

    try {
      if (routeOverride == speakerGoogleCast || routeOverride == speakerGoogleCastIp) {
        await _triggerGoogleCastIfConfigured(
          prayerName: prayerName,
          isBackground: false,
        );
        return 'Test command sent to Google Cast ($prayerName)';
      } else if (routeOverride == speakerPhoneAndCast) {
        debugPrint('[ATHAN_TEST] Triggering Phone + Cast');
        final castFuture = _triggerGoogleCastIfConfigured(
          prayerName: prayerName,
          isBackground: false,
          enableFallback: false,
        );
        final phoneFuture = _triggerPhoneSpeakerNow(prayerName: prayerName);
        await Future.wait([castFuture, phoneFuture]);
        return 'Dual playback started ($prayerName)';
      } else {
        await _triggerPhoneSpeakerNow(prayerName: prayerName);
        return 'Local playback started ($prayerName)';
      }
    } catch (e) {
      return 'Test failed: $e';
    }
  }
}
