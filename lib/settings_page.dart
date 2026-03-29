import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

import 'db_helper.dart';

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

  LocationPermission? _locationPermission;
  PermissionStatus? _notificationPermission;
  PermissionStatus? _batteryOptimizationPermission;
  bool _isLoading = true;
  final Map<String, String> _tonePreferences = {
    for (final prayer in _prayerNames) prayer: 'Beep',
  };

  bool get _supportsBatteryOptimizationPermission =>
      defaultTargetPlatform == TargetPlatform.android;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final locationPermission = await Geolocator.checkPermission();
    final notificationPermission = await Permission.notification.status;
    final batteryOptimizationPermission =
      _supportsBatteryOptimizationPermission
        ? await Permission.ignoreBatteryOptimizations.status
        : null;

    for (final prayer in _prayerNames) {
      final storedTone = await DBHelper.getSetting(_toneKey(prayer));
      if (storedTone != null && _toneOptions.contains(storedTone)) {
        _tonePreferences[prayer] = storedTone;
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

  String _toneKey(String prayer) =>
      'alarm_tone_${prayer.toLowerCase()}';

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
    if (!mounted) return;
    setState(() => _tonePreferences[prayer] = tone);
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
        body: Center(child: CircularProgressIndicator()),
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
                  const Text(
                    'Permissions',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                  const Text(
                    'Athan Sound Preferences',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Your selections are stored now and will be used by scheduled prayer alarms when the notification service is added.',
                  ),
                  const SizedBox(height: 12),
                  for (final prayer in _prayerNames)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: DropdownButtonFormField<String>(
                        initialValue: _tonePreferences[prayer],
                        decoration: InputDecoration(
                          labelText: prayer,
                          border: const OutlineInputBorder(),
                        ),
                        items: _toneOptions
                            .map(
                              (tone) => DropdownMenuItem<String>(
                                value: tone,
                                child: Text(tone),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          _updateTone(prayer, value);
                        },
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
                children: const [
                  Text(
                    'Reliability Roadmap',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(
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
