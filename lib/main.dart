import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:adhan/adhan.dart';
import 'package:geolocator/geolocator.dart';
import 'prayer_service.dart'; // Ensure you created this file in the previous step

void main() => runApp(const AthanApp());

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

  // Navigation Pages
  static const List<Widget> _pages = [
    HomePage(),
    Center(child: Text('Qibla Compass')),
    Center(child: Text('Settings')),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        selectedItemColor: const Color(0xFF00796B), // Emerald highlights
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.explore_outlined), activeIcon: Icon(Icons.explore), label: 'Qibla'),
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
  String _locationStatus = "Waiting for location...";
  PrayerTimes? _currentPrayerTimes;

  Future<void> _determinePosition() async {
    // 1. Check if location services are enabled
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() => _locationStatus = 'Location services are disabled.');
      return;
    }

    // 2. Check / request permission
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() => _locationStatus = 'Location permission denied.');
        return;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      setState(() => _locationStatus =
          'Location permission permanently denied. Enable it in device settings.');
      return;
    }

    // 3. Get position
    try {
      final position = await Geolocator.getCurrentPosition();
      final times =
          PrayerService.getTimes(position.latitude, position.longitude);
      setState(() {
        _locationStatus =
            'Location: ${position.latitude.toStringAsFixed(2)}, ${position.longitude.toStringAsFixed(2)}';
        _currentPrayerTimes = times;
      });
    } catch (e) {
      setState(() => _locationStatus = 'Could not get location: $e');
    }
  }

  // Helper to format time (e.g., 5:30 AM)
  String _formatTime(DateTime time) {
    return DateFormat.jm().format(time.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Athan - Call to Success")),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 20),
            Image.asset('assets/icon/athan_app_icon.png', height: 80),
            Text(_locationStatus),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: _determinePosition, child: const Text("Update Times")),
            
            if (_currentPrayerTimes != null) ...[
              const Divider(),
              _prayerTile("Fajr", _currentPrayerTimes!.fajr),
              _prayerTile("Sunrise", _currentPrayerTimes!.sunrise),
              _prayerTile("Dhuhr", _currentPrayerTimes!.dhuhr),
              _prayerTile("Asr", _currentPrayerTimes!.asr),
              _prayerTile("Maghrib", _currentPrayerTimes!.maghrib),
              _prayerTile("Isha", _currentPrayerTimes!.isha),
            ]
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