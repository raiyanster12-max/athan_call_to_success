import 'dart:async';

import 'package:adhan/adhan.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hijri_date/hijri.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';

import 'db_helper.dart';
import 'masjid_page.dart';
import 'prayer_service.dart';
import 'settings_page.dart';

void main() {
  HijriDate.setLocal('en');
  runApp(const AthanApp());
}

class AthanApp extends StatelessWidget {
  const AthanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Athan - Call to Success',
      theme: ThemeData(primarySwatch: Colors.green),
      home: const MainNavigation(),
    );
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      const HomePage(),
      const MasjidPage(),
      const SettingsPage(),
    ];
    return Scaffold(
      body: pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        selectedItemColor: const Color(0xFF00796B), // Emerald highlights
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.mosque_outlined), activeIcon: Icon(Icons.mosque), label: 'Masjid'),
          BottomNavigationBarItem(icon: Icon(Icons.settings_outlined), activeIcon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const List<String> _trackedPrayers = [
    'Fajr',
    'Dhuhr',
    'Asr',
    'Maghrib',
    'Isha',
  ];

  String _locationStatus = "Waiting for location...";
  PrayerTimes? _currentPrayerTimes;
  bool _isLoading = false;
  Position? _currentPosition;
  Timer? _countdownTimer;
  String? _nextPrayerName;
  Duration? _timeUntilNextPrayer;
  Map<String, bool> _prayerStatuses = {
    for (final prayer in _trackedPrayers) prayer: false,
  };
  bool _notificationPrompted = false;

  bool get _supportsNotificationPermission {
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  String get _todayKey => DateFormat('yyyy-MM-dd').format(DateTime.now());

  String get _gregorianLabel =>
      DateFormat('EEEE, MMMM d, y').format(DateTime.now());

  String get _hijriLabel =>
      HijriDate.fromDate(DateTime.now()).toFormat('DDDD, MMMM dd, yyyy');

  Future<String> _buildLocationLabel(Position position) async {
    try {
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (placemarks.isEmpty) {
        return 'Location found';
      }

      final placemark = placemarks.first;
      final city = placemark.locality?.trim();
      final state = placemark.administrativeArea?.trim();

      if (city != null && city.isNotEmpty && state != null && state.isNotEmpty) {
        return 'Location: $city, $state';
      }
      if (city != null && city.isNotEmpty) {
        return 'Location: $city';
      }
      if (state != null && state.isNotEmpty) {
        return 'Location: $state';
      }
      return 'Location found';
    } catch (_) {
      return 'Location found';
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _determinePosition();
      if (!mounted) return;
      await _maybePromptNotificationPermission();
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _maybePromptNotificationPermission() async {
    if (_notificationPrompted || !_supportsNotificationPermission) {
      return;
    }
    _notificationPrompted = true;

    final status = await Permission.notification.status;
    if (!mounted) return;
    if (status == PermissionStatus.granted ||
        status == PermissionStatus.limited ||
        status == PermissionStatus.provisional) {
      return;
    }

    final proceed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Notification Permission'),
        content: const Text(
          'Athan uses notifications for prayer reminders and upcoming scheduled alerts. Please allow notification access when prompted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Not Now'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Allow'),
          ),
        ],
      ),
    );

    if (proceed == true) {
      await Permission.notification.request();
    }
  }

  Future<void> _loadPrayerTracker() async {
    final prayerStatuses = await DBHelper.getPrayerLogForDate(_todayKey);
    if (!mounted) return;
    setState(() {
      _prayerStatuses = {
        for (final prayer in _trackedPrayers)
          prayer: prayerStatuses[prayer] ?? false,
      };
    });
  }

  Future<void> _togglePrayer(String prayer, bool value) async {
    await DBHelper.setPrayerCompleted(
      dateKey: _todayKey,
      prayerName: prayer,
      completed: value,
    );
    if (!mounted) return;
    setState(() {
      _prayerStatuses[prayer] = value;
    });
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _updateNextPrayerCountdown();
    _countdownTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _updateNextPrayerCountdown(),
    );
  }

  void _updateNextPrayerCountdown() {
    final position = _currentPosition;
    if (position == null || !mounted) {
      return;
    }

    final nextPrayer = PrayerService.getNextPrayer(
      position.latitude,
      position.longitude,
    );
    final remaining = nextPrayer.time.difference(DateTime.now());

    setState(() {
      _nextPrayerName = nextPrayer.name;
      _timeUntilNextPrayer = remaining.isNegative ? Duration.zero : remaining;
    });
  }

  String _formatCountdown(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    return '${hours.toString().padLeft(2, '0')}:'
        '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  Future<void> _determinePosition() async {
    setState(() { _isLoading = true; _locationStatus = 'Detecting location...'; });
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!mounted) return;

    if (!serviceEnabled) {
      setState(() { _locationStatus = 'Location services are disabled.'; _isLoading = false; });
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (!mounted) return;

    if (permission == LocationPermission.denied) {
      final bool? proceed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('Location Permission'),
          content: const Text(
            'Athan needs your location to calculate accurate prayer times for your area. '
            'Please allow location access when prompted.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Not Now'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Allow'),
            ),
          ],
        ),
      );
      if (!mounted) return;

      if (proceed != true) {
        setState(() { _locationStatus = 'Location permission not granted.'; _isLoading = false; });
        return;
      }
      permission = await Geolocator.requestPermission();
      if (!mounted) return;

      if (permission == LocationPermission.denied) {
        setState(() { _locationStatus = 'Location permission denied.'; _isLoading = false; });
        return;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      setState(() { _locationStatus = 'Location permission permanently denied. Enable it in device settings.'; _isLoading = false; });
      return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      if (!mounted) return;

      final locationLabel = await _buildLocationLabel(position);
      if (!mounted) return;

      final times = PrayerService.getTimes(position.latitude, position.longitude);
      _currentPosition = position;
      setState(() {
        _locationStatus = locationLabel;
        _currentPrayerTimes = times;
        _isLoading = false;
      });
      _startCountdown();
      await _loadPrayerTracker();
    } catch (e) {
      if (!mounted) return;
      setState(() { _locationStatus = 'Could not get location: $e'; _isLoading = false; });
    }
  }

  // Helper to format time (e.g., 5:30 AM)
  String _formatTime(DateTime time) {
    return DateFormat.jm().format(time.toLocal());
  }

  Widget _buildDateCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.calendar_today, color: Color(0xFF00796B)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _gregorianLabel,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _hijriLabel,
                    style: const TextStyle(color: Colors.black54),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNextPrayerCard() {
    if (_nextPrayerName == null || _timeUntilNextPrayer == null) {
      return const SizedBox.shrink();
    }

    return Card(
      color: const Color(0xFF00796B),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Next Prayer',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 8),
            Text(
              _nextPrayerName!,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _formatCountdown(_timeUntilNextPrayer!),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrayerTrackerCard() {
    final completedCount =
        _prayerStatuses.values.where((completed) => completed).length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Prayer Tracker',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 4),
            Text('$completedCount of ${_trackedPrayers.length} prayers logged today'),
            const SizedBox(height: 12),
            for (final prayer in _trackedPrayers)
              CheckboxListTile(
                value: _prayerStatuses[prayer] ?? false,
                contentPadding: EdgeInsets.zero,
                activeColor: const Color(0xFF00796B),
                title: Text(prayer),
                controlAffinity: ListTileControlAffinity.leading,
                onChanged: (value) {
                  if (value == null) return;
                  _togglePrayer(prayer, value);
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Athan - Call to Success")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            Center(
              child: Image.asset('assets/icon/athan_app_icon.png', height: 80),
            ),
            const SizedBox(height: 16),
            _buildDateCard(),
            const SizedBox(height: 12),
            _buildNextPrayerCard(),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _locationStatus,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _determinePosition,
                        icon: _isLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.my_location),
                        label: Text(_isLoading ? 'Detecting...' : 'Refresh Location'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (_currentPrayerTimes != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    children: [
                      _prayerTile("Fajr", _currentPrayerTimes!.fajr),
                      _prayerTile("Sunrise", _currentPrayerTimes!.sunrise),
                      _prayerTile("Dhuhr", _currentPrayerTimes!.dhuhr),
                      _prayerTile("Asr", _currentPrayerTimes!.asr),
                      _prayerTile("Maghrib", _currentPrayerTimes!.maghrib),
                      _prayerTile("Isha", _currentPrayerTimes!.isha),
                    ],
                  ),
                ),
              ),
            if (_currentPrayerTimes != null) const SizedBox(height: 12),
            if (_currentPrayerTimes != null) _buildPrayerTrackerCard(),
          ],
        ),
      ),
    );
  }

  Widget _prayerTile(String name, DateTime time) {
    return ListTile(
      leading: const Icon(Icons.access_time, color: Color(0xFF00796B)),
      title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
      trailing: Text(_formatTime(time), style: const TextStyle(fontSize: 16)),
    );
  }
}