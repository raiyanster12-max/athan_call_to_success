import 'dart:async';

import 'package:adhan/adhan.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hijri_date/hijri.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

import 'db_helper.dart';
import 'more_page.dart';
import 'prayer_service.dart';
import 'quran_page.dart';
import 'settings_page.dart';
import 'tracker_page.dart';

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
  static const _webTesterBannerKey = 'web_tester_banner_dismissed';
  int _selectedIndex = 0;
  bool _showWebTesterBanner = false;

  @override
  void initState() {
    super.initState();
    _loadWebTesterBannerPreference();
  }

  Future<void> _loadWebTesterBannerPreference() async {
    if (!kIsWeb) {
      return;
    }

    final dismissed = await DBHelper.getSetting(_webTesterBannerKey);
    if (!mounted) {
      return;
    }

    setState(() {
      _showWebTesterBanner = dismissed != 'true';
    });
  }

  Future<void> _dismissWebTesterBanner() async {
    await DBHelper.setSetting(_webTesterBannerKey, 'true');
    if (!mounted) {
      return;
    }

    setState(() {
      _showWebTesterBanner = false;
    });
  }

  Future<void> _openFeedbackDialog() async {
    final message = await showDialog<String>(
      context: context,
      builder: (dialogContext) => const _TesterFeedbackDialog(),
    );

    if (!mounted || message == null || message.isEmpty) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      const HomePage(),
      const QuranPage(),
      const TrackerPage(),
      const MorePage(),
    ];

    return Scaffold(
      body: Column(
        children: [
          if (kIsWeb && _showWebTesterBanner)
            _WebTesterBanner(
              onDismiss: _dismissWebTesterBanner,
              onShareFeedback: _openFeedbackDialog,
            ),
          Expanded(child: pages[_selectedIndex]),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        selectedItemColor: const Color(0xFF00796B),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
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

class _WebTesterBanner extends StatelessWidget {
  const _WebTesterBanner({
    required this.onDismiss,
    required this.onShareFeedback,
  });

  final Future<void> Function() onDismiss;
  final Future<void> Function() onShareFeedback;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF143A2E),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            runSpacing: 8,
            spacing: 12,
            children: [
              const SizedBox(
                width: 420,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Tester Preview',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'This hosted build is for early feedback. Use the feedback button to report bugs, ideas, or anything unclear.',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: onShareFeedback,
                    icon: const Icon(Icons.rate_review_outlined),
                    label: const Text('Share Feedback'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF53B97B),
                      foregroundColor: Colors.black,
                    ),
                  ),
                  TextButton(
                    onPressed: onDismiss,
                    child: const Text(
                      'Dismiss',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TesterFeedbackDialog extends StatefulWidget {
  const _TesterFeedbackDialog();

  @override
  State<_TesterFeedbackDialog> createState() => _TesterFeedbackDialogState();
}

class _TesterFeedbackDialogState extends State<_TesterFeedbackDialog> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _commentController = TextEditingController();
  int _rating = 4;
  bool _submitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  String _buildFeedbackBody() {
    final name = _nameController.text.trim();
    final comments = _commentController.text.trim();

    return [
      '## Tester Feedback',
      '',
      '- Rating: $_rating/5',
      '- Tester: ${name.isEmpty ? 'Anonymous tester' : name}',
      '- Platform: Chrome Web (GitHub Pages)',
      '',
      '### Comments',
      comments.isEmpty ? 'No comments provided.' : comments,
    ].join('\n');
  }

  Future<void> _submit({required bool openIssue}) async {
    final comments = _commentController.text.trim();
    if (comments.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a short comment before submitting.')),
      );
      return;
    }

    setState(() {
      _submitting = true;
    });

    final body = _buildFeedbackBody();
    await Clipboard.setData(ClipboardData(text: body));
    await DBHelper.setSetting('last_feedback_draft', body);

    String message = 'Feedback copied to clipboard.';
    if (openIssue) {
      final issueUri = Uri.https(
        'github.com',
        '/raiyanster12-max/athan_call_to_success/issues/new',
        {
          'title': 'Tester feedback ($_rating/5)',
          'body': body,
        },
      );

      final launched = await launchUrl(issueUri);
      message = launched
          ? 'Opened GitHub issue draft and copied feedback to clipboard.'
          : 'Feedback copied to clipboard. GitHub issue could not be opened automatically.';
    }

    if (!mounted) {
      return;
    }

    Navigator.of(context).pop(message);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Share Tester Feedback'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'This copies the feedback text first, then opens a prefilled GitHub issue draft if you choose that option.',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Name (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Rating',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: List.generate(5, (index) {
                  final value = index + 1;
                  return ChoiceChip(
                    label: Text('$value/5'),
                    selected: _rating == value,
                    onSelected: (_) => setState(() => _rating = value),
                  );
                }),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _commentController,
                minLines: 4,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: 'What worked well, what broke, or what felt unclear?',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        OutlinedButton(
          onPressed: _submitting ? null : () => _submit(openIssue: false),
          child: const Text('Copy Only'),
        ),
        FilledButton(
          onPressed: _submitting ? null : () => _submit(openIssue: true),
          child: const Text('Open GitHub Issue'),
        ),
      ],
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
    if (kIsWeb) return false;
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
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _now = DateTime.now());
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

      final times = PrayerService.getTimes(position.latitude, position.longitude);
      _currentPosition = position;
      setState(() {
        _locationStatus = locationLabel;
        _currentPrayerTimes = times;
        _isLoading = false;
      });
      _startCountdown();
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
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SettingsPage()),
    );
  }

  Widget _buildNextPrayerCard() {
    if (_nextPrayerName == null || _timeUntilNextPrayer == null) {
      return const SizedBox.shrink();
    }

    return Card(
      color: const Color(0xFF0E5F4F),
      elevation: 1,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F6F2),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0E5F4F),
        foregroundColor: Colors.white,
        title: const Text('Athan - Call to Success'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: _openSettings,
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFE8F2EC), Color(0xFFF8FAF7)],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              Center(
                child: Image.asset('assets/icon/athan_app_icon.png', height: 80),
              ),
              const SizedBox(height: 16),
              Card(
                color: const Color(0xFFE9F4EF),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _gregorianNowLabel,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0E5F4F),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _timeNowLabel,
                        style: const TextStyle(
                          fontSize: 18,
                          color: Color(0xFF1A3A35),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _hijriNowLabel,
                        style: const TextStyle(color: Color(0xFF46645E)),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _buildNextPrayerCard(),
              const SizedBox(height: 12),
              Card(
                color: const Color(0xFFF1F7F4),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _locationStatus,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1F3F39),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0E5F4F),
                            foregroundColor: Colors.white,
                          ),
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
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      children: [
                        _prayerTile('Fajr', _currentPrayerTimes!.fajr),
                        _prayerTile('Sunrise', _currentPrayerTimes!.sunrise),
                        _prayerTile('Dhuhr', _currentPrayerTimes!.dhuhr),
                        _prayerTile('Asr', _currentPrayerTimes!.asr),
                        _prayerTile('Maghrib', _currentPrayerTimes!.maghrib),
                        _prayerTile('Isha', _currentPrayerTimes!.isha),
                      ],
                    ),
                  ),
                ),
            ],
          ),
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
