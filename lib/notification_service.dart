import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:googlecast/CastController.dart';
import 'package:googlecast/googlecast.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'db_helper.dart';
import 'prayer_service.dart';

import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';

// ─────────────────────────────────────────────────────────────────────────────
// TOP-LEVEL background callbacks
// ─────────────────────────────────────────────────────────────────────────────

@pragma('vm:entry-point')
Future<void> onDidReceiveBackgroundNotificationResponse(
  NotificationResponse response,
) async {
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('[ATHAN_BG_SERVICE] Background notification response received');

  try {
    await NotificationService.instance.initialize();
    await NotificationService.instance
        ._triggerNetworkSpeakerIfConfigured(
          payload: response.payload,
          isBackground: true,
        )
        .timeout(const Duration(minutes: 5));
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

void stopAllPlayback() {
  NotificationService.instance._stopAllPlaybackInternal();
}

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  // Constants
  static const String preferredCastSpeakerNameKey =
      'preferred_cast_speaker_name';
  static const String _speakerRouteKey = 'notification_speaker_route';
  static const String speakerGoogleCast = 'Google/Chromecast Speaker';
  static const String speakerPhoneSpeaker = 'Phone Speaker (Alarm Stream)';
  static const String overrideMuteKey = 'settings_override_mute';
  static const String actionStopAthan = 'stop_athan_action';
  static const String googleCastMediaUrlKey = 'google_cast_media_url';
  static const String toneCustomFile = 'Custom File';
  static const String _storedLatKey = 'stored_lat';
  static const String _storedLonKey = 'stored_lon';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  AudioPlayer? _testAudioPlayer;

  bool _initialized = false;
  Future<void>? _initializationFuture;

  Future<void> initialize() async {
    if (kIsWeb || _initialized) return;
    _initializationFuture ??= _doInitialize();
    return _initializationFuture;
  }

  Future<void> _doInitialize() async {
    try {
      await _configureLocalTimezone();
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
          } else {
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
  // FIXED: Robust Cast connection helper
  // ───────────────────────────────────────────────────────────────────────────
  Future<bool> _ensureCastConnected() async {
    debugPrint('[ATHAN_BG_SERVICE] Google Cast: Ensuring connection...');
    try {
      if (await GoogleChromeCast.isConnected()) return true;

      await GoogleChromeCast.startDiscovery();
      final savedName = await DBHelper.getSetting(preferredCastSpeakerNameKey);
      if (savedName == null || savedName.isEmpty) return false;

      // STABILITY FIX: Retry discovery 5 times (1s interval) in the background isolate
      for (int i = 0; i < 5; i++) {
        final found = await GoogleChromeCast.reconnectToDevice(savedName);
        if (found) {
          debugPrint('[ATHAN_BG_SERVICE] Reconnected to $savedName');
          return true;
        }
        await Future.delayed(const Duration(seconds: 1));
      }
      return false;
    } catch (e) {
      debugPrint('[ATHAN_BG_SERVICE] Cast Connection error: $e');
      return false;
    }
  }

  Future<void> _triggerGoogleCastIfConfigured({
    String? prayerName,
    bool isBackground = false,
  }) async {
    if (defaultTargetPlatform != TargetPlatform.android) return;

    try {
      final connected = await _ensureCastConnected();
      if (!connected) {
        debugPrint('[ATHAN_BG_SERVICE] Cast connection failed. Falling back.');
        if (isBackground) await _triggerPhoneSpeakerNow(prayerName: prayerName);
        return;
      }

      final resolvedName = _resolvePrayerNameForTrigger(prayerName);
      final mediaUrl = await _resolveCastUrlForPrayer(resolvedName);
      if (mediaUrl == null) return;

      final castController = CastController();
      await castController.setMedia(
        url: mediaUrl.trim(),
        title: '$resolvedName Athan',
      );
      await castController.loadAudio();
      await castController.play();

      // ISOLATE PROTECTION: Keep isolate alive while the speaker streams from local server
      if (isBackground) {
        await Future.delayed(const Duration(seconds: 180));
      }
    } catch (e) {
      debugPrint('[ATHAN_BG_SERVICE] Cast Trigger Error: $e');
    }
  }

  Future<void> _triggerNetworkSpeakerIfConfigured({
    String? payload,
    bool isBackground = false,
  }) async {
    final route = await _loadSpeakerRoutePreference();
    final prayerName = _prayerNameFromPayload(payload);

    if (route == speakerGoogleCast) {
      await _triggerGoogleCastIfConfigured(
        prayerName: prayerName,
        isBackground: isBackground,
      );
    } else if (isBackground) {
      await _triggerPhoneSpeakerNow(prayerName: prayerName);
    }
  }

  Future<void> scheduleRollingPrayerNotifications({
    required double latitude,
    required double longitude,
  }) async {
    await DBHelper.setSetting(_storedLatKey, latitude.toString());
    await DBHelper.setSetting(_storedLonKey, longitude.toString());
    await _plugin.cancelAll();

    final now = DateTime.now();
    final overrideMute =
        (await DBHelper.getSetting(overrideMuteKey))?.toLowerCase() == 'true';

    for (int day = 0; day < 7; day++) {
      final date = now.add(Duration(days: day));
      final times = PrayerService.getTimesForDate(latitude, longitude, date);
      for (final prayer in PrayerService.getObligatoryPrayers(times)) {
        if (prayer.time.isBefore(now)) continue;
        final id = _notificationIdForPrayer(prayer.name, date);
        await _plugin.zonedSchedule(
          id,
          '${prayer.name} Prayer Time',
          'Tap to play Athan',
          tz.TZDateTime.from(prayer.time, tz.local),
          _buildNotificationDetails(overrideMute: overrideMute),
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          androidScheduleMode: AndroidScheduleMode.alarmClock,
          payload: prayer.name,
        );
      }
    }
  }

  Future<void> rescheduleUsingStoredLocation() async {
    final latStr = await DBHelper.getSetting(_storedLatKey);
    final lonStr = await DBHelper.getSetting(_storedLonKey);
    final lat = double.tryParse(latStr ?? '');
    final lon = double.tryParse(lonStr ?? '');
    if (lat == null || lon == null) return;
    await scheduleRollingPrayerNotifications(latitude: lat, longitude: lon);
  }

  Future<String> testSelectedSpeakerNow({
    String? routeOverride,
    String? prayerOverride,
  }) async {
    try {
      final route = routeOverride ?? await _loadSpeakerRoutePreference();
      final effectivePrayer = prayerOverride ?? await _resolveNextPrayerName();

      if (route == speakerGoogleCast) {
        await _triggerGoogleCastIfConfigured(
          prayerName: effectivePrayer,
          isBackground: false,
        );
      } else {
        await _triggerPhoneSpeakerNow(prayerName: effectivePrayer);
      }
      return 'Triggered $effectivePrayer via $route';
    } catch (e) {
      return 'Trigger failed: $e';
    }
  }

  Future<String> _resolveNextPrayerName() async {
    final latStr = await DBHelper.getSetting(_storedLatKey);
    final lonStr = await DBHelper.getSetting(_storedLonKey);
    final lat = double.tryParse(latStr ?? '');
    final lon = double.tryParse(lonStr ?? '');
    if (lat == null || lon == null) return 'Fajr';
    return PrayerService.getNextPrayer(lat, lon).name;
  }

  String _resolvePrayerNameForTrigger(String? prayerName) {
    const valid = {'Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'};
    if (prayerName != null && valid.contains(prayerName)) return prayerName;
    return prayerName ?? 'Athan';
  }

  String? _prayerNameFromPayload(String? payload) {
    if (payload == null || payload.trim().isEmpty) return null;
    return payload.trim();
  }

  Future<void> _triggerPhoneSpeakerNow({String? prayerName}) async {
    try {
      final resolvedName = _resolvePrayerNameForTrigger(prayerName);
      final tone =
          await DBHelper.getSetting(
            'alarm_tone_${resolvedName.toLowerCase()}',
          ) ??
          'Beep';

      _stopAllPlaybackInternal();
      _testAudioPlayer = AudioPlayer();

      if (tone == toneCustomFile) {
        final customPath = await DBHelper.getSetting(
          'alarm_tone_custom_path_${resolvedName.toLowerCase()}',
        );
        if (customPath != null && customPath.isNotEmpty) {
          await _testAudioPlayer!.play(DeviceFileSource(customPath));
          return;
        }
      }
      await _testAudioPlayer!.play(AssetSource(_assetPathForTone(tone)));
    } catch (e) {
      debugPrint('[ATHAN_BG_SERVICE] Phone speaker error: $e');
    }
  }

  void _stopAllPlaybackInternal() {
    _testAudioPlayer?.stop();
    _testAudioPlayer?.dispose();
    _testAudioPlayer = null;
  }

  String _assetPathForTone(String tone) {
    switch (tone) {
      case 'Muezzin Voice 1 with Fajr Athan':
        return 'audio/athan_muezzin_1.mp3';
      case 'Muezzin Voice 2 with Mishary Alafasi':
        return 'audio/athan_muezzin_2.mp3';
      case 'Abbu_Athan':
        return 'audio/athan_abbu_athan.mp3';
      default:
        return 'audio/athan_beep.wav';
    }
  }

  int _notificationIdForPrayer(String name, DateTime date) {
    const prayerOrder = {
      'Fajr': 0,
      'Dhuhr': 1,
      'Asr': 2,
      'Maghrib': 3,
      'Isha': 4,
    };
    final dayOfYear = date.difference(DateTime(date.year, 1, 1)).inDays;
    return (dayOfYear * 5 + (prayerOrder[name] ?? 0)) % 0x7FFFFFFF;
  }

  NotificationDetails _buildNotificationDetails({bool overrideMute = true}) {
    final channelId = overrideMute
        ? 'athan_alarm_channel'
        : 'athan_normal_channel';
    final channelName = overrideMute ? 'Athan Alarm' : 'Athan Notification';

    return NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        importance: Importance.max,
        priority: Priority.max,
        category: AndroidNotificationCategory.alarm,
        audioAttributesUsage: AudioAttributesUsage.alarm,
        actions: [AndroidNotificationAction(actionStopAthan, 'Stop')],
      ),
    );
  }

  triggerSelectedSpeakerNow({required String prayerName}) {}
}

extension on NotificationService {
  Future<String> _loadSpeakerRoutePreference() async {
    final stored = await DBHelper.getSetting(
      NotificationService._speakerRouteKey,
    );
    if (stored == NotificationService.speakerGoogleCast) {
      return NotificationService.speakerGoogleCast;
    }
    return NotificationService.speakerPhoneSpeaker;
  }

  Future<void> _configureLocalTimezone() async {
    tz.initializeTimeZones();
    final timezoneName = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(timezoneName));
  }

  Future<String?> _resolveCastUrlForPrayer(String resolvedName) async {
    final prayerUrl = await DBHelper.getSetting(
      'google_cast_media_url_${resolvedName.toLowerCase()}',
    );
    if (prayerUrl != null && prayerUrl.trim().isNotEmpty) {
      return prayerUrl.trim();
    }
    final globalUrl = await DBHelper.getSetting(
      NotificationService.googleCastMediaUrlKey,
    );
    if (globalUrl != null && globalUrl.trim().isNotEmpty) {
      return globalUrl.trim();
    }
    return null;
  }
}
