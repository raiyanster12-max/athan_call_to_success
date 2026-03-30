import 'dart:async';

import 'package:adhan/adhan.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hijri_date/hijri.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';

import 'notification_service.dart';
import 'more_page.dart';
import 'prayer_service.dart';
import 'quran_page.dart';
import 'settings_page.dart';
import 'tracker_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.instance.initialize();
  HijriDate.setLocal('en');
  runApp(const AthanApp());
}

class AthanApp extends StatelessWidget {
  const AthanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Athan - Call to Success',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0D2818),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF4CAF50),
          onPrimary: Colors.white,
          secondary: Color(0xFF66BB6A),
          onSecondary: Colors.white,
          surface: Color(0xFF143526),
          onSurface: Colors.white,
          outline: Color(0xFF2D5C40),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0D2818),
          foregroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF143526),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          margin: EdgeInsets.zero,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Color(0xFF0A2015),
          selectedItemColor: Color(0xFF4CAF50),
          unselectedItemColor: Color(0xFF5A8A6A),
          type: BottomNavigationBarType.fixed,
          elevation: 0,
        ),
        listTileTheme: const ListTileThemeData(
          iconColor: Color(0xFF4CAF50),
          // WCAG 1.4.3: accessible contrast
          subtitleTextStyle: TextStyle(color: Color(0xFF8FBE9E)),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2E7D32),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF4CAF50),
            side: const BorderSide(color: Color(0xFF2D5C40)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: Color(0xFF143526),
          border: OutlineInputBorder(
            borderSide: BorderSide(color: Color(0xFF2D5C40)),
          ),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Color(0xFF2D5C40)),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Color(0xFF4CAF50), width: 2),
          ),
          labelStyle: TextStyle(color: Color(0xFF8FBE9E)),
          hintStyle: TextStyle(color: Color(0xFF5A8A6A)),
        ),
        chipTheme: const ChipThemeData(
          backgroundColor: Color(0xFF1A3E2A),
          labelStyle: TextStyle(color: Colors.white),
          side: BorderSide(color: Color(0xFF2D5C40)),
        ),
        dividerTheme: const DividerThemeData(
          color: Color(0xFF1E4B30),
        ),
        tabBarTheme: const TabBarThemeData(
          labelColor: Color(0xFF4CAF50),
          unselectedLabelColor: Color(0xFF8FBE9E),
          indicatorColor: Color(0xFF4CAF50),
        ),
        checkboxTheme: CheckboxThemeData(
          fillColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected)
                ? const Color(0xFF4CAF50)
                : null,
          ),
          checkColor: WidgetStateProperty.all(Colors.white),
        ),
      ),
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
      const QuranPage(),
      const TrackerPage(),
      const MorePage(),
    ];

    return Scaffold(
      body: pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Today',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.menu_book_outlined),
            activeIcon: Icon(Icons.menu_book),
            label: 'Quran',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.checklist_outlined),
            activeIcon: Icon(Icons.checklist),
            label: 'Tracker',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.more_horiz),
            activeIcon: Icon(Icons.more_horiz),
            label: 'More',
          ),
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
  String _locationStatus = 'Waiting for location...';
  PrayerTimes? _currentPrayerTimes;
  bool _isLoading = false;
  Position? _currentPosition;
  DateTime _now = DateTime.now();
  Timer? _clockTimer;
  Timer? _countdownTimer;
  String? _nextPrayerName;
  Duration? _timeUntilNextPrayer;
  bool _notificationPrompted = false;

  bool get _supportsNotificationPermission {
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

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

      if (city != null &&
          city.isNotEmpty &&
          state != null &&
          state.isNotEmpty) {
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
    NotificationService.instance.refreshBatchIfNeeded();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _now = DateTime.now();
      });
    });
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _determinePosition();
      if (!mounted) return;
      await _maybePromptNotificationPermission();
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  String get _gregorianNowLabel => DateFormat('EEEE, MMM d, y').format(_now);

  String get _timeNowLabel => DateFormat('h:mm:ss a').format(_now);

  String get _hijriNowLabel =>
      HijriDate.fromDate(_now).toFormat('DDDD, MMMM dd, yyyy');

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
    setState(() {
      _isLoading = true;
      _locationStatus = 'Detecting location...';
    });
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!mounted) return;

    if (!serviceEnabled) {
      setState(() {
        _locationStatus = 'Location services are disabled.';
        _isLoading = false;
      });
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
        setState(() {
          _locationStatus = 'Location permission not granted.';
          _isLoading = false;
        });
        return;
      }
      permission = await Geolocator.requestPermission();
      if (!mounted) return;

      if (permission == LocationPermission.denied) {
        setState(() {
          _locationStatus = 'Location permission denied.';
          _isLoading = false;
        });
        return;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      setState(() {
        _locationStatus =
            'Location permission permanently denied. Enable it in device settings.';
        _isLoading = false;
      });
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

      final times = PrayerService.getTimes(
        position.latitude,
        position.longitude,
      );
      _currentPosition = position;

      setState(() {
        _locationStatus = locationLabel;
        _currentPrayerTimes = times;
        _isLoading = false;
      });
      _startCountdown();

      // Schedule notifications independently so a sound/channel error never
      // surfaces as a "Could not get location" message.
      NotificationService.instance
          .scheduleRollingPrayerNotifications(
            latitude: position.latitude,
            longitude: position.longitude,
          )
          .catchError((_) {});
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _locationStatus = 'Could not get location: $e';
        _isLoading = false;
      });
    }
  }

  String _formatTime(DateTime time) {
    return DateFormat.jm().format(time.toLocal());
  }

  void _openSettings() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const SettingsPage()));
  }

  Widget _buildNextPrayerCard() {
    if (_nextPrayerName == null || _timeUntilNextPrayer == null) {
      return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF0E2A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E5030)),
      ),
      child: Row(
        children: [
          const Icon(Icons.av_timer, color: Color(0xFF4CAF50), size: 28),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Next: ${_nextPrayerName!}',
                style: const TextStyle(
                  color: Color(0xFF8FBE9E),
                  fontSize: 13,
                ),
              ),
              Text(
                _formatCountdown(_timeUntilNextPrayer!),
                semanticsLabel:
                    'Time until ${_nextPrayerName!}: ${_formatCountdown(_timeUntilNextPrayer!)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Athan — Call to Success',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Text(
              _hijriNowLabel,
              style: const TextStyle(
                color: Color(0xFF8FBE9E),
                fontSize: 11,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: _openSettings,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildDateTimeCard(),
            const SizedBox(height: 12),
            if (_currentPrayerTimes != null) ..._buildNextTwoPrayersRow(),
            _buildNextPrayerCard(),
            if (_nextPrayerName != null) const SizedBox(height: 12),
            if (_currentPrayerTimes != null) ...[_buildPrayerTimesCard(), const SizedBox(height: 12)],
            _buildLocationCard(),
          ],
        ),
      ),
    );
  }

  Widget _prayerTile(String name, DateTime time) {
    // WCAG 4.1.2: merge into a single accessible announcement
    return Semantics(
      label: '$name prayer time is ${_formatTime(time)}',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: const Color(0xFF0E2A1A),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.access_time,
                color: Color(0xFF4CAF50),
                size: 17,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                name,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              _formatTime(time),
              style: const TextStyle(
                color: Color(0xFF8FBE9E),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateTimeCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF143526),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _gregorianNowLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _timeNowLabel,
                  style: const TextStyle(
                    color: Color(0xFF4CAF50),
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Returns up to 2 upcoming prayers as (label, name, time) records.
  List<(String, String, DateTime)> _getNextTwoPrayers() {
    final times = _currentPrayerTimes;
    if (times == null) return [];
    final now = DateTime.now();
    final all = [
      ('Fajr', times.fajr),
      ('Sunrise', times.sunrise),
      ('Dhuhr', times.dhuhr),
      ('Asr', times.asr),
      ('Maghrib', times.maghrib),
      ('Isha', times.isha),
    ];
    final upcoming = all.where((p) => p.$2.isAfter(now)).toList();
    final result = <(String, String, DateTime)>[];
    for (int i = 0; i < upcoming.length && i < 2; i++) {
      result.add((i == 0 ? 'Next' : 'Upcoming', upcoming[i].$1, upcoming[i].$2));
    }
    return result;
  }

  List<Widget> _buildNextTwoPrayersRow() {
    final prayers = _getNextTwoPrayers();
    if (prayers.isEmpty) return [];
    final Widget row;
    if (prayers.length == 1) {
      row = _buildPrayerQuickCard(
          prayers[0].$1, prayers[0].$2, prayers[0].$3);
    } else {
      row = Row(
        children: [
          Expanded(
            child: _buildPrayerQuickCard(
                prayers[0].$1, prayers[0].$2, prayers[0].$3),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildPrayerQuickCard(
                prayers[1].$1, prayers[1].$2, prayers[1].$3),
          ),
        ],
      );
    }
    return [row, const SizedBox(height: 12)];
  }

  Widget _buildPrayerQuickCard(String label, String name, DateTime time) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF143526),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E4B30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFF0E2A1A),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF4CAF50),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            _formatTime(time),
            style: const TextStyle(
              color: Color(0xFF8FBE9E),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrayerTimesCard() {
    final times = _currentPrayerTimes!;
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF143526),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Column(
        children: [
          _prayerTile('Fajr', times.fajr),
          const Divider(color: Color(0xFF1E4B30), height: 1),
          _prayerTile('Sunrise', times.sunrise),
          const Divider(color: Color(0xFF1E4B30), height: 1),
          _prayerTile('Dhuhr', times.dhuhr),
          const Divider(color: Color(0xFF1E4B30), height: 1),
          _prayerTile('Asr', times.asr),
          const Divider(color: Color(0xFF1E4B30), height: 1),
          _prayerTile('Maghrib', times.maghrib),
          const Divider(color: Color(0xFF1E4B30), height: 1),
          _prayerTile('Isha', times.isha),
        ],
      ),
    );
  }

  Widget _buildLocationCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF143526),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.location_on_outlined,
                color: Color(0xFF4CAF50),
                size: 15,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _locationStatus,
                  style: const TextStyle(
                    color: Color(0xFF8FBE9E),
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _determinePosition,
              icon: _isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.my_location),
              label: Text(
                _isLoading ? 'Detecting...' : 'Refresh Location',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
