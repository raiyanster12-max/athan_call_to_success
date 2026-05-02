import 'dart:async';

import 'package:adhan/adhan.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hijri_date/hijri.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';

import 'app_palette.dart';
import 'db_helper.dart';
import 'notification_service.dart';
import 'more_page.dart';
import 'onboarding_page.dart';
import 'mosque_service.dart';
import 'qibla_page.dart';
import 'prayer_service.dart';
import 'quran_page.dart';
import 'settings_page.dart';
import 'tracker_page.dart';
import 'package:google_sign_in/google_sign_in.dart';

// Use the Type 3 ID from your JSON: 896243268657-eoiqbejcc7qa...
final GoogleSignIn _googleSignIn = GoogleSignIn(
  clientId:
      '896243268657-eoiqbejcc7qa6ataoqhdvhru92s7pr9f.apps.googleusercontent.com',
  scopes: ['email', 'https://www.googleapis.com/auth/contacts.readonly'],
);

// main.dart

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Initialize Database for Desktop/Mobile
  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.macOS)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // 2. STABLE CONNECTION FIX: Initialize Notification Service & Background Handlers
  // This must happen before runApp so the background isolate can register properly.
  final notificationService = NotificationService.instance;
  await notificationService.initialize();

  // 3. Initialize Alarm Manager (Required for Android background triggers)
  if (defaultTargetPlatform == TargetPlatform.android) {
    await AndroidAlarmManager.initialize();
  }

  final onboardingDone =
      await DBHelper.getSetting('onboarding_complete') == 'true';
  runApp(AthanApp(showOnboarding: !onboardingDone));
}

@pragma('vm:entry-point')
Future<void> carAppMain() async {
  await _initializeSharedPrayerEngines();
  runApp(const AthanApp());
}

Future<void> _initializeSharedPrayerEngines() async {}

class AthanApp extends StatelessWidget {
  const AthanApp({super.key, this.showOnboarding = false});

  final bool showOnboarding;

  @override
  Widget build(BuildContext context) {
    // Dark palette colors — must mirror AppPalette._dark (#262943 base)
    const Color darkBg = Color(0xFF262943);
    const Color darkSurface = Color(0xFF2E3252);
    const Color darkSurfaceRaised = Color(0xFF353960);
    const Color darkPanel = Color(0xFF202340);
    const Color darkOutline = Color(0xFF4A4F7A);
    const Color darkTextPrimary = Color(0xFFE8E6FF);
    const Color darkTextSecondary = Color(0xFFB0ADDB);
    const Color darkTextMuted = Color(0xFF7B79A8);

    // Light palette colors
    const Color lightBg = Color(0xFFF8F8F8);
    const Color lightSurface = Color(0xFFFFFFFF);
    const Color lightSurfaceRaised = Color(0xFFF2F2F2);
    const Color lightPanel = Color(0xFFF5F5F5);
    const Color lightOutline = Color(0xFFD0D0D8);
    const Color lightTextPrimary = Color(0xFF0D0D0D);
    const Color lightTextSecondary = Color(0xFF4A4A52);
    const Color lightTextMuted = Color(0xFF8A8A92);

    return MaterialApp(
      title: 'Athan - Call to Success',
      themeMode: ThemeMode.system,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: lightBg,
        colorScheme: const ColorScheme.light(
          primary: AppPalette.accent,
          onPrimary: Colors.white,
          secondary: AppPalette.accentSoft,
          onSecondary: Colors.white,
          surface: lightSurface,
          onSurface: lightTextPrimary,
          outline: lightOutline,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          foregroundColor: lightTextPrimary,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        cardTheme: CardThemeData(
          color: lightSurface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          margin: EdgeInsets.zero,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: lightPanel,
          selectedItemColor: AppPalette.accent,
          unselectedItemColor: lightTextMuted,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
        ),
        listTileTheme: const ListTileThemeData(
          iconColor: AppPalette.accent,
          subtitleTextStyle: TextStyle(color: lightTextSecondary),
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
            side: const BorderSide(color: lightOutline),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: lightSurfaceRaised,
          border: OutlineInputBorder(
            borderSide: BorderSide(color: lightOutline),
          ),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: lightOutline),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: AppPalette.accent, width: 2),
          ),
          labelStyle: TextStyle(color: lightTextSecondary),
          hintStyle: TextStyle(color: lightTextMuted),
        ),
        chipTheme: const ChipThemeData(
          backgroundColor: lightSurface,
          labelStyle: TextStyle(color: lightTextPrimary),
          side: BorderSide(color: lightOutline),
        ),
        dividerTheme: const DividerThemeData(color: lightOutline),
        tabBarTheme: const TabBarThemeData(
          labelColor: AppPalette.accent,
          unselectedLabelColor: lightTextMuted,
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
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: darkBg,
        colorScheme: const ColorScheme.dark(
          primary: AppPalette.accent,
          onPrimary: Colors.white,
          secondary: AppPalette.accentSoft,
          onSecondary: Colors.white,
          surface: darkSurface,
          onSurface: darkTextPrimary,
          outline: darkOutline,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        cardTheme: CardThemeData(
          color: darkSurface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          margin: EdgeInsets.zero,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: darkPanel,
          selectedItemColor: AppPalette.accent,
          unselectedItemColor: darkTextMuted,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
        ),
        listTileTheme: ListTileThemeData(
          iconColor: AppPalette.accent,
          titleTextStyle: TextStyle(color: darkTextPrimary, fontSize: 16),
          subtitleTextStyle: TextStyle(color: darkTextSecondary),
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
            side: const BorderSide(color: darkOutline),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: darkSurfaceRaised,
          border: OutlineInputBorder(
            borderSide: BorderSide(color: darkOutline),
          ),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: darkOutline),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: AppPalette.accent, width: 2),
          ),
          labelStyle: TextStyle(color: darkTextSecondary),
          hintStyle: TextStyle(color: darkTextMuted),
        ),
        chipTheme: const ChipThemeData(
          backgroundColor: darkSurface,
          labelStyle: TextStyle(color: Colors.white),
          side: BorderSide(color: darkOutline),
        ),
        dividerTheme: const DividerThemeData(color: darkOutline),
        tabBarTheme: const TabBarThemeData(
          labelColor: AppPalette.accent,
          unselectedLabelColor: darkTextMuted,
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
      home: showOnboarding ? const OnboardingPage() : const MainNavigation(),
      routes: {'/home': (_) => const MainNavigation()},
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

class _HeroBackground extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const imagePath = 'assets/images/hero_bg.png';
    // Check if asset exists at runtime; fall back to gradient if not yet added.
    return Stack(
      fit: StackFit.expand,
      children: [
        Image(
          image: const AssetImage(imagePath),
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            decoration: BoxDecoration(
              gradient: AppPalette.of(context).heroGradient,
            ),
          ),
        ),
        // Semi-transparent overlay for text legibility
        // Bottom stop blends into #262943 so the hero image flows
        // seamlessly into the prayer timetable section below.
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: [0.0, 0.45, 1.0],
              colors: [
                Color(0x44000020), // very light tint at top
                Color(0x99000030), // moderate at mid
                Color(0xFF262943), // solid #262943 at bottom — matches prayer list bg
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PrayerEntry {
  const _PrayerEntry(this.name, this.time);
  final String name;
  final DateTime time;
}

class HomePage extends StatefulWidget {
  const HomePage({super.key, this.showSettingsButton = true});

  final bool showSettingsButton;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
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
  final MosqueService _mosqueService = MosqueService();
  String _cityName = '';
  Map<String, dynamic>? _pinnedMasjid;
  Map<String, dynamic>? _nearestMasjid;
  Map<String, dynamic> _iqamahSettings = const {};
  String? _lastScheduledPrayerCoordKey;

  bool get _isUsingMasjidPrayerSource =>
      _pinnedMasjid != null || _nearestMasjid != null;

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
    WidgetsBinding.instance.addObserver(this);
    DBHelper.pinnedChangeNotifier.addListener(_loadPinnedMasjidForHome);
    NotificationService.instance.refreshBatchIfNeeded();
    unawaited(_loadPinnedMasjidForHome());
    unawaited(_loadIqamahSettingsForHome());
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
    WidgetsBinding.instance.removeObserver(this);
    DBHelper.pinnedChangeNotifier.removeListener(_loadPinnedMasjidForHome);
    _clockTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      NotificationService.instance.refreshBatchIfNeeded();
      unawaited(_loadPinnedMasjidForHome());
      unawaited(_loadIqamahSettingsForHome());
      _refreshPrayerTimesFromBestSource();
      unawaited(_scheduleNotificationsForBestSource());

      final position = _currentPosition;
      if (_pinnedMasjid == null && position != null) {
        unawaited(_resolveNearestMasjid(position));
      }
    }
  }

  Future<void> _loadPinnedMasjidForHome() async {
    final pinned = await DBHelper.getPinnedMasjid();
    if (!mounted) return;
    setState(() {
      _pinnedMasjid = pinned;
      if (pinned != null) {
        _nearestMasjid = null;
      }
    });
    _refreshPrayerTimesFromBestSource();
    unawaited(_scheduleNotificationsForBestSource());

    final position = _currentPosition;
    if (pinned == null && position != null) {
      unawaited(_resolveNearestMasjid(position));
    }
  }

  Future<void> _loadIqamahSettingsForHome() async {
    final iqamah = await DBHelper.getIqamahSettings();
    if (!mounted) return;
    setState(() {
      _iqamahSettings = iqamah;
    });
  }

  int? _iqamahOffsetForPrayer(String prayerName) {
    final key = prayerName.toLowerCase();
    const defaults = {
      'fajr': 30,
      'dhuhr': 15,
      'asr': 15,
      'maghrib': 10,
      'isha': 15,
    };
    if (_iqamahSettings.containsKey(key)) {
      final value = _iqamahSettings[key] as int?;
      if (value != null) {
        return value;
      }
    }
    return defaults[key];
  }

  String? _masjidOffsetLabel(String prayerName) {
    if (!_isUsingMasjidPrayerSource) {
      return null;
    }
    final offset = _iqamahOffsetForPrayer(prayerName);
    if (offset == null) {
      return null;
    }
    final padded = offset.toString().padLeft(2, '0');
    return '+$padded';
  }

  ({double lat, double lng})? _activePrayerCoordinates() {
    final pinned = _pinnedMasjid;
    final pinnedLat = pinned?['lat'] as double?;
    final pinnedLng = pinned?['lng'] as double?;
    if (pinnedLat != null && pinnedLng != null) {
      return (lat: pinnedLat, lng: pinnedLng);
    }

    final nearest = _nearestMasjid;
    final nearestLat = nearest?['lat'] as double?;
    final nearestLng = nearest?['lng'] as double?;
    if (nearestLat != null && nearestLng != null) {
      return (lat: nearestLat, lng: nearestLng);
    }

    final position = _currentPosition;
    if (position == null) return null;
    return (lat: position.latitude, lng: position.longitude);
  }

  Future<void> _resolveNearestMasjid(Position position) async {
    if (_pinnedMasjid != null) {
      if (_nearestMasjid != null && mounted) {
        setState(() {
          _nearestMasjid = null;
        });
      }
      return;
    }

    try {
      final token = await DBHelper.getSetting('mawaqit_token');
      final nearby = await _mosqueService.findNearbyMosques(
        position.latitude,
        position.longitude,
        mawaqitToken: token,
      );
      if (!mounted || _pinnedMasjid != null) return;

      nearby.sort((a, b) {
        final da = Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          a.lat,
          a.lng,
        );
        final db = Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          b.lat,
          b.lng,
        );
        return da.compareTo(db);
      });

      if (nearby.isEmpty) {
        setState(() {
          _nearestMasjid = null;
        });
        _refreshPrayerTimesFromBestSource();
        unawaited(_scheduleNotificationsForBestSource());
        return;
      }

      final nearest = nearby.first;
      setState(() {
        _nearestMasjid = {
          'id': nearest.id,
          'name': nearest.name,
          'address': nearest.address,
          'lat': nearest.lat,
          'lng': nearest.lng,
        };
      });
      _refreshPrayerTimesFromBestSource();
      unawaited(_scheduleNotificationsForBestSource());
    } catch (_) {
      if (!mounted || _pinnedMasjid != null) return;
      setState(() {
        _nearestMasjid = null;
      });
      _refreshPrayerTimesFromBestSource();
      unawaited(_scheduleNotificationsForBestSource());
    }
  }

  void _refreshPrayerTimesFromBestSource() {
    final coords = _activePrayerCoordinates();
    if (coords == null || !mounted) return;
    setState(() {
      _currentPrayerTimes = PrayerService.getTimes(coords.lat, coords.lng);
    });
  }

  Future<void> _scheduleNotificationsForBestSource() async {
    final coords = _activePrayerCoordinates();
    if (coords == null) return;

    final scheduleKey =
        '${coords.lat.toStringAsFixed(6)},${coords.lng.toStringAsFixed(6)}';
    if (scheduleKey == _lastScheduledPrayerCoordKey) {
      return;
    }

    _lastScheduledPrayerCoordKey = scheduleKey;
    try {
      await NotificationService.instance.scheduleRollingPrayerNotifications(
        latitude: coords.lat,
        longitude: coords.lng,
      );
    } catch (_) {
      _lastScheduledPrayerCoordKey = null;
    }
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
    final coords = _activePrayerCoordinates();
    if (coords == null || !mounted) {
      return;
    }

    _maybeTriggerExternalSpeakerAtPrayerTime();

    final nextPrayer = PrayerService.getNextPrayer(coords.lat, coords.lng);

    setState(() {
      _nextPrayerName = nextPrayer.name;
    });
  }

  void _maybeTriggerExternalSpeakerAtPrayerTime() {
    final coords = _activePrayerCoordinates();
    if (coords == null) return;

    final now = DateTime.now();
    final prayers = PrayerService.getObligatoryPrayers(
      PrayerService.getTimesForDate(coords.lat, coords.lng, now),
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
      NotificationService.instance
          .triggerSelectedSpeakerNow(prayerName: prayer.name)
          .catchError((_) {});
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
          timeLimit: Duration(seconds: 20),
        ),
      );
      if (!mounted) return;

      final locationLabel = await _buildLocationLabel(position);
      if (!mounted) return;

      _currentPosition = position;

      setState(() {
        _locationStatus = locationLabel;
        _isLoading = false;
      });

      await _resolveNearestMasjid(position).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          if (mounted) {
            setState(() => _nearestMasjid = null);
          }
        },
      );
      if (!mounted) return;

      _refreshPrayerTimesFromBestSource();
      _startCountdown();

      // Schedule notifications independently so a sound/channel error never
      // surfaces as a "Could not get location" message.
      unawaited(_scheduleNotificationsForBestSource());
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
    final coords = _activePrayerCoordinates();
    if (coords == null) {
      return '';
    }

    final nextPrayer = PrayerService.getNextPrayer(coords.lat, coords.lng);
    final diff = nextPrayer.time.difference(DateTime.now());
    final totalMinutes = diff.inMinutes < 0 ? 0 : diff.inMinutes;
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;

    if (hours > 0) {
      return 'Next prayer in $hours hrs and $minutes minutes';
    }
    return 'Next prayer in $minutes minutes';
  }

  String _heroLocationLabel() {
    final pinnedName = (_pinnedMasjid?['name'] as String?)?.trim() ?? '';
    if (pinnedName.isNotEmpty) {
      return 'Masjid prayer times: $pinnedName';
    }

    final nearestName = (_nearestMasjid?['name'] as String?)?.trim() ?? '';
    if (nearestName.isNotEmpty) {
      return 'Nearest masjid prayer times: $nearestName';
    }

    if (_cityName.trim().isNotEmpty) {
      return 'Local prayer times: ${_cityName.trim()}';
    }
    return 'Local prayer times';
  }

  @override
  Widget build(BuildContext context) {
    final current = _getCurrentPrayer();
    final screenHeight = MediaQuery.sizeOf(context).height;
    final isSmallScreen = screenHeight < 700;
    final heroHeight = (screenHeight * 0.34).clamp(isSmallScreen ? 200.0 : 250.0, 360.0);
    final timetableTopGap = (screenHeight * 0.018).clamp(isSmallScreen ? 4.0 : 8.0, 20.0);

    return Scaffold(
      backgroundColor: AppPalette.pageBackground,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _HeroBackground(),
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildTopBar(),
                  _buildHeroSection(current, heroHeight: heroHeight),
                  // Prayer list section — sits on solid #262943 for WCAG contrast.
                  Container(
                    color: AppPalette.pageBackground,
                    padding: EdgeInsets.only(bottom: timetableTopGap),
                    child: _buildPrayerList(current?.name),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final isSmallScreen = screenHeight < 700;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, isSmallScreen ? 4 : 8, 4, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _hijriShortLabel,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: isSmallScreen ? 18 : 20,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _todayDateLabel,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: isSmallScreen ? 14 : 16,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
          if (widget.showSettingsButton)
            IconButton(
              icon: const Icon(Icons.menu, color: Colors.white),
              tooltip: 'Settings',
              onPressed: _openSettings,
            )
          else
            const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildHeroSection(
    _PrayerEntry? current, {
    required double heroHeight,
  }) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final isSmallScreen = screenHeight < 700;

    final countdown = _nextPrayerCountdownLabel();
    final prayerLabel = current?.name ?? (_nextPrayerName ?? '—');
    final locationLabel = _heroLocationLabel();

    final textTopPadding = isSmallScreen
        ? (heroHeight * 0.22).clamp(40.0, 80.0)
        : (heroHeight * 0.28).clamp(80.0, 120.0);
    final textBottomPadding = isSmallScreen
        ? 8.0
        : (heroHeight * 0.12).clamp(20.0, 36.0);

    return Container(
      constraints: BoxConstraints(minHeight: heroHeight),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Current prayer text + qibla button
          Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              textTopPadding,
              20,
              textBottomPadding,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        prayerLabel,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isSmallScreen ? 42 : 52,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -1.0,
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'In Prayer.',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isSmallScreen ? 18 : 22,
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                      if (countdown.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          countdown,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isSmallScreen ? 18 : 22,
                            fontWeight: FontWeight.w300,
                          ),
                        ),
                      ],
                      if (locationLabel.trim().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          locationLabel,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: isSmallScreen ? 13 : 15,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                _buildQiblaFab(isSmallScreen: isSmallScreen),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMoonDecoration({bool isSmallScreen = false}) {
    final size = isSmallScreen ? 110.0 : 130.0;
    return SizedBox(
      width: size,
      height: size,
      child: FittedBox(
        child: SizedBox(
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
        ),
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

  Widget _buildQiblaFab({bool isSmallScreen = false}) {
    final size = isSmallScreen ? 56.0 : 68.0;
    final iconSize = isSmallScreen ? 28.0 : 32.0;

    return GestureDetector(
      onTap: () => Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const QiblaPage())),
      child: Container(
        width: size,
        height: size,
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
            Icon(Icons.mosque, color: Colors.white, size: iconSize),
            Positioned(
              bottom: isSmallScreen ? 8 : 11,
              right: isSmallScreen ? 8 : 11,
              child: Container(
                width: isSmallScreen ? 8 : 10,
                height: isSmallScreen ? 8 : 10,
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
      return Center(
        child: CircularProgressIndicator(color: AppPalette.of(context).textSecondary),
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
                style: TextStyle(
                  color: AppPalette.of(context).textSecondary,
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
    final screenHeight = MediaQuery.sizeOf(context).height;
    final isSmallScreen = screenHeight < 700;

    final offsetLabel = _masjidOffsetLabel(name);
    final offsetMinutes = _iqamahOffsetForPrayer(name);
    final timeLabel = _formatTime(time);
    final row = Semantics(
      label: offsetMinutes == null
          ? '$name at $timeLabel'
          : '$name at $timeLabel with iqamah offset plus $offsetMinutes minutes',
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: 24,
          vertical: isSmallScreen ? 12 : 18,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                name,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isSmallScreen ? 16 : 18,
                  fontWeight: isActive ? FontWeight.w500 : FontWeight.w300,
                ),
              ),
            ),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    timeLabel,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isSmallScreen ? 16 : 18,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                  if (offsetLabel != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        // High-contrast badge for WCAG/508 readability.
                        color: const Color(0xFF0E3A2B),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: const Color(0xFF7CE2B4)),
                      ),
                      child: Text(
                        '$offsetLabel min',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
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

extension on NotificationService {
  Future<void> refreshBatchIfNeeded() =>
      NotificationService.instance.refreshBatchIfNeeded();

  Future<void> scheduleRollingPrayerNotifications({
    required double latitude,
    required double longitude,
  }) =>
      NotificationService.instance.scheduleRollingPrayerNotifications(
        latitude: latitude,
        longitude: longitude,
      );

  Future<void> triggerSelectedSpeakerNow({required String prayerName}) =>
      NotificationService.instance.triggerSelectedSpeakerNow(
        prayerName: prayerName,
      );
}
