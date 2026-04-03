import 'dart:async';

import 'package:adhan/adhan.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hijri_date/hijri.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';

import 'app_palette.dart';
import 'notification_service.dart';
import 'more_page.dart';
import 'qibla_page.dart';
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
        scaffoldBackgroundColor: AppPalette.backgroundTop,
        colorScheme: const ColorScheme.dark(
          primary: AppPalette.accent,
          onPrimary: Colors.white,
          secondary: AppPalette.accentSoft,
          onSecondary: Colors.white,
          surface: AppPalette.surface,
          onSurface: Colors.white,
          outline: AppPalette.outline,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        cardTheme: CardThemeData(
          color: AppPalette.surface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          margin: EdgeInsets.zero,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: AppPalette.panel,
          selectedItemColor: AppPalette.accent,
          unselectedItemColor: AppPalette.textMuted,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
        ),
        listTileTheme: const ListTileThemeData(
          iconColor: AppPalette.accent,
          subtitleTextStyle: TextStyle(color: AppPalette.textSecondary),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppPalette.accent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppPalette.accent,
            side: const BorderSide(color: AppPalette.outline),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: AppPalette.surfaceRaised,
          border: OutlineInputBorder(
            borderSide: BorderSide(color: AppPalette.outline),
          ),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: AppPalette.outline),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: AppPalette.accent, width: 2),
          ),
          labelStyle: TextStyle(color: AppPalette.textSecondary),
          hintStyle: TextStyle(color: AppPalette.textMuted),
        ),
        chipTheme: const ChipThemeData(
          backgroundColor: AppPalette.surface,
          labelStyle: TextStyle(color: Colors.white),
          side: BorderSide(color: AppPalette.outline),
        ),
        dividerTheme: const DividerThemeData(color: AppPalette.outline),
        tabBarTheme: const TabBarThemeData(
          labelColor: AppPalette.accent,
          unselectedLabelColor: AppPalette.textMuted,
          indicatorColor: AppPalette.accent,
        ),
        checkboxTheme: CheckboxThemeData(
          fillColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? AppPalette.accent
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

class _PrayerEntry {
  const _PrayerEntry(this.name, this.time);
  final String name;
  final DateTime time;
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
  bool _notificationPrompted = false;
  final Set<String> _triggeredPrayerKeys = <String>{};
  String _cityName = '';

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
        _cityName = city;
        return 'Location: $city, $state';
      }
      if (city != null && city.isNotEmpty) {
        _cityName = city;
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

    _maybeTriggerExternalSpeakerAtPrayerTime(position);

    final nextPrayer = PrayerService.getNextPrayer(
      position.latitude,
      position.longitude,
    );

    setState(() {
      _nextPrayerName = nextPrayer.name;
    });
  }

  void _maybeTriggerExternalSpeakerAtPrayerTime(Position position) {
    final now = DateTime.now();
    final prayers = PrayerService.getObligatoryPrayers(
      PrayerService.getTimesForDate(position.latitude, position.longitude, now),
    );

    for (final prayer in prayers) {
      final start = prayer.time;
      final end = start.add(const Duration(seconds: 59));
      if (now.isBefore(start) || now.isAfter(end)) {
        continue;
      }

      final triggerKey =
          '${prayer.name}_${start.year}-${start.month}-${start.day}';
      if (_triggeredPrayerKeys.contains(triggerKey)) {
        return;
      }

      _triggeredPrayerKeys.add(triggerKey);
      NotificationService.instance.triggerSelectedSpeakerNow().catchError(
        (_) {},
      );
      return;
    }
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

  _PrayerEntry? _getCurrentPrayer() {
    final times = _currentPrayerTimes;
    if (times == null) return null;
    final now = DateTime.now();
    final all = [
      _PrayerEntry('Fajr', times.fajr),
      _PrayerEntry('Dhuhr', times.dhuhr),
      _PrayerEntry('Asr', times.asr),
      _PrayerEntry('Maghrib', times.maghrib),
      _PrayerEntry('Isha', times.isha),
    ];

    _PrayerEntry? current;
    for (final prayer in all) {
      if (!prayer.time.isAfter(now)) {
        current = prayer;
      }
    }
    return current;
  }

  String get _hijriShortLabel {
    final full = HijriDate.fromDate(_now).toFormat('dd MMMM yyyy');
    final parts = full.split(' ');
    if (parts.length == 3) {
      final month = parts[1];
      final shortMonth = month.length > 5 ? '${month.substring(0, 4)}.' : month;
      return '${parts[0]} $shortMonth, ${parts[2]}';
    }
    return full;
  }

  String get _todayDateLabel {
    return DateFormat('EEE, MMM d, yyyy').format(_now);
  }

  String _nextPrayerCountdownLabel() {
    final position = _currentPosition;
    if (position == null) {
      return '';
    }

    final nextPrayer = PrayerService.getNextPrayer(
      position.latitude,
      position.longitude,
    );
    final diff = nextPrayer.time.difference(DateTime.now());
    final totalMinutes = diff.inMinutes < 0 ? 0 : diff.inMinutes;
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;

    if (hours > 0) {
      return 'Next prayer in ${hours}h ${minutes}m';
    }
    return 'Next prayer in ${minutes}m';
  }

  @override
  Widget build(BuildContext context) {
    final current = _getCurrentPrayer();
    final screenHeight = MediaQuery.sizeOf(context).height;
    final heroHeight = (screenHeight * 0.34).clamp(250.0, 360.0);
    final timetableTopGap = (screenHeight * 0.018).clamp(8.0, 20.0);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: AppPalette.backgroundGradient,
            ),
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildTopBar(),
                _buildHeroSection(current, heroHeight: heroHeight),
                SizedBox(height: timetableTopGap),
                Expanded(child: _buildPrayerList(current?.name)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 4, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _hijriShortLabel,
                style: const TextStyle(
                  color: AppPalette.textSecondary,
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _todayDateLabel,
                style: const TextStyle(
                  color: AppPalette.textMuted,
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.menu, color: Colors.white),
            tooltip: 'Settings',
            onPressed: _openSettings,
          ),
        ],
      ),
    );
  }

  Widget _buildHeroSection(_PrayerEntry? current, {required double heroHeight}) {
    final countdown = _nextPrayerCountdownLabel();
    final textTopPadding = (heroHeight * 0.28).clamp(80.0, 120.0);
    final textBottomPadding = (heroHeight * 0.12).clamp(20.0, 36.0);
    final cloudTop = (heroHeight * 0.48).clamp(108.0, 150.0);

    return SizedBox(
      height: heroHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Keep decoration below the top bar so the settings/menu icon remains visible.
          Positioned(top: 8, right: -8, child: _buildMoonDecoration()),
          Positioned(top: cloudTop, right: 34, child: _buildCloudWisps()),
          // Current prayer text + qibla button
          Padding(
            padding: EdgeInsets.fromLTRB(20, textTopPadding, 20, textBottomPadding),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        current?.name ?? (_nextPrayerName ?? '—'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 52,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -1.0,
                          height: 1.0,
                        ),
                      ),
                      if (countdown.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          countdown,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w300,
                          ),
                        ),
                      ],
                      if (_cityName.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          _cityName,
                          style: const TextStyle(
                            color: AppPalette.textMuted,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                _buildQiblaFab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMoonDecoration() {
    return SizedBox(
      width: 130,
      height: 130,
      child: Stack(
        children: [
          // Base moon circle
          Container(
            width: 130,
            height: 130,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF9EA8D8),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF9EA8D8).withValues(alpha: 0.25),
                  blurRadius: 24,
                  spreadRadius: 6,
                ),
              ],
            ),
          ),
          // Large crater
          Positioned(
            top: 22,
            left: 28,
            child: Container(
              width: 26,
              height: 26,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF7A84B8),
              ),
            ),
          ),
          // Medium crater
          Positioned(
            top: 56,
            left: 72,
            child: Container(
              width: 16,
              height: 16,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF8088C0),
              ),
            ),
          ),
          // Small crater
          Positioned(
            top: 84,
            left: 36,
            child: Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF8490C4),
              ),
            ),
          ),
          // Shadow overlay on right edge
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              width: 38,
              height: 130,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.horizontal(
                  right: Radius.circular(65),
                ),
                color: const Color(0xFF1B1744).withValues(alpha: 0.55),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCloudWisps() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(
          width: 88,
          height: 10,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(5),
          ),
        ),
        const SizedBox(height: 5),
        Container(
          width: 58,
          height: 8,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ],
    );
  }

  Widget _buildQiblaFab() {
    return GestureDetector(
      onTap: () => Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const QiblaPage())),
      child: Container(
        width: 68,
        height: 68,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF2A2270),
          border: Border.all(color: Colors.white24, width: 2),
          boxShadow: const [
            BoxShadow(color: Colors.black38, blurRadius: 10, spreadRadius: 2),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            const Icon(Icons.mosque, color: Colors.white, size: 32),
            Positioned(
              bottom: 11,
              right: 11,
              child: Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppPalette.accent,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrayerList(String? currentPrayerName) {
    final times = _currentPrayerTimes;
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppPalette.textSecondary),
      );
    }
    if (times == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _locationStatus,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppPalette.textSecondary,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _determinePosition,
                icon: const Icon(Icons.my_location),
                label: const Text('Detect Location'),
              ),
            ],
          ),
        ),
      );
    }
    final List<(String, DateTime)> rows = [
      ('Fajr', times.fajr),
      ('Sunrise', times.sunrise),
      ('Dhuhr', times.dhuhr),
      ('Asr', times.asr),
      ('Maghrib', times.maghrib),
      ('Isha', times.isha),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final targetWidth = constraints.maxWidth > 620
            ? 620.0
            : constraints.maxWidth;
        return Center(
          child: SizedBox(
            width: targetWidth,
            child: Column(
              children: [
                for (final (name, time) in rows)
                  _buildPrayerRow(
                    name,
                    time,
                    isActive: name == currentPrayerName,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPrayerRow(String name, DateTime time, {bool isActive = false}) {
    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      child: Row(
        children: [
          Expanded(
            child: Text(
              name,
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: isActive ? FontWeight.w500 : FontWeight.w300,
              ),
            ),
          ),
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive ? Colors.white : Colors.transparent,
              border: Border.all(
                color: isActive ? Colors.white : Colors.white38,
                width: 1.5,
              ),
            ),
          ),
          Expanded(
            child: Text(
              _formatTime(time),
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w300,
              ),
            ),
          ),
        ],
      ),
    );
    if (isActive) {
      return Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFF8A00), Color(0xFFFFB040)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
        ),
        child: row,
      );
    }
    return row;
  }
}
