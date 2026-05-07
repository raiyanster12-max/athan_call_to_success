import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/services.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:googlecast/CastController.dart';
import 'package:googlecast/googlecast.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'db_helper.dart';
import 'mosque_service.dart';
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
    // Wrap in a timeout to keep the isolate alive long enough for streaming
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
  static const String speakerPhoneSpeaker = 'Phone Speaker (Alarm Stream)';
  static const String overrideMuteKey = 'settings_override_mute';
  static const String actionStopAthan = 'stop_athan_action';
  static const String googleCastMediaUrlKey = 'google_cast_media_url';
  static const String toneCustom = 'CUSTOM_FILE';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  AudioPlayer? _testAudioPlayer;
  bool _initialized = false;
  Future<void>? _initializationFuture;

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
      // If we are on Android and the preferred route is Cast, try to reconnect
      // in the background as soon as the app/service starts.
      if (defaultTargetPlatform == TargetPlatform.android) {
        final route = await _loadSpeakerRoutePreference();
        if (route == speakerGoogleCast || route == speakerGoogleCastIp) {
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
      await Future.delayed(const Duration(seconds: 3));

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
            'athan_alerts',
            'Athan Alerts',
            channelDescription: 'Prayer time notifications and Athan playback',
            importance: Importance.max,
            priority: Priority.high,
            fullScreenIntent: true,
            category: AndroidNotificationCategory.alarm,
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
  }) async {
    if (defaultTargetPlatform != TargetPlatform.android) return;

    debugPrint('[ATHAN_SIGNAL] START_TRIGGER: $prayerName (Background: $isBackground)');
    try {
      final connected = await _ensureCastConnected();

      if (!connected) {
        debugPrint(
          '[ATHAN_BG_SERVICE] Cast connection failed. Falling back to phone speaker.',
        );
        if (isBackground) {
          await _showFallbackNotification(
            prayerName,
            'Cast unavailable — athan playing on phone.',
          );
        }
        await _triggerPhoneSpeakerNow(prayerName: prayerName);
        if (isBackground) {
          await Future.delayed(const Duration(seconds: 180));
        }
        return;
      }

      final resolvedName = await _resolvePrayerNameForTrigger(prayerName);
      final mediaUrl = await _resolveCastUrlForPrayer(resolvedName);

      if (mediaUrl == null || mediaUrl.isEmpty) {
        debugPrint('[ATHAN_BG_SERVICE] No media URL found for $resolvedName. Falling back.');
        if (isBackground) {
          await _showFallbackNotification(
            prayerName,
            'No Cast media URL set — athan playing on phone.',
          );
        }
        await _triggerPhoneSpeakerNow(prayerName: prayerName);
        if (isBackground) {
          await Future.delayed(const Duration(seconds: 180));
        }
        return;
      }

      final castController = CastController();
      await castController.setMedia(
        url: mediaUrl.trim(),
        title: '$resolvedName Athan',
      );

      await castController.loadAudio();
      await castController.play();

      // ISOLATE PROTECTION: When the app is in the background, the speaker is
      // pulling the file from the local server. We must keep the isolate alive.
      if (isBackground) {
        debugPrint(
          '[ATHAN_BG_SERVICE] Isolate active for streaming duration...',
        );
        await Future.delayed(const Duration(seconds: 300));
      }
    } catch (e) {
      debugPrint('[ATHAN_BG_SERVICE] Cast Trigger Error: $e');
      if (isBackground) {
        await _showFallbackNotification(
          prayerName,
          'Cast error — athan playing on phone.',
        );
      }
      await _triggerPhoneSpeakerNow(prayerName: prayerName);
      if (isBackground) {
        await Future.delayed(const Duration(seconds: 180));
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
    } else {
      // Direct local playback if route is Phone Speaker or as fallback
      await _triggerPhoneSpeakerNow(prayerName: prayerName);

      if (isBackground) {
        debugPrint('[ATHAN_BG_SERVICE] Isolate active for local playback...');
        await Future.delayed(const Duration(seconds: 300));
      }
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // PHONE SPEAKER & CLEANUP
  // ───────────────────────────────────────────────────────────────────────────

  Future<void> _triggerPhoneSpeakerNow({String? prayerName}) async {
    debugPrint('[ATHAN_BG_SERVICE] Triggering Phone Speaker local playback...');
    try {
      final tone = await _loadTonePreference(prayerName);
      final isOverrideMute =
          (await DBHelper.getSetting(overrideMuteKey)) == 'true';

      _testAudioPlayer?.stop();
      _testAudioPlayer?.dispose();
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
    } catch (e) {
      debugPrint('[ATHAN_BG_SERVICE] Phone speaker trigger error: $e');
    }
  }

  String _mapToneToAsset(String tone) {
    switch (tone) {
      case 'Muezzin Voice 1 with Fajr Athan':
        return 'audio/athan_muezzin_1.mp3';
      case 'Muezzin Voice 2 with Mishary Alafasi':
        return 'audio/athan_muezzin_2.mp3';
      case 'Abbu_Athan':
        return 'audio/athan_abbu_athan.mp3';
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

  Future<void> cancelAllNotifications() async {
    if (kIsWeb) return;
    await initialize();
    await _plugin.cancelAll();
  }

  Future<void> stopAllPlayback() async {
    try {
      _testAudioPlayer?.stop();
      if (await GoogleChromeCast.isConnected()) {
        final castController = CastController();
        await castController.stop();
      }
    } catch (e) {
      debugPrint('Error stopping playback: $e');
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // HELPERS
  // ───────────────────────────────────────────────────────────────────────────

  String? _prayerNameFromPayload(String? payload) {
    if (payload == null) return null;
    if (payload.contains('Fajr')) return 'Fajr';
    if (payload.contains('Dhuhr')) return 'Dhuhr';
    if (payload.contains('Asr')) return 'Asr';
    if (payload.contains('Maghrib')) return 'Maghrib';
    if (payload.contains('Isha')) return 'Isha';
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

  Future<String?> _resolveCastUrlForPrayer(String resolvedName) async {
    final prayerUrl = await DBHelper.getSetting(
      'google_cast_media_url_${resolvedName.toLowerCase()}',
    );
    if (prayerUrl != null && prayerUrl.trim().isNotEmpty) {
      return prayerUrl.trim();
    }
    return await DBHelper.getSetting(googleCastMediaUrlKey);
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
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'athan_alerts',
              'Athan Alerts',
              channelDescription: 'Prayer time notifications and Athan playback',
              importance: Importance.max,
              priority: Priority.high,
              fullScreenIntent: true,
              category: AndroidNotificationCategory.alarm,
              actions: [
                AndroidNotificationAction(
                  actionStopAthan,
                  'Stop Athan',
                  showsUserInterface: true,
                ),
              ],
            ),
            iOS: DarwinNotificationDetails(
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
  }

  Future<void> triggerSelectedSpeakerNow({required String prayerName}) async {
    await _triggerNetworkSpeakerIfConfigured(
      payload: 'PRAYER_$prayerName',
      isBackground: false,
    );
  }

  Future<String> testSelectedSpeakerNow({
    required String routeOverride,
    String? prayerOverride,
  }) async {
    final prayerName = prayerOverride ?? 'Fajr';
    try {
      if (routeOverride == speakerGoogleCast || routeOverride == speakerGoogleCastIp) {
        await _triggerGoogleCastIfConfigured(
          prayerName: prayerName,
          isBackground: false,
        );
        return 'Test command sent to Google Cast ($prayerName)';
      } else {
        await _triggerPhoneSpeakerNow(prayerName: prayerName);
        return 'Local playback started ($prayerName)';
      }
    } catch (e) {
      return 'Test failed: $e';
    }
  }
}
