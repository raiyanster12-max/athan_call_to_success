import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'db_helper.dart';
import 'settings_page.dart';

class TrackerPage extends StatefulWidget {
  const TrackerPage({super.key});

  @override
  State<TrackerPage> createState() => _TrackerPageState();
}

class _TrackerPageState extends State<TrackerPage> {
  static const List<String> _trackedPrayers = [
    'Fajr',
    'Dhuhr',
    'Asr',
    'Maghrib',
    'Isha',
  ];

  bool _isLoading = true;
  Map<String, bool> _prayerStatuses = {
    for (final prayer in _trackedPrayers) prayer: false,
  };

  String get _todayKey => DateFormat('yyyy-MM-dd').format(DateTime.now());

  int get _completedCount =>
      _prayerStatuses.values.where((completed) => completed).length;

  @override
  void initState() {
    super.initState();
    _loadPrayerTracker();
  }

  Future<void> _loadPrayerTracker() async {
    final prayerStatuses = await DBHelper.getPrayerLogForDate(_todayKey);
    if (!mounted) return;
    setState(() {
      _prayerStatuses = {
        for (final prayer in _trackedPrayers)
          prayer: prayerStatuses[prayer] ?? false,
      };
      _isLoading = false;
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

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SettingsPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Prayer Tracker'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: _openSettings,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadPrayerTracker,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Today',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$_completedCount of ${_trackedPrayers.length} prayers logged',
                          ),
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
                  ),
                ],
              ),
            ),
    );
  }
}
