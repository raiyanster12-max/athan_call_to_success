import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path_lib;
import 'package:permission_handler/permission_handler.dart';

import 'db_helper.dart';
import 'notification_service.dart';

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
    'Muezzin Voice 1',
    'Muezzin Voice 2',
  ];

  static const String _customFileTone = NotificationService.toneCustomFile;
  static const String _speakerRouteKey = 'notification_speaker_route';
  static const String _networkSpeakerIpKey =
      NotificationService.networkSpeakerIpKey;
  static const String _networkSpeakerPortKey =
      NotificationService.networkSpeakerPortKey;
  static const String _networkSpeakerPathKey =
      NotificationService.networkSpeakerPathKey;

  static const List<String> _speakerRouteOptions = [
    NotificationService.speakerSystemDefault,
    NotificationService.speakerPhoneSpeaker,
    NotificationService.speakerNetworkIp,
  ];

  LocationPermission? _locationPermission;
  PermissionStatus? _notificationPermission;
  PermissionStatus? _batteryOptimizationPermission;
  bool _isLoading = true;
  String _speakerRoute = NotificationService.speakerSystemDefault;
  final TextEditingController _networkSpeakerIpController =
      TextEditingController();
  final TextEditingController _networkSpeakerPortController =
      TextEditingController(text: '80');
  final TextEditingController _networkSpeakerPathController =
      TextEditingController(text: '/play');
  final Map<String, String> _tonePreferences = {
    for (final prayer in _prayerNames) prayer: 'Beep',
  };
  final Map<String, String> _customToneFileNames = {
    for (final prayer in _prayerNames) prayer: '',
  };

  AudioPlayer? _audioPlayer;
  String? _playingPrayer;

  bool get _supportsBatteryOptimizationPermission =>
      defaultTargetPlatform == TargetPlatform.android;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _audioPlayer?.stop();
    _audioPlayer?.dispose();
    _networkSpeakerIpController.dispose();
    _networkSpeakerPortController.dispose();
    _networkSpeakerPathController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final locationPermission = await Geolocator.checkPermission();
    final notificationPermission = await Permission.notification.status;
    final batteryOptimizationPermission = _supportsBatteryOptimizationPermission
        ? await Permission.ignoreBatteryOptimizations.status
        : null;
    final storedSpeakerRoute = await DBHelper.getSetting(_speakerRouteKey);
    if (storedSpeakerRoute != null &&
        _speakerRouteOptions.contains(storedSpeakerRoute)) {
      _speakerRoute = storedSpeakerRoute;
    }

    final storedIp = await DBHelper.getSetting(_networkSpeakerIpKey);
    final storedPort = await DBHelper.getSetting(_networkSpeakerPortKey);
    final storedPath = await DBHelper.getSetting(_networkSpeakerPathKey);
    if (storedIp != null && storedIp.trim().isNotEmpty) {
      _networkSpeakerIpController.text = storedIp;
    }
    if (storedPort != null && storedPort.trim().isNotEmpty) {
      _networkSpeakerPortController.text = storedPort;
    }
    if (storedPath != null && storedPath.trim().isNotEmpty) {
      _networkSpeakerPathController.text = storedPath;
    }

    for (final prayer in _prayerNames) {
      final storedTone = await DBHelper.getSetting(_toneKey(prayer));
      if (storedTone != null &&
          (_toneOptions.contains(storedTone) ||
              storedTone == _customFileTone)) {
        _tonePreferences[prayer] = storedTone;
      }

      final customPath = await DBHelper.getSetting(_customTonePathKey(prayer));
      if (customPath != null && customPath.trim().isNotEmpty) {
        _customToneFileNames[prayer] = path_lib.basename(customPath);
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
      _isLoading = false;
    });
  }

  String _toneKey(String prayer) => 'alarm_tone_${prayer.toLowerCase()}';

  String _customTonePathKey(String prayer) =>
      'alarm_tone_custom_path_${prayer.toLowerCase()}';

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

  Future<void> _updateTone(String prayer, String tone) async {
    await DBHelper.setSetting(_toneKey(prayer), tone);
    await NotificationService.instance.rescheduleUsingStoredLocation();
    if (!mounted) return;
    setState(() => _tonePreferences[prayer] = tone);
  }

  Future<void> _updateSpeakerRoute(String route) async {
    await DBHelper.setSetting(_speakerRouteKey, route);
    if (route == NotificationService.speakerNetworkIp) {
      await _saveNetworkSpeakerConfig(reschedule: false);
    }
    await NotificationService.instance.rescheduleUsingStoredLocation();
    if (!mounted) return;
    setState(() => _speakerRoute = route);
  }

  Future<void> _saveNetworkSpeakerConfig({bool reschedule = true}) async {
    await DBHelper.setSetting(
      _networkSpeakerIpKey,
      _networkSpeakerIpController.text.trim(),
    );
    await DBHelper.setSetting(
      _networkSpeakerPortKey,
      _networkSpeakerPortController.text.trim(),
    );
    await DBHelper.setSetting(
      _networkSpeakerPathKey,
      _networkSpeakerPathController.text.trim(),
    );

    if (reschedule) {
      await NotificationService.instance.rescheduleUsingStoredLocation();
    }
  }

  Future<void> _testNetworkSpeaker() async {
    final ip = _networkSpeakerIpController.text.trim();
    final port = int.tryParse(_networkSpeakerPortController.text.trim()) ?? 80;
    var path = _networkSpeakerPathController.text.trim();

    if (ip.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a speaker IP address first.')),
      );
      return;
    }
    if (path.isEmpty) {
      path = '/play';
    }
    if (!path.startsWith('/')) {
      path = '/$path';
    }

    await _saveNetworkSpeakerConfig(reschedule: false);

    final uri = Uri(scheme: 'http', host: ip, port: port, path: path);
    String message;
    try {
      final response = await http
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 4));
      message = response.statusCode >= 200 && response.statusCode < 400
          ? 'Speaker endpoint reachable: ${response.statusCode}'
          : 'Speaker responded with status ${response.statusCode}';
    } catch (e) {
      message = 'Could not reach speaker endpoint: $e';
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
        'mp3', 'wav', 'm4a', 'aac', 'ogg',
        'flac', 'opus', '3gp', 'amr', 'wma',
        'aiff', 'aif', 'mp4', 'mkv',
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
    final ext = path_lib.extension(customPath).toLowerCase().replaceFirst('.', '');
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
      if (mounted) setState(() => _playingPrayer = null);
      player.dispose();
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not play audio: $e')),
      );
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            // WCAG 4.1.2: announce loading state
            semanticsLabel: 'Loading settings',
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // WCAG 2.4.6: mark as heading for screen-reader navigation
                  Semantics(
                    header: true,
                    child: const Text(
                      'Permissions',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.location_on_outlined),
                    title: const Text('Location'),
                    subtitle: Text(_locationPermissionLabel()),
                    trailing: FilledButton(
                      onPressed: _requestLocationPermission,
                      child: const Text('Review'),
                    ),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.notifications_outlined),
                    title: const Text('Notifications'),
                    subtitle: Text(_notificationPermissionLabel()),
                    trailing: FilledButton(
                      onPressed: _requestNotificationPermission,
                      child: const Text('Review'),
                    ),
                  ),
                  if (_supportsBatteryOptimizationPermission)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.battery_charging_full_outlined),
                      title: const Text('Battery Optimization'),
                      subtitle: Text(_batteryPermissionLabel()),
                      trailing: FilledButton(
                        onPressed: _requestBatteryOptimizationPermission,
                        child: const Text('Unrestrict'),
                      ),
                    ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: openAppSettings,
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Open app settings'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // WCAG 2.4.6: mark as heading for screen-reader navigation
                  Semantics(
                    header: true,
                    child: const Text(
                      'Athan Sound Preferences',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Your selections are stored and applied to upcoming prayer reminders. '
                    'On Android, you can also choose a custom audio file from your phone.',
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _speakerRoute,
                    decoration: const InputDecoration(
                      labelText: 'Notification Audio Route',
                      border: OutlineInputBorder(),
                    ),
                    items: _speakerRouteOptions
                        .map(
                          (route) => DropdownMenuItem<String>(
                            value: route,
                            child: Text(route),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      _updateSpeakerRoute(value);
                    },
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'System Default follows your current audio route. '
                    'Phone Speaker uses alarm audio usage for stronger output on Android. '
                    'Network Speaker stores an IP endpoint used for connected speaker integrations.',
                    style: TextStyle(color: Colors.black54, fontSize: 12),
                  ),
                  if (_speakerRoute ==
                      NotificationService.speakerNetworkIp) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _networkSpeakerIpController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Speaker IP Address',
                        hintText: 'e.g. 192.168.1.45',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => _saveNetworkSpeakerConfig(),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _networkSpeakerPortController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Port',
                              hintText: '80',
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (_) => _saveNetworkSpeakerConfig(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: _networkSpeakerPathController,
                            decoration: const InputDecoration(
                              labelText: 'Endpoint Path',
                              hintText: '/play',
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (_) => _saveNetworkSpeakerConfig(),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        onPressed: _testNetworkSpeaker,
                        icon: const Icon(Icons.wifi_tethering),
                        label: const Text('Test speaker endpoint'),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  for (final prayer in _prayerNames)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          DropdownButtonFormField<String>(
                            initialValue: _tonePreferences[prayer],
                            decoration: InputDecoration(
                              labelText: prayer,
                              border: const OutlineInputBorder(),
                            ),
                            items: _allToneOptions
                                .map(
                                  (tone) => DropdownMenuItem<String>(
                                    value: tone,
                                    child: Text(tone),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) async {
                              if (value == null) return;
                              if (value == _customFileTone && !kIsWeb) {
                                await _pickCustomToneForPrayer(prayer);
                                return;
                              }
                              _updateTone(prayer, value);
                            },
                          ),
                          if (_tonePreferences[prayer] == _customFileTone &&
                              !kIsWeb)
                            Padding(
                              padding: const EdgeInsets.only(top: 8, left: 4),
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                  Text(
                    _customToneFileNames[prayer]!.isEmpty
                        ? 'No custom file selected'
                        : 'Selected: ${_customToneFileNames[prayer]}',
                    // WCAG 1.4.3: Color(0xFF616161) ~5.6:1 on white (passes AA)
                    style: const TextStyle(
                      color: Color(0xFF616161),
                      fontSize: 12,
                    ),
                  ),
                                  if (_customToneFileNames[prayer]!.isNotEmpty)
                                    _playingPrayer == prayer
                                        ? OutlinedButton.icon(
                                            onPressed: _stopPlayback,
                                            icon: const Icon(Icons.stop, color: Colors.red),
                                            label: const Text('Stop'),
                                          )
                                        : OutlinedButton.icon(
                                            onPressed: () => _playCustomTone(prayer),
                                            icon: const Icon(Icons.play_arrow),
                                            label: const Text('Preview'),
                                          ),
                                  OutlinedButton(
                                    onPressed: () =>
                                        _pickCustomToneForPrayer(prayer),
                                    child: const Text('Change file'),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        _clearCustomToneForPrayer(prayer),
                                    child: const Text('Use Beep'),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // WCAG 2.4.6: mark as heading
                  Semantics(
                    header: true,
                    child: const Text(
                      'Reliability Roadmap',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'The next implementation pass will add background Athan scheduling in 3-day batches and connect these tone preferences to real prayer notifications.',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
