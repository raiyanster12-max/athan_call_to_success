import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:geolocator/geolocator.dart';
// [Settings-page-fixes] CastController unused after Stop fix — import removed
// import 'package:googlecast/CastController.dart';
import 'package:googlecast/googlecast.dart';
import 'package:path/path.dart' as path_lib;
import 'package:permission_handler/permission_handler.dart';

import 'package:google_sign_in/google_sign_in.dart';

import 'app_palette.dart';
import 'db_helper.dart';
import 'gallery_theme.dart';
import 'notification_service.dart';
import 'onboarding_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  static const List<String> _prayerNames = [
    'Fajr',
    'Dhuhr',
    'Asr',
    'Maghrib',
    'Isha',
  ];

  static const List<String> _toneOptions = [
    'Beep',
    'Fajr Athan by Mishary Rashid',
    'Athan by Mishary Rashid',
    'Athan by Wakilur R Chowdhury',
  ];

  static final String _customFileTone = NotificationService.toneCustomFile ?? '';
  static const String _speakerRouteKey = 'notification_speaker_route';
  static const String _googleCastMediaUrlKey =
      NotificationService.googleCastMediaUrlKey;
  static const String _preferredCastSpeakerNameKey =
      NotificationService.preferredCastSpeakerNameKey;
  static const String _preferredCastSpeakerIpKey =
      NotificationService.preferredCastSpeakerIpKey;
  static const String _overrideMuteKey = NotificationService.overrideMuteKey;
  static const String _showHijriDateKey = 'settings_show_hijri_date';
  static const String _popupNotificationKey =
      NotificationService.popupNotificationKey;
  static const String _autoTestPrayerValue = '__auto_next__';

  Color get _pageBackground => AppPalette.pageBackground;
  Color get _surfaceBackground => AppPalette.dark.surface;
  Color get _surfaceHighlight => AppPalette.dark.surfaceRaised;
  Color get _dividerColor => AppPalette.dark.outline;
  Color get _primaryText => AppPalette.dark.textPrimary;
  Color get _secondaryText => AppPalette.dark.textSecondary;
  Color get _textMuted => AppPalette.dark.textMuted;
  static const Color _sectionAccent = AppPalette.accent;
  Color get _iconBackground => AppPalette.dark.panel;

  static const List<String> _speakerRouteOptions = [
    NotificationService.speakerPhoneSpeaker,
    NotificationService.speakerGoogleCast,
    NotificationService.speakerGoogleCastIp,
    NotificationService.speakerPhoneAndCast,
  ];

  LocationPermission? _locationPermission;
  PermissionStatus? _notificationPermission;
  PermissionStatus? _batteryOptimizationPermission;
  PermissionStatus? _systemAlertWindowPermission;
  bool _isLoading = true;
  String _speakerRoute = NotificationService.speakerPhoneSpeaker;
  final TextEditingController _googleCastMediaUrlController =
      TextEditingController();
  final Map<String, String> _tonePreferences = {
    for (final prayer in _prayerNames) prayer: 'Beep',
  };
  final Map<String, String> _customToneFileNames = {
    for (final prayer in _prayerNames) prayer: '',
  };
  final Map<String, TextEditingController> _castUrlControllers = {
    for (final prayer in _prayerNames) prayer: TextEditingController(),
  };

  AudioPlayer? _audioPlayer;
  String? _playingPrayer;
  // [Settings-page-fixes] _castController unused — Stop now routes through NotificationService.stopAllPlayback
  // final CastController _castController = CastController();
  StreamSubscription<bool>? _castConnectionSub;
  StreamSubscription<String?>? _castMessageSub;
  bool _castConnected = false;
  String _lastCastState = 'Not connected';
  String _preferredCastSpeakerName = '';
  String _preferredCastSpeakerIp = '';
  bool _overrideMute = true;
  bool _popupNotification = true;
  bool _showHijriDate = true;
  String _testPrayerSelection = _autoTestPrayerValue;

  bool get _supportsBatteryOptimizationPermission =>
      defaultTargetPlatform == TargetPlatform.android;

  @override
  void initState() {
    super.initState();
    _initializeCastConnectionListener();
    _loadSettings();
    _refreshCastConnectionState();
    _startCastReconnectIfNeeded();
    GalleryThemeService.instance.addListener(_onGalleryThemeChange);
  }

  @override
  void dispose() {
    GalleryThemeService.instance.removeListener(_onGalleryThemeChange);
    _audioPlayer?.stop();
    _audioPlayer?.dispose();
    _castConnectionSub?.cancel();
    _castMessageSub?.cancel();
    _googleCastMediaUrlController.dispose();
    for (final c in _castUrlControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _onGalleryThemeChange() => setState(() {});

  void _initializeCastConnectionListener() {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    final cast = GoogleChromeCast();
    _castConnectionSub = cast.connectionState.listen((connected) {
      if (!mounted) return;
      setState(() {
        _castConnected = connected;
        _lastCastState = connected ? 'Connected' : 'Disconnected';
      });
    });
    _castMessageSub = cast.messageStream.listen((state) {
      if (!mounted || state == null || state.trim().isEmpty) return;
      final message = state.trim();
      String? parsedDeviceName;
      if (message.startsWith('SESSION_CONNECTED')) {
        final match = RegExp(r'SESSION_CONNECTED\((.+)\)').firstMatch(message);
        final name = match?.group(1)?.trim();
        if (name != null && name.isNotEmpty) {
          parsedDeviceName = name;
        }
      }
      setState(() {
        _lastCastState = message;
        if (message.startsWith('SESSION_CONNECTED')) {
          _castConnected = true;
          if (parsedDeviceName != null) {
            _preferredCastSpeakerName = parsedDeviceName;
          }
        } else if (message.startsWith('SESSION_ENDED') ||
            message.startsWith('SESSION_SUSPENDED') ||
            message.startsWith('NO_CAST_SESSION')) {
          _castConnected = false;
        }
      });
      if (parsedDeviceName != null) {
        DBHelper.setSetting(_preferredCastSpeakerNameKey, parsedDeviceName);
      }
    });
  }

  void _startCastReconnectIfNeeded() {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    GoogleChromeCast.startDiscovery()
        .then((_) async {
          final savedName = await DBHelper.getSetting(
            _preferredCastSpeakerNameKey,
          );
          if (savedName == null || savedName.isEmpty) {
            if (mounted) await _refreshCastConnectionState();
            return;
          }
          // Poll up to 12s for the saved device to appear in mDNS routes, then reconnect.
          for (int i = 0; i < 12; i++) {
            await Future.delayed(const Duration(seconds: 1));
            if (!mounted) return;
            if (await GoogleChromeCast.isConnected()) {
              if (mounted) await _refreshCastConnectionState();
              return;
            }
            final devices = await GoogleChromeCast.getDiscoveredDevices();
            if (devices.contains(savedName)) {
              final found = await GoogleChromeCast.reconnectToDevice(savedName);
              if (found) {
                await Future.delayed(const Duration(seconds: 2));
                if (mounted) await _refreshCastConnectionState();
                return;
              }
            }
          }
          if (mounted) await _refreshCastConnectionState();
        })
        .catchError((_) {});
  }

  Future<void> _refreshCastConnectionState() async {
    if (defaultTargetPlatform != TargetPlatform.android || !mounted) {
      return;
    }
    final connected = await GoogleChromeCast.isConnected();
    if (!mounted) return;
    setState(() {
      _castConnected = connected;
      _lastCastState = connected ? 'Connected' : 'Not connected';
    });
  }

  Future<bool> _ensureCastDiscoveryPermissions() async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return true;
    }

    var locationPermission = await Geolocator.checkPermission();
    if (locationPermission == LocationPermission.denied) {
      locationPermission = await Geolocator.requestPermission();
    }
    if (locationPermission == LocationPermission.denied ||
        locationPermission == LocationPermission.deniedForever) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Location permission is required to discover Cast devices on your network.',
          ),
        ),
      );
      return false;
    }

    final nearbyWifiStatus = await Permission.nearbyWifiDevices.status;
    if (nearbyWifiStatus != PermissionStatus.granted) {
      final requested = await Permission.nearbyWifiDevices.request();
      if (requested != PermissionStatus.granted) {
        if (!mounted) return false;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Nearby Wi-Fi devices permission is required to discover Cast speakers.',
            ),
          ),
        );
        return false;
      }
    }

    if (mounted) {
      setState(() => _locationPermission = locationPermission);
    }
    return true;
  }

  Future<void> _loadSettings() async {
    final locationPermission = await Geolocator.checkPermission();
    final notificationPermission = await Permission.notification.status;
    final batteryOptimizationPermission = _supportsBatteryOptimizationPermission
        ? await Permission.ignoreBatteryOptimizations.status
        : null;
    final systemAlertWindowPermission = _supportsBatteryOptimizationPermission
        ? await Permission.systemAlertWindow.status
        : null;
    final storedSpeakerRoute = await DBHelper.getSetting(_speakerRouteKey);
    if (storedSpeakerRoute != null &&
        _speakerRouteOptions.contains(storedSpeakerRoute)) {
      _speakerRoute = storedSpeakerRoute;
    }

    final storedCastUrl = await DBHelper.getSetting(_googleCastMediaUrlKey);
    final storedPreferredCastName = await DBHelper.getSetting(
      _preferredCastSpeakerNameKey,
    );
    final storedPreferredCastIp = await DBHelper.getSetting(
      _preferredCastSpeakerIpKey,
    );
    if (storedCastUrl != null && storedCastUrl.trim().isNotEmpty) {
      _googleCastMediaUrlController.text = storedCastUrl;
    } else {
      _googleCastMediaUrlController.text =
          'https://download.samplelib.com/mp3/sample-3s.mp3';
    }
    _preferredCastSpeakerName = (storedPreferredCastName ?? '').trim();
    _preferredCastSpeakerIp = (storedPreferredCastIp ?? '').trim();

    _overrideMute = await _loadBoolSetting(_overrideMuteKey, fallback: true);
    _popupNotification =
        await _loadBoolSetting(_popupNotificationKey, fallback: true);
    _showHijriDate = await _loadBoolSetting(_showHijriDateKey, fallback: true);

    for (final prayer in _prayerNames) {
      var storedTone = await DBHelper.getSetting(_toneKey(prayer));
      // [Settings-page-fixes] Migrate legacy tone names to new display names
      storedTone = _migrateToneName(storedTone);
      if (storedTone != null &&
          (_toneOptions.contains(storedTone) ||
              storedTone == _customFileTone)) {
        _tonePreferences[prayer] = storedTone;
      }

      final customPath = await DBHelper.getSetting(_customTonePathKey(prayer));
      if (customPath != null && customPath.trim().isNotEmpty) {
        _customToneFileNames[prayer] = path_lib.basename(customPath);
      }

      final castUrl = await DBHelper.getSetting(_castUrlKey(prayer));
      if (castUrl != null && castUrl.trim().isNotEmpty) {
        _castUrlControllers[prayer]?.text = castUrl.trim();
      }

      if (_tonePreferences[prayer] == _customFileTone &&
          _customToneFileNames[prayer]!.isEmpty) {
        // Fallback gracefully if custom tone was selected but file is unavailable.
        _tonePreferences[prayer] = _toneOptions.first;
      }
    }

    if (!mounted) return;
    setState(() {
      _locationPermission = locationPermission;
      _notificationPermission = notificationPermission;
      _batteryOptimizationPermission = batteryOptimizationPermission;
      _systemAlertWindowPermission = systemAlertWindowPermission;
      _isLoading = false;
    });
  }

  String _toneKey(String prayer) => 'alarm_tone_${prayer.toLowerCase()}';

  String? _migrateToneName(String? tone) {
    const legacy = {
      'Muezzin Voice 1 with Fajr Athan': 'Fajr Athan by Mishary Rashid',
      'Muezzin Voice 2 with Mishary Alafasi': 'Athan by Mishary Rashid',
      'Abbu_Athan': 'Athan by Wakilur R Chowdhury',
    };
    return legacy[tone] ?? tone;
  }
  String _customTonePathKey(String prayer) =>
      'alarm_tone_custom_path_${prayer.toLowerCase()}';
  String _castUrlKey(String prayer) =>
      'google_cast_media_url_${prayer.toLowerCase()}';

  List<String> get _allToneOptions {
    if (kIsWeb) {
      return _toneOptions;
    }
    return [..._toneOptions, _customFileTone];
  }

  Future<bool> _showPermissionDialog({
    required String title,
    required String message,
  }) async {
    final proceed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Not now'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    return proceed ?? false;
  }

  Future<void> _requestLocationPermission() async {
    final proceed = await _showPermissionDialog(
      title: 'Location Access',
      message:
          'Location is used to detect your city automatically, calculate local prayer times, and support the Qibla and nearby masjid features.',
    );
    if (!proceed) {
      return;
    }

    final permission = await Geolocator.requestPermission();
    if (!mounted) return;
    setState(() => _locationPermission = permission);
  }

  Future<void> _requestNotificationPermission() async {
    final proceed = await _showPermissionDialog(
      title: 'Notification Access',
      message:
          'Notifications are used to deliver Athan reminders and future background prayer alerts on time.',
    );
    if (!proceed) {
      return;
    }

    final status = await Permission.notification.request();
    if (!mounted) return;
    setState(() => _notificationPermission = status);
  }

  Future<void> _requestBatteryOptimizationPermission() async {
    if (!_supportsBatteryOptimizationPermission) {
      return;
    }

    final proceed = await _showPermissionDialog(
      title: 'Unrestricted Battery Access',
      message:
          'To improve background reliability, allow this app to ignore battery optimizations on Android. '
          'On the next system screen choose Allow or Unrestricted.',
    );
    if (!proceed) {
      return;
    }

    final status = await Permission.ignoreBatteryOptimizations.request();
    if (!mounted) return;
    setState(() => _batteryOptimizationPermission = status);
  }

  Future<void> _requestSystemAlertWindowPermission() async {
    if (!_supportsBatteryOptimizationPermission) {
      return;
    }

    final proceed = await _showPermissionDialog(
      title: 'Display Over Other Apps',
      message:
          'This permission is required to show the Athan alert even when you are using other apps or when the screen is locked.',
    );
    if (!proceed) {
      return;
    }

    final status = await Permission.systemAlertWindow.request();
    if (!mounted) return;
    setState(() => _systemAlertWindowPermission = status);
  }

  Future<void> _updateTone(String prayer, String tone) async {
    await DBHelper.setSetting(_toneKey(prayer), tone);
    await NotificationService.instance.rescheduleUsingStoredLocation();
    if (!mounted) return;
    setState(() => _tonePreferences[prayer] = tone);
  }

  Future<void> _updateSpeakerRoute(String route) async {
    if (mounted) {
      setState(() => _speakerRoute = route);
    }
    await DBHelper.setSetting(_speakerRouteKey, route);
    await NotificationService.instance.rescheduleUsingStoredLocation();
  }

  Future<void> _saveGoogleCastMediaUrl() async {
    await DBHelper.setSetting(
      _googleCastMediaUrlKey,
      _googleCastMediaUrlController.text.trim(),
    );
  }

  // [Settings-page-fixes] _playCastUrl unused — only called by commented-out _testGoogleCastPlayback
  // Future<void> _playCastUrl(
  //   String mediaUrl, {
  //   required String title,
  //   required String subtitle,
  //   bool saveUrl = false,
  // }) async {
  //   await _refreshCastConnectionState();
  //   if (mediaUrl.trim().isEmpty) {
  //     if (!mounted) return;
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       const SnackBar(content: Text('Enter a Cast media URL first.')),
  //     );
  //     return;
  //   }
  //   if (saveUrl) {
  //     await _saveGoogleCastMediaUrl();
  //   }
  //   try {
  //     if (!_castConnected) {
  //       if (!mounted) return;
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         const SnackBar(
  //           content: Text(
  //             'Cast is not connected. Tap the Cast icon and select your speaker first.',
  //           ),
  //         ),
  //       );
  //       return;
  //     }
  //     await _castController
  //         .setMedia(url: mediaUrl.trim(), title: title, subtitle: subtitle)
  //         .timeout(const Duration(seconds: 5));
  //     await _castController.loadAudio().timeout(const Duration(seconds: 10));
  //     await _castController.play().timeout(const Duration(seconds: 10));
  //     await Future.delayed(const Duration(milliseconds: 1200));
  //     await _refreshCastConnectionState();
  //     if (!mounted) return;
  //     if (_lastCastState == 'ERROR' || _lastCastState == 'IDLE') {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(
  //           content: Text(
  //             'Cast command sent, but device state is $_lastCastState. '
  //             'If cast audio still does not play, the Cast session/plugin path is the problem.',
  //           ),
  //         ),
  //       );
  //       return;
  //     }
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(content: Text('Cast playback started. State: $_lastCastState')),
  //     );
  //   } catch (e) {
  //     if (!mounted) return;
  //     ScaffoldMessenger.of(context)
  //         .showSnackBar(SnackBar(content: Text('Could not play on Cast: $e')));
  //   }
  // }

  // [Settings-page-fixes] _testGoogleCastPlayback unused — Test Audio button commented out
  // Future<void> _testGoogleCastPlayback() async {
  //   final mediaUrl = _googleCastMediaUrlController.text.trim();
  //   await _playCastUrl(
  //     mediaUrl,
  //     title: 'Athan Test',
  //     subtitle: 'Call to Success',
  //     saveUrl: true,
  //   );
  // }

  Future<void> _testPrayerTriggerNow({
    String? routeOverride,
    String? prayerSelectionOverride,
  }) async {
    // [Settings-page-fixes] Stop any in-progress preview before triggering test
    await _stopPlayback();
    await _saveGoogleCastMediaUrl();
    final activeRoute = routeOverride ?? _speakerRoute;
    final selectedPrayer = prayerSelectionOverride ?? _testPrayerSelection;

    await DBHelper.setSetting(_speakerRouteKey, activeRoute);
    await _refreshCastConnectionState();

    // [Settings-page-fixes] Only block speakerGoogleCast (needs prior discovery session).
    // speakerGoogleCastIp connects itself inside _triggerGoogleCastIfConfigured via IP.
    if (activeRoute == NotificationService.speakerGoogleCast && !_castConnected) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Google Cast route is selected, but no Cast session is connected yet.',
          ),
        ),
      );
      return;
    }

    String message;
    try {
      message = await NotificationService.instance.testSelectedSpeakerNow(
        routeOverride: activeRoute,
        prayerOverride: selectedPrayer == _autoTestPrayerValue
            ? null
            : selectedPrayer,
      );
    } catch (e) {
      message = 'Trigger failed: $e';
    }

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _pickCustomToneForPrayer(String prayer) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: [
        'mp3',
        'wav',
        'm4a',
        'aac',
        'ogg',
        'flac',
        'opus',
        '3gp',
        'amr',
        'wma',
        'aiff',
        'aif',
        'mp4',
        'mkv',
      ],
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) {
      return;
    }

    final selected = result.files.single;
    final selectedPath = selected.path;
    if (selectedPath == null || selectedPath.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not access selected file path.')),
      );
      return;
    }

    await DBHelper.setSetting(_customTonePathKey(prayer), selectedPath);
    await DBHelper.setSetting(_toneKey(prayer), _customFileTone);
    await NotificationService.instance.rescheduleUsingStoredLocation();

    if (!mounted) return;
    setState(() {
      _tonePreferences[prayer] = _customFileTone;
      _customToneFileNames[prayer] = path_lib.basename(selectedPath);
    });
  }

  Future<void> _playCustomTone(String prayer) async {
    // Stop any currently playing audio first.
    await _stopPlayback();

    final customPath = await DBHelper.getSetting(_customTonePathKey(prayer));
    if (customPath == null || customPath.trim().isEmpty) return;

    // ExoPlayer (audioplayers v6 on Android) does not support WMA or AIFF.
    // Detect early and surface a friendly message instead of a silent failure.
    final ext = path_lib
        .extension(customPath)
        .toLowerCase()
        .replaceFirst('.', '');
    const androidUnsupported = {'wma', 'aiff', 'aif'};
    if (defaultTargetPlatform == TargetPlatform.android &&
        androidUnsupported.contains(ext)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '.$ext files are not supported for preview on Android. '
            'Convert to MP3, AAC, WAV, or OGG for playback.',
          ),
          duration: const Duration(seconds: 5),
        ),
      );
      return;
    }

    final player = AudioPlayer();
    player.onPlayerComplete.listen((_) {
      if (identical(_audioPlayer, player)) {
        _audioPlayer = null;
      }
      if (mounted) setState(() => _playingPrayer = null);
      unawaited(player.dispose().catchError((_) {}));
    });

    try {
      await player.play(DeviceFileSource(customPath));
      if (!mounted) {
        await player.dispose();
        return;
      }
      setState(() {
        _audioPlayer = player;
        _playingPrayer = prayer;
      });
    } catch (e) {
      await player.dispose();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not play audio: $e')));
    }
  }

  Future<void> _stopPlayback() async {
    final player = _audioPlayer;
    if (player != null) {
      await player.stop();
      await player.dispose();
    }
    _audioPlayer = null;
    if (mounted) setState(() => _playingPrayer = null);
  }

  Future<void> _clearCustomToneForPrayer(String prayer) async {
    await DBHelper.setSetting(_customTonePathKey(prayer), '');
    await DBHelper.setSetting(_toneKey(prayer), _toneOptions.first);
    await NotificationService.instance.rescheduleUsingStoredLocation();

    if (!mounted) return;
    setState(() {
      _tonePreferences[prayer] = _toneOptions.first;
      _customToneFileNames[prayer] = '';
    });
  }

  String _locationPermissionLabel() {
    switch (_locationPermission) {
      case LocationPermission.always:
      case LocationPermission.whileInUse:
        return 'Granted';
      case LocationPermission.denied:
        return 'Denied';
      case LocationPermission.deniedForever:
        return 'Denied permanently';
      case LocationPermission.unableToDetermine:
      case null:
        return 'Unknown';
    }
  }

  String _notificationPermissionLabel() {
    switch (_notificationPermission) {
      case PermissionStatus.granted:
        return 'Granted';
      case PermissionStatus.denied:
        return 'Denied';
      case PermissionStatus.permanentlyDenied:
        return 'Denied permanently';
      case PermissionStatus.restricted:
        return 'Restricted';
      case PermissionStatus.limited:
        return 'Limited';
      case PermissionStatus.provisional:
        return 'Provisional';
      case null:
        return 'Unknown';
    }
  }

  String _batteryPermissionLabel() {
    switch (_batteryOptimizationPermission) {
      case PermissionStatus.granted:
        return 'Unrestricted enabled';
      case PermissionStatus.denied:
        return 'Restricted by battery optimization';
      case PermissionStatus.permanentlyDenied:
        return 'Denied permanently';
      case PermissionStatus.restricted:
        return 'Restricted';
      case PermissionStatus.limited:
        return 'Limited';
      case PermissionStatus.provisional:
        return 'Provisional';
      case null:
        return 'Unknown';
    }
  }

  String _systemAlertWindowPermissionLabel() {
    switch (_systemAlertWindowPermission) {
      case PermissionStatus.granted:
        return 'Granted';
      case PermissionStatus.denied:
        return 'Denied';
      case PermissionStatus.permanentlyDenied:
        return 'Denied permanently';
      case PermissionStatus.restricted:
        return 'Restricted';
      case PermissionStatus.limited:
        return 'Limited';
      case PermissionStatus.provisional:
        return 'Provisional';
      case null:
        return 'Unknown';
    }
  }

  String _speakerRouteLabel() {
    switch (_speakerRoute) {
      case NotificationService.speakerPhoneSpeaker:
        return 'Phone speaker';
      case NotificationService.speakerGoogleCast:
        return 'Google Speaker';
      case NotificationService.speakerGoogleCastIp:
        return 'Google Cast (IP)';
      case NotificationService.speakerPhoneAndCast:
        return 'Phone + Google Cast';
      default:
        return 'Phone speaker';
    }
  }

  String _alertSettingsSummary() {
    final route = _speakerRouteLabel();
    if (_speakerRoute == NotificationService.speakerGoogleCast ||
        _speakerRoute == NotificationService.speakerGoogleCastIp) {
      final castState = _castConnected ? 'Connected' : 'Not connected';
      if (_speakerRoute == NotificationService.speakerGoogleCastIp &&
          _preferredCastSpeakerIp.isNotEmpty) {
        return '$route • $castState • $_preferredCastSpeakerIp';
      }
      if (_preferredCastSpeakerName.isNotEmpty) {
        return '$route • $castState • $_preferredCastSpeakerName';
      }
      return '$route • $castState';
    }
    return route;
  }

  String _permissionSummary() {
    return 'Location ${_locationPermissionLabel()} • Notifications ${_notificationPermissionLabel()}';
  }

  String _batterySummary() {
    if (!_supportsBatteryOptimizationPermission) {
      return 'Not required on this platform';
    }
    return _batteryPermissionLabel();
  }

  Future<bool> _loadBoolSetting(String key, {bool fallback = false}) async {
    final stored = await DBHelper.getSetting(key);
    if (stored == null) {
      return fallback;
    }
    return stored.toLowerCase() == 'true';
  }

  Future<void> _saveBoolSetting(String key, bool value) async {
    await DBHelper.setSetting(key, value.toString());
  }

  Future<void> _setOverrideMute(bool value) async {
    await _saveBoolSetting(_overrideMuteKey, value);
    if (!mounted) return;
    setState(() => _overrideMute = value);
    // Reschedule so notifications use the correct channel (alarm vs normal stream).
    unawaited(
      NotificationService.instance.rescheduleUsingStoredLocation().catchError(
        (_) {},
      ),
    );
  }

  Future<void> _setPopupNotification(bool value) async {
    await _saveBoolSetting(_popupNotificationKey, value);
    if (!mounted) return;
    setState(() => _popupNotification = value);
    unawaited(
      NotificationService.instance.rescheduleUsingStoredLocation().catchError(
        (_) {},
      ),
    );
  }

  Future<void> _setShowHijriDate(bool value) async {
    await _saveBoolSetting(_showHijriDateKey, value);
    if (!mounted) return;
    setState(() => _showHijriDate = value);
  }

  Future<void> _showCalculationMethodDialog() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Calculation Method'),
        content: const Text(
          'Current calculation method: ISNA (North-America)\nAsr method: Hanafi',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _openAlertSettingsSheet() {
    _refreshCastConnectionState();
    var draftSpeakerRoute = _speakerRoute;
    var draftTestPrayerSelection = _testPrayerSelection;
    var draftReconnecting = false;
    final ipController = TextEditingController(text: _preferredCastSpeakerIp);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (_, setSheetState) => _buildBottomSheetScaffold(
          title: 'Alert Settings',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select where Athan notifications should play and test the route directly.',
                style: TextStyle(color: _secondaryText),
              ),
              const SizedBox(height: 16),
              RadioGroup<String>(
                groupValue: draftSpeakerRoute,
                onChanged: (value) {
                  if (value != null) {
                    setSheetState(() => draftSpeakerRoute = value);
                  }
                },
                child: Column(
                  children: [
                    RadioListTile<String>(
                      activeColor: _sectionAccent,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'Phone',
                        style: TextStyle(color: _primaryText),
                      ),
                      value: NotificationService.speakerPhoneSpeaker,
                    ),
                    RadioListTile<String>(
                      activeColor: _sectionAccent,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'Google Speaker',
                        style: TextStyle(color: _primaryText),
                      ),
                      value: NotificationService.speakerGoogleCast,
                    ),
                    RadioListTile<String>(
                      activeColor: _sectionAccent,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'Google Cast (IP Address Selection)',
                        style: TextStyle(color: _primaryText),
                      ),
                      value: NotificationService.speakerGoogleCastIp,
                    ),
                    RadioListTile<String>(
                      activeColor: _sectionAccent,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'Phone + Google Cast',
                        style: TextStyle(color: _primaryText),
                      ),
                      value: NotificationService.speakerPhoneAndCast,
                    ),
                  ],
                ),
              ),
              if (draftSpeakerRoute == NotificationService.speakerGoogleCast) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () async {
                      final hasPermissions = await _ensureCastDiscoveryPermissions();
                      if (!hasPermissions) return;
                      await GoogleChromeCast.startDiscovery();
                      await Future.delayed(const Duration(seconds: 1));
                      await GoogleChromeCast.showCastDialog();
                      await Future.delayed(const Duration(seconds: 1));
                      await _refreshCastConnectionState();
                    },
                    icon: const Icon(Icons.cast_connected),
                    label: const Text('Select Speaker'),
                  ),
                ),
              ],
              if (draftSpeakerRoute == NotificationService.speakerGoogleCastIp) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: ipController,
                  style: TextStyle(color: _primaryText),
                  decoration: _sheetInputDecoration(
                    'Speaker IP Address',
                    hint: 'e.g. 192.168.1.100',
                  ),
                  keyboardType: TextInputType.number,
                ),
              ],
              if (draftSpeakerRoute == NotificationService.speakerGoogleCast ||
                  draftSpeakerRoute == NotificationService.speakerGoogleCastIp) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _castConnected
                                ? 'Cast connected.'
                                : 'Cast not connected.',
                            style: TextStyle(color: _primaryText),
                          ),
                          if (_preferredCastSpeakerName.isNotEmpty &&
                              draftSpeakerRoute == NotificationService.speakerGoogleCast)
                            Text(
                              'Speaker: $_preferredCastSpeakerName',
                              style: TextStyle(
                                color: _secondaryText,
                                fontSize: 12,
                              ),
                            ),
                          Text(
                            'State: $_lastCastState',
                            style: TextStyle(
                              color: _secondaryText,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: draftReconnecting
                          ? null
                          : () async {
                              setSheetState(() => draftReconnecting = true);
                              await NotificationService.instance.reconnectCast();
                              await _refreshCastConnectionState();
                              setSheetState(() => draftReconnecting = false);
                            },
                      icon: draftReconnecting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.refresh),
                      label: const Text('Refresh'),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: draftTestPrayerSelection,
                dropdownColor: _surfaceBackground,
                style: TextStyle(color: _primaryText),
                decoration: _sheetInputDecoration('Test prayer'),
                items: [
                  DropdownMenuItem<String>(
                    value: _autoTestPrayerValue,
                    child: Text(
                      'Auto (next prayer)',
                      style: TextStyle(color: _primaryText),
                    ),
                  ),
                  ..._prayerNames.map(
                    (prayer) => DropdownMenuItem<String>(
                      value: prayer,
                      child: Text(
                        prayer,
                        style: TextStyle(color: _primaryText),
                      ),
                    ),
                  ),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setSheetState(() => draftTestPrayerSelection = value);
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _testPrayerTriggerNow(
                        routeOverride: draftSpeakerRoute,
                        prayerSelectionOverride: draftTestPrayerSelection,
                      ),
                      icon: const Icon(Icons.notifications_active_outlined),
                      label: const Text('Test Prayer Trigger Now'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // [Settings-page-fixes] Use stopAllPlayback so both Cast and
                  // phone speaker audio (from NotificationService) are stopped
                  OutlinedButton.icon(
                    onPressed: () =>
                        NotificationService.instance.stopAllPlayback(),
                    icon: const Icon(Icons.stop),
                    label: const Text('Stop'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () async {
                        await _updateSpeakerRoute(draftSpeakerRoute);
                        final newIp = ipController.text.trim();
                        await DBHelper.setSetting(_preferredCastSpeakerIpKey, newIp);
                        await _refreshCastConnectionState();
                        if (!mounted) return;
                        setState(() {
                          _testPrayerSelection = draftTestPrayerSelection;
                          _preferredCastSpeakerIp = newIp;
                        });
                        if (!sheetContext.mounted) return;
                        Navigator.of(sheetContext).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Alert settings saved.'),
                          ),
                        );
                      },
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('Save'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ).then((_) {
      if (mounted) {
        _refreshCastConnectionState();
      }
    });
  }

  void _openMoreSettingsSheet() {
    // Local copy of preferences — edited in sheet, committed on Save
    final localPrefs = Map<String, String>.from(_tonePreferences);
    bool saving = false;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheetState) => _buildBottomSheetScaffold(
          title: 'More Prayer Settings',
          child: Column(
            children: [
              for (final prayer in _prayerNames) ...[
                _buildToneEditorLocal(
                  prayer,
                  localPrefs,
                  (val) => setSheetState(() => localPrefs[prayer] = val),
                ),
                const SizedBox(height: 12),
              ],
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: saving
                      ? null
                      : () async {
                          setSheetState(() => saving = true);
                          for (final entry in localPrefs.entries) {
                            await DBHelper.setSetting(
                              _toneKey(entry.key),
                              entry.value,
                            );
                          }
                          await NotificationService.instance
                              .rescheduleUsingStoredLocation()
                              .catchError((_) {});
                          if (mounted) {
                            setState(() => _tonePreferences.addAll(localPrefs));
                          }
                          if (ctx.mounted) Navigator.of(ctx).pop();
                        },
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: saving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Save'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomSheetScaffold({
    required String title,
    required Widget child,
  }) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.82,
      minChildSize: 0.55,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: _surfaceBackground,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: _dividerColor,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                color: _primaryText,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }

  InputDecoration _sheetInputDecoration(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: TextStyle(color: _secondaryText),
      hintStyle: TextStyle(color: _secondaryText),
      filled: true,
      fillColor: _iconBackground,
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: _dividerColor),
        borderRadius: BorderRadius.circular(12),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: _sectionAccent),
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }

  Widget _buildToneEditorLocal(
    String prayer,
    Map<String, String> localPrefs,
    void Function(String) onChanged,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _iconBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            prayer,
            style: TextStyle(
              color: _primaryText,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: localPrefs[prayer],
            dropdownColor: _surfaceBackground,
            style: TextStyle(color: _primaryText),
            decoration: _sheetInputDecoration('Tone'),
            items: _toneOptions
                .map(
                  (tone) => DropdownMenuItem<String>(
                    value: tone,
                    child: Text(
                      tone,
                      style: TextStyle(color: _primaryText),
                    ),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) onChanged(value);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildToneEditor(String prayer) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _iconBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            prayer,
            style: TextStyle(
              color: _primaryText,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: _tonePreferences[prayer],
            dropdownColor: _surfaceBackground,
            style: TextStyle(color: _primaryText),
            decoration: _sheetInputDecoration('Tone'),
            items: _allToneOptions
                .map(
                  (tone) => DropdownMenuItem<String>(
                    value: tone,
                    child: Text(
                      tone,
                      style: TextStyle(color: _primaryText),
                    ),
                  ),
                )
                .toList(),
            onChanged: (value) async {
              if (value == null) return;
              if (value == _customFileTone && !kIsWeb) {
                await _pickCustomToneForPrayer(prayer);
                return;
              }
              await _updateTone(prayer, value);
            },
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _castUrlControllers[prayer],
            style: TextStyle(color: _primaryText, fontSize: 13),
            decoration: _sheetInputDecoration(
              'Cast Audio URL ($prayer)',
              hint: 'https://… (leave blank to use global URL)',
            ),
            keyboardType: TextInputType.url,
          ),
          if (_tonePreferences[prayer] == _customFileTone && !kIsWeb) ...[
            const SizedBox(height: 10),
            Text(
              _customToneFileNames[prayer]!.isEmpty
                  ? 'No custom file selected'
                  : 'Selected: ${_customToneFileNames[prayer]}',
              style: TextStyle(color: _secondaryText, fontSize: 12),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (_customToneFileNames[prayer]!.isNotEmpty)
                  _playingPrayer == prayer
                      ? OutlinedButton.icon(
                          onPressed: _stopPlayback,
                          icon: const Icon(Icons.stop),
                          label: const Text('Stop'),
                        )
                      : OutlinedButton.icon(
                          onPressed: () => _playCustomTone(prayer),
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('Preview'),
                        ),
                OutlinedButton(
                  onPressed: () => _pickCustomToneForPrayer(prayer),
                  child: const Text('Change file'),
                ),
                TextButton(
                  onPressed: () => _clearCustomToneForPrayer(prayer),
                  child: const Text('Use Beep'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPageHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Settings',
            style: TextStyle(
              color: _primaryText,
              fontSize: 32,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.8,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Prayer notifications, device behavior, and date preferences.',
            style: TextStyle(color: _secondaryText, fontSize: 14, height: 1.35),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildStatusChip(
                Icons.notifications_active_outlined,
                'Alerts',
                _speakerRouteLabel(),
              ),
              _buildStatusChip(
                Icons.location_on_outlined,
                'Access',
                _locationPermissionLabel(),
              ),
              _buildStatusChip(
                Icons.battery_charging_full_outlined,
                'Battery',
                _supportsBatteryOptimizationPermission
                    ? (_batteryOptimizationPermission ==
                              PermissionStatus.granted
                          ? 'Unrestricted'
                          : 'Managed')
                    : 'Default',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _surfaceHighlight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _dividerColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: _sectionAccent),
          const SizedBox(width: 8),
          Text(
            '$label: $value',
            style: TextStyle(
              color: _primaryText,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
      child: Text(
        label,
        style: const TextStyle(
          color: _sectionAccent,
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.7,
        ),
      ),
    );
  }

  Widget _buildSectionCard(List<Widget> children) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: _surfaceBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _dividerColor),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildSettingRow({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
    bool enabled = true,
  }) {
    final titleColor = enabled ? _primaryText : _primaryText.withValues(alpha: 0.35);
    final subtitleColor = enabled ? _secondaryText : _textMuted;
    final resolvedTrailing =
        trailing ??
        ((enabled && onTap != null)
            ? Icon(
                Icons.chevron_right_rounded,
                color: _secondaryText,
                size: 24,
              )
            : null);

    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: enabled ? _iconBackground : _surfaceHighlight,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                icon,
                color: enabled ? Colors.white : Colors.white30,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: titleColor,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.3,
                        color: subtitleColor,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (resolvedTrailing != null) ...[
              const SizedBox(width: 12),
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: resolvedTrailing,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRowDivider() {
    return Divider(height: 1, color: _dividerColor, indent: 72);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: _pageBackground,
        appBar: AppBar(backgroundColor: _pageBackground),
        body: const Center(
          child: CircularProgressIndicator(semanticsLabel: 'Loading settings'),
        ),
      );
    }

    final batteryEnabled =
        _batteryOptimizationPermission == PermissionStatus.granted;
    final systemAlertWindowEnabled =
        _systemAlertWindowPermission == PermissionStatus.granted;

    return Scaffold(
      backgroundColor: _pageBackground,
      appBar: AppBar(
        backgroundColor: _pageBackground,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(0, 10, 0, 32),
          children: [
            _buildPageHeader(),
            _buildSectionLabel('Permissions'),
            _buildSectionCard([
              _buildSettingRow(
                icon: Icons.location_on_outlined,
                title: 'Manage Locations',
                subtitle: _permissionSummary(),
                onTap: _requestLocationPermission,
              ),
              _buildRowDivider(),
              _buildSettingRow(
                icon: Icons.notifications_active_outlined,
                title: 'Notification Access',
                subtitle: _notificationPermissionLabel(),
                onTap: _requestNotificationPermission,
              ),
              if (_supportsBatteryOptimizationPermission) ...[
                _buildRowDivider(),
                _buildSettingRow(
                  icon: Icons.layers_outlined,
                  title: 'Display Over Other Apps',
                  subtitle: _systemAlertWindowPermissionLabel(),
                  onTap: _requestSystemAlertWindowPermission,
                  trailing: Checkbox(
                    value: systemAlertWindowEnabled,
                    onChanged: (_) => _requestSystemAlertWindowPermission(),
                    activeColor: _sectionAccent,
                    checkColor: _pageBackground,
                    side: BorderSide(color: _secondaryText),
                  ),
                ),
              ],
            ]),
            _buildSectionLabel('Prayer Times'),
            _buildSectionCard([
              _buildSettingRow(
                icon: Icons.volume_up_outlined,
                title: 'Override Mute',
                subtitle: 'Play Athan even when the phone is muted.',
                trailing: Switch(
                  value: _overrideMute,
                  onChanged: _setOverrideMute,
                  activeThumbColor: _sectionAccent,
                ),
              ),
              _buildRowDivider(),
              _buildSettingRow(
                icon: Icons.notification_important_outlined,
                title: 'Pop-up Notifications',
                subtitle: 'Show a heads-up alert when Athan starts.',
                trailing: Switch(
                  value: _popupNotification,
                  onChanged: _setPopupNotification,
                  activeThumbColor: _sectionAccent,
                ),
              ),
              _buildRowDivider(),
              _buildSettingRow(
                icon: Icons.battery_charging_full_outlined,
                title: 'Ignore Battery Optimizations',
                subtitle: _batterySummary(),
                onTap: _requestBatteryOptimizationPermission,
                trailing: Checkbox(
                  value: batteryEnabled,
                  onChanged: (_) => _requestBatteryOptimizationPermission(),
                  activeColor: _sectionAccent,
                  checkColor: _pageBackground,
                  side: BorderSide(color: _secondaryText),
                ),
              ),
              _buildRowDivider(),
              _buildSettingRow(
                icon: Icons.cast_connected_outlined,
                title: 'Alert Settings',
                subtitle: _alertSettingsSummary(),
                onTap: _openAlertSettingsSheet,
              ),
              _buildRowDivider(),
              _buildSettingRow(
                icon: Icons.auto_awesome_outlined,
                title: 'Calculation Method',
                subtitle: 'ISNA (North-America) • Hanafi Asr',
                onTap: _showCalculationMethodDialog,
              ),
              _buildRowDivider(),
              _buildSettingRow(
                icon: Icons.tune_outlined,
                title: 'More...',
                subtitle: 'Per-prayer tones and custom audio files',
                onTap: _openMoreSettingsSheet,
              ),
            ]),
            _buildSectionLabel('Hijri'),
            _buildSectionCard([
              _buildSettingRow(
                icon: Icons.calendar_month_outlined,
                title: 'Show Hijri Date',
                subtitle: 'Display the Hijri date on the main prayer view.',
                trailing: Switch(
                  value: _showHijriDate,
                  onChanged: _setShowHijriDate,
                  activeThumbColor: _sectionAccent,
                ),
              ),
            ]),
            _buildSectionLabel('Appearance'),
            _buildAppearanceDropdown(),
            _buildSectionLabel('Reset'),
            _buildSectionCard([
              _buildSettingRow(
                icon: Icons.delete_forever_outlined,
                title: 'Reset App',
                subtitle: 'Clear all settings, prayer data, and Google sign-in',
                onTap: _confirmResetApp,
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildAppearanceDropdown() {
    final current = GalleryThemeService.instance.current;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: _surfaceBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _dividerColor),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            leading: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _iconBackground,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.palette_outlined, color: _sectionAccent, size: 20),
            ),
            title: Text(
              'Gallery Theme',
              style: TextStyle(color: _primaryText, fontSize: 15, fontWeight: FontWeight.w500),
            ),
            subtitle: Text(
              current.label,
              style: TextStyle(color: _textMuted, fontSize: 13),
            ),
            iconColor: _textMuted,
            collapsedIconColor: _textMuted,
            children: [
              Divider(height: 1, color: _dividerColor),
              _buildGalleryGrid(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGalleryGrid() {
    final currentIndex = GalleryThemeService.instance.index;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 0.78,
        ),
        itemCount: galleryItems.length,
        itemBuilder: (context, i) {
          final item = galleryItems[i];
          final selected = i == currentIndex;
          return GestureDetector(
            onTap: () => GalleryThemeService.instance.setIndex(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected ? _sectionAccent : _dividerColor,
                  width: selected ? 2.5 : 1,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(11),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(
                      item.assetPath,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        color: item.darkPalette.backgroundTop,
                        child: Icon(Icons.image_outlined, color: _textMuted),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 5,
                          horizontal: 4,
                        ),
                        color: Colors.black54,
                        child: Text(
                          item.label,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    if (selected)
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                            color: AppPalette.accent,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 12,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _confirmResetApp() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset App?'),
        content: const Text(
          'This will erase all settings, prayer logs, favourite masjids, and Google sign-in data. The app will restart to the setup screen.\n\nThis cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    await NotificationService.instance.cancelAllNotifications();
    await DBHelper.deleteAllData();
    try {
      await GoogleSignIn(scopes: ['email']).disconnect();
    } catch (_) {}

    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const OnboardingPage()),
      (_) => false,
    );
  }
}

extension on NotificationService {
  Future<void> rescheduleUsingStoredLocation() =>
      NotificationService.instance.rescheduleUsingStoredLocation();
}
