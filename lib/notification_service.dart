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
  static const String _speakerRouteKey = 'notification_speaker_route';
  static const String speakerGoogleCast = 'Google/Chromecast Speaker';
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

  static String? get toneCustomFile => null;

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
  // STABLE CAST CONNECTION LOGIC
  // ───────────────────────────────────────────────────────────────────────────

  Future<bool> _ensureCastConnected() async {
    debugPrint('[ATHAN_BG_SERVICE] Google Cast: Ensuring connection...');
    try {
      if (await GoogleChromeCast.isConnected()) return true;

      // Force discovery to refresh the mDNS cache
      await GoogleChromeCast.startDiscovery();

      final savedName = await DBHelper.getSetting(preferredCastSpeakerNameKey);
      if (savedName == null || savedName.isEmpty) {
        debugPrint('[ATHAN_BG_SERVICE] No preferred speaker name found in DB.');
        return false;
      }

      // Reconnection Loop: Background isolates need extra time to resolve mDNS
      for (int i = 0; i < 5; i++) {
        debugPrint(
          '[ATHAN_BG_SERVICE] Attempting reconnection to $savedName (Try ${i + 1}/5)',
        );
        final found = await GoogleChromeCast.reconnectToDevice(savedName);
        if (found) {
          debugPrint(
            '[ATHAN_BG_SERVICE] Reconnected successfully to $savedName',
          );
          return true;
        }
        await Future.delayed(const Duration(seconds: 1));
      }

      return false;
    } catch (e) {
      debugPrint('[ATHAN_BG_SERVICE] Cast connection error: $e');
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
        debugPrint(
          '[ATHAN_BG_SERVICE] Cast connection failed. Falling back to phone speaker.',
        );
        if (isBackground) await _triggerPhoneSpeakerNow(prayerName: prayerName);
        return;
      }

      final resolvedName = await _resolvePrayerNameForTrigger(prayerName);
      final mediaUrl = await _resolveCastUrlForPrayer(resolvedName);

      if (mediaUrl == null || mediaUrl.isEmpty) {
        debugPrint('[ATHAN_BG_SERVICE] No media URL found for $resolvedName');
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
      // Direct local playback if route isn't Cast
      await _triggerPhoneSpeakerNow(prayerName: prayerName);
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // PHONE SPEAKER & CLEANUP
  // ───────────────────────────────────────────────────────────────────────────

  Future<void> _triggerPhoneSpeakerNow({String? prayerName}) async {
    debugPrint('[ATHAN_BG_SERVICE] Triggering Phone Speaker local playback...');
    try {
      final resolvedName = await _resolvePrayerNameForTrigger(prayerName);
      final assetPath = await _resolveLocalAssetForPrayer(resolvedName);

      if (assetPath == null || assetPath.isEmpty) {
        debugPrint('[ATHAN_BG_SERVICE] No local asset found for $resolvedName');
        return;
      }

      _testAudioPlayer?.dispose();
      _testAudioPlayer = AudioPlayer();
      _testAudioPlayer!.setReleaseMode(ReleaseMode.stop);

      // Use the Alarm stream for background reliability if possible,
      // though audioplayers defaults to media.
      await _testAudioPlayer!.play(AssetSource(assetPath));

      debugPrint('[ATHAN_BG_SERVICE] Local playback started: $assetPath');
    } catch (e) {
      debugPrint('[ATHAN_BG_SERVICE] Local playback error: $e');
    }
  }

  Future<String?> _resolveLocalAssetForPrayer(String resolvedName) async {
    // Default asset names based on prayer
    final name = resolvedName.toLowerCase();
    if (name == 'fajr') return 'audio/fajr_athan.mp3';
    return 'audio/standard_athan.mp3';
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

  Future<String> testSelectedSpeakerNow({
    required String routeOverride,
    String? prayerOverride,
  }) async {
    return '';
  }
}
