import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'db_helper.dart';
import 'prayer_service.dart';

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  static const int _batchDays = 3;
  static const String _batchEndKey = 'notification_batch_end';
  static const String _lastLatKey = 'notification_last_lat';
  static const String _lastLngKey = 'notification_last_lng';
  static const String _speakerRouteKey = 'notification_speaker_route';
  static const String networkSpeakerIpKey = 'network_speaker_ip';
  static const String networkSpeakerPortKey = 'network_speaker_port';
  static const String networkSpeakerPathKey = 'network_speaker_path';

  static const String _toneBeep = 'Beep';
  static const String _toneMuezzin1 = 'Muezzin Voice 1';
  static const String _toneMuezzin2 = 'Muezzin Voice 2';
  static const String toneCustomFile = 'Custom File';
  static const String speakerSystemDefault = 'System Default';
  static const String speakerPhoneSpeaker = 'Phone Speaker (Alarm Stream)';
  static const String speakerNetworkIp = 'Network Speaker (IP)';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

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
      // When the user taps a prayer notification, fire the network speaker
      // HTTP endpoint (if Network Speaker route is active).
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        _triggerNetworkSpeakerIfConfigured();
      },
    );

    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    await androidPlugin?.requestNotificationsPermission();
    await androidPlugin?.requestExactAlarmsPermission();

    await _ensureAndroidToneChannels();

    _initialized = true;
  }

  Future<void> _ensureAndroidToneChannels() async {
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidPlugin == null) return;

    // Wrap each channel creation individually. Android throws PlatformException
    // (invalid_sound) when a channel already exists on the device with a
    // cached sound that can no longer be resolved (e.g. after a fresh install
    // or a build that previously lacked the raw resource). Catching here
    // prevents the error from propagating up and masquerading as a location
    // failure in the UI.
    Future<void> create(AndroidNotificationChannel channel) async {
      try {
        await androidPlugin.createNotificationChannel(channel);
      } catch (_) {
        // Channel may already exist from a prior install; safe to ignore.
      }
    }

    await create(
      const AndroidNotificationChannel(
        'athan_tone_beep',
        'Athan Tone: Beep',
        description: 'Prayer reminders with Beep tone',
        importance: Importance.max,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('athan_beep'),
      ),
    );

    await create(
      const AndroidNotificationChannel(
        'athan_tone_muezzin_1',
        'Athan Tone: Muezzin Voice 1',
        description: 'Prayer reminders with Muezzin Voice 1 tone',
        importance: Importance.max,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('athan_muezzin_1'),
      ),
    );

    await create(
      const AndroidNotificationChannel(
        'athan_tone_muezzin_2',
        'Athan Tone: Muezzin Voice 2',
        description: 'Prayer reminders with Muezzin Voice 2 tone',
        importance: Importance.max,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('athan_muezzin_2'),
      ),
    );
  }

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

    var scheduledCount = 0;

    for (int dayOffset = 0; dayOffset < _batchDays; dayOffset++) {
      final date = DateTime(
        now.year,
        now.month,
        now.day,
      ).add(Duration(days: dayOffset));

      final times = PrayerService.getTimesForDate(latitude, longitude, date);
      final prayers = PrayerService.getObligatoryPrayers(times);

      for (final prayer in prayers) {
        if (!prayer.time.isAfter(now)) {
          continue;
        }

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
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          payload: '${prayer.name}|${prayer.time.toIso8601String()}',
        );

        scheduledCount += 1;
      }
    }

    final batchEnd = DateTime(
      now.year,
      now.month,
      now.day,
    ).add(const Duration(days: _batchDays));

    await DBHelper.setSetting(_batchEndKey, batchEnd.toIso8601String());
    await DBHelper.setSetting(_lastLatKey, latitude.toString());
    await DBHelper.setSetting(_lastLngKey, longitude.toString());
    await DBHelper.setSetting(
      'notification_batch_count',
      scheduledCount.toString(),
    );
  }

  Future<void> refreshBatchIfNeeded() async {
    if (kIsWeb) return;
    await initialize();

    final storedBatchEnd = await DBHelper.getSetting(_batchEndKey);
    if (storedBatchEnd == null) {
      return;
    }

    final parsedBatchEnd = DateTime.tryParse(storedBatchEnd);
    if (parsedBatchEnd == null) {
      return;
    }

    final now = DateTime.now();
    final shouldRefresh = !parsedBatchEnd.isAfter(
      now.add(const Duration(hours: 12)),
    );
    if (!shouldRefresh) {
      return;
    }

    final latText = await DBHelper.getSetting(_lastLatKey);
    final lngText = await DBHelper.getSetting(_lastLngKey);
    final latitude = double.tryParse(latText ?? '');
    final longitude = double.tryParse(lngText ?? '');
    if (latitude == null || longitude == null) {
      return;
    }

    await scheduleRollingPrayerNotifications(
      latitude: latitude,
      longitude: longitude,
    );
  }

  Future<void> rescheduleUsingStoredLocation() async {
    if (kIsWeb) return;
    await initialize();

    final latText = await DBHelper.getSetting(_lastLatKey);
    final lngText = await DBHelper.getSetting(_lastLngKey);
    final latitude = double.tryParse(latText ?? '');
    final longitude = double.tryParse(lngText ?? '');
    if (latitude == null || longitude == null) {
      return;
    }

    await scheduleRollingPrayerNotifications(
      latitude: latitude,
      longitude: longitude,
    );
  }

  Future<Map<String, String>> _loadPrayerTonePreferences() async {
    final prayers = const ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];
    final map = <String, String>{};

    for (final prayer in prayers) {
      final key = 'alarm_tone_${prayer.toLowerCase()}';
      final stored = await DBHelper.getSetting(key);
      if (stored == _toneMuezzin1 ||
          stored == _toneMuezzin2 ||
          stored == toneCustomFile ||
          stored == _toneBeep) {
        map[prayer] = stored!;
      } else {
        map[prayer] = _toneBeep;
      }
    }

    return map;
  }

  Future<NotificationDetails> _buildNotificationDetailsForPrayer({
    required String prayerName,
    required String tone,
    required String speakerRoute,
  }) async {
    final audioUsage = _audioUsageForRoute(speakerRoute);

    if (tone == toneCustomFile &&
        defaultTargetPlatform == TargetPlatform.android) {
      final customPath = await DBHelper.getSetting(
        _customTonePathKey(prayerName),
      );
      if (customPath != null && customPath.trim().isNotEmpty) {
        final file = File(customPath);
        if (file.existsSync()) {
          final uri = Uri.file(customPath).toString();
          final channelId =
              'athan_tone_custom_${prayerName.toLowerCase()}_${uri.hashCode.abs()}';

          await _createAndroidCustomChannel(
            channelId: channelId,
            prayerName: prayerName,
            uri: uri,
          );

          return NotificationDetails(
            android: AndroidNotificationDetails(
              channelId,
              'Athan Tone: Custom ($prayerName)',
              importance: Importance.max,
              priority: Priority.high,
              playSound: true,
              sound: UriAndroidNotificationSound(uri),
              audioAttributesUsage: audioUsage,
            ),
            // iOS cannot use arbitrary user file paths for notification sounds.
            iOS: const DarwinNotificationDetails(presentSound: true),
          );
        }
      }
    }

    final (channelId, channelName, androidSound, iOSSound) =
        _tonePlatformConfig(tone);

    return NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        sound: androidSound,
        audioAttributesUsage: audioUsage,
      ),
      iOS: DarwinNotificationDetails(presentSound: true, sound: iOSSound),
    );
  }

  Future<void> _triggerNetworkSpeakerIfConfigured() async {
    try {
      final route = await _loadSpeakerRoutePreference();
      if (route != speakerNetworkIp) return;

      final ip = await DBHelper.getSetting(networkSpeakerIpKey);
      if (ip == null || ip.trim().isEmpty) return;

      final portStr = await DBHelper.getSetting(networkSpeakerPortKey);
      final port = int.tryParse(portStr?.trim() ?? '') ?? 80;
      var path = (await DBHelper.getSetting(networkSpeakerPathKey))?.trim() ?? '/play';
      if (path.isEmpty) path = '/play';
      if (!path.startsWith('/')) path = '/$path';

      final uri = Uri(scheme: 'http', host: ip.trim(), port: port, path: path);
      await http
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 5));
    } catch (_) {
      // Best-effort fire — silent failure if speaker is unreachable.
    }
  }

  Future<String> _loadSpeakerRoutePreference() async {
    final stored = await DBHelper.getSetting(_speakerRouteKey);
    if (stored == speakerPhoneSpeaker ||
        stored == speakerSystemDefault ||
        stored == speakerNetworkIp) {
      return stored!;
    }
    return speakerSystemDefault;
  }

  AudioAttributesUsage _audioUsageForRoute(String route) {
    if (route == speakerPhoneSpeaker) {
      return AudioAttributesUsage.alarm;
    }
    return AudioAttributesUsage.notification;
  }

  Future<void> _createAndroidCustomChannel({
    required String channelId,
    required String prayerName,
    required String uri,
  }) async {
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidPlugin == null) {
      return;
    }

    await androidPlugin.createNotificationChannel(
      AndroidNotificationChannel(
        channelId,
        'Athan Tone: Custom ($prayerName)',
        description: 'Prayer reminders with your selected custom audio file',
        importance: Importance.max,
        playSound: true,
        sound: UriAndroidNotificationSound(uri),
      ),
    );
  }

  String _customTonePathKey(String prayerName) =>
      'alarm_tone_custom_path_${prayerName.toLowerCase()}';

  (String, String, RawResourceAndroidNotificationSound?, String?)
  _tonePlatformConfig(String tone) {
    switch (tone) {
      case _toneMuezzin1:
        return (
          'athan_tone_muezzin_1',
          'Athan Tone: Muezzin Voice 1',
          const RawResourceAndroidNotificationSound('athan_muezzin_1'),
          null,
        );
      case _toneMuezzin2:
        return (
          'athan_tone_muezzin_2',
          'Athan Tone: Muezzin Voice 2',
          const RawResourceAndroidNotificationSound('athan_muezzin_2'),
          null,
        );
      case _toneBeep:
      default:
        return (
          'athan_tone_beep',
          'Athan Tone: Beep',
          const RawResourceAndroidNotificationSound('athan_beep'),
          null,
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
    final datePart = (time.year * 10000) + (time.month * 100) + time.day;
    return datePart * 10 + prayerOffset;
  }
}
