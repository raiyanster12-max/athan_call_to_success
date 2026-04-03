import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:hijri_date/hijri.dart';
import 'package:intl/intl.dart';

import 'app_palette.dart';
import 'db_helper.dart';

class TrackerPage extends StatefulWidget {
  const TrackerPage({super.key});

  @override
  State<TrackerPage> createState() => _TrackerPageState();
}

class _TrackerPageState extends State<TrackerPage> {
  static const String _ramadanStatusStoragePrefix = 'ramadan_status_year_';
  static const List<String> _trackedPrayers = [
    'Fajr',
    'Dhuhr',
    'Asr',
    'Maghrib',
    'Isha',
  ];

  bool _isLoading = true;
  final int _currentYear = DateTime.now().year;
  final DateTime _today = DateTime.now();
  Map<String, bool> _prayerStatuses = {
    for (final prayer in _trackedPrayers) prayer: false,
  };
  List<DateTime> _ramadanDates = <DateTime>[];
  Map<String, String> _ramadanStatuses = <String, String>{};

  String get _todayKey => DateFormat('yyyy-MM-dd').format(DateTime.now());

  int get _completedCount =>
      _prayerStatuses.values.where((completed) => completed).length;

  @override
  void initState() {
    super.initState();
    _loadTrackerData();
  }

  Future<void> _loadTrackerData() async {
    final prayerStatuses = await DBHelper.getPrayerLogForDate(_todayKey);
    final ramadanDates = _buildRamadanDatesForYear(_currentYear);
    final savedRamadanStatuses = await _loadRamadanStatuses(_currentYear);

    if (!mounted) return;
    setState(() {
      _prayerStatuses = {
        for (final prayer in _trackedPrayers)
          prayer: prayerStatuses[prayer] ?? false,
      };
      _ramadanDates = ramadanDates;
      _ramadanStatuses = savedRamadanStatuses;
      _isLoading = false;
    });
  }

  List<DateTime> _buildRamadanDatesForYear(int year) {
    final first = DateTime(year, 1, 1);
    final last = DateTime(year, 12, 31);
    final dates = <DateTime>[];

    for (var d = first; !d.isAfter(last); d = d.add(const Duration(days: 1))) {
      final hijri = HijriDate.fromDate(d);
      if (hijri.hMonth == 9) {
        dates.add(DateTime(d.year, d.month, d.day));
      }
    }

    return dates;
  }

  String _ramadanStorageKey(int year) => '$_ramadanStatusStoragePrefix$year';

  Future<Map<String, String>> _loadRamadanStatuses(int year) async {
    final raw = await DBHelper.getSetting(_ramadanStorageKey(year));
    if (raw == null || raw.trim().isEmpty) {
      return <String, String>{};
    }

    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map(
        (key, value) => MapEntry(key, value?.toString() ?? ''),
      );
    } catch (_) {
      return <String, String>{};
    }
  }

  Future<void> _saveRamadanStatuses() async {
    await DBHelper.setSetting(
      _ramadanStorageKey(_currentYear),
      jsonEncode(_ramadanStatuses),
    );
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

  String _dateKey(DateTime date) => DateFormat('yyyy-MM-dd').format(date);

  Future<void> _toggleRamadanStatus(DateTime date) async {
    final key = _dateKey(date);
    final current = _ramadanStatuses[key] ?? '';

    String next;
    if (current == '') {
      next = 'done';
    } else if (current == 'done') {
      next = 'missed';
    } else {
      next = '';
    }

    setState(() {
      if (next.isEmpty) {
        _ramadanStatuses.remove(key);
      } else {
        _ramadanStatuses[key] = next;
      }
    });
    await _saveRamadanStatuses();
  }

  int get _ramadanDoneCount =>
      _ramadanStatuses.values.where((status) => status == 'done').length;

  int get _ramadanMissedCount =>
      _ramadanStatuses.values.where((status) => status == 'missed').length;

  int get _ramadanPendingCount =>
      (_ramadanDates.length - _ramadanDoneCount - _ramadanMissedCount).clamp(
        0,
        _ramadanDates.length,
      );

  List<List<DateTime?>> _buildRamadanCalendarRows() {
    if (_ramadanDates.isEmpty) return const <List<DateTime?>>[];

    final rows = <List<DateTime?>>[];
    var row = List<DateTime?>.filled(7, null);

    final firstWeekday = _ramadanDates.first.weekday;
    var col = firstWeekday - 1;

    for (final date in _ramadanDates) {
      row[col] = date;
      if (col == 6) {
        rows.add(row);
        row = List<DateTime?>.filled(7, null);
        col = 0;
      } else {
        col += 1;
      }
    }

    if (row.any((value) => value != null)) {
      rows.add(row);
    }

    return rows;
  }

  Widget _buildRamadanDayCell(DateTime date) {
    final key = _dateKey(date);
    final status = _ramadanStatuses[key] ?? '';
    final isToday = DateUtils.isSameDay(date, _today);

    IconData? statusIcon;
    Color statusColor = AppPalette.textMuted;
    Color backgroundColor = AppPalette.surface;

    // WCAG 4.1.2: determine semantic status label for screen readers
    String statusLabel;
    if (status == 'done') {
      statusIcon = Icons.check_circle;
      statusColor = AppPalette.accent;
      backgroundColor = AppPalette.surfaceRaised;
      statusLabel = 'Fast observed';
    } else if (status == 'missed') {
      statusIcon = Icons.cancel;
      statusColor = AppPalette.danger;
      backgroundColor = const Color(0xFF4A1E36);
      statusLabel = 'Fast missed';
    } else {
      statusLabel = 'Fast status not recorded';
    }

    final int hijriDay = HijriDate.fromDate(date).hDay;
    final String gregDateLabel = DateFormat('MMMM d').format(date);

    return Semantics(
      button: true,
      label:
          '${isToday ? 'Today, ' : ''}$gregDateLabel, Ramadan day $hijriDay: $statusLabel',
      hint: 'Activate to change status',
      child: ExcludeSemantics(
        child: InkWell(
          onTap: () => _toggleRamadanStatus(date),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            margin: const EdgeInsets.all(3),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isToday ? AppPalette.accent : AppPalette.outline,
                width: isToday ? 1.5 : 1,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${HijriDate.fromDate(date).hDay}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('MMM d').format(date),
                  // WCAG 1.4.3: accessible contrast on dark background
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppPalette.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Icon(
                  statusIcon ?? Icons.radio_button_unchecked,
                  size: 16,
                  color: statusColor,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRamadanTrackerCard() {
    final rows = _buildRamadanCalendarRows();

    if (_ramadanDates.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('No Ramadan dates found for the current year.'),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ramadan Tracker ($_currentYear)',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            // WCAG 1.4.3: accessible contrast for instruction text
            const Text(
              'Tap each day to cycle: pending -> done -> missed -> pending.',
              style: TextStyle(color: AppPalette.textSecondary),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(label: Text('Done: $_ramadanDoneCount')),
                Chip(label: Text('Missed: $_ramadanMissedCount')),
                Chip(label: Text('Pending: $_ramadanPendingCount')),
              ],
            ),
            const SizedBox(height: 10),
            // WCAG 4.1.2: accessible column headers with full day names for screen readers
            Row(
              children: const [
                Expanded(
                  child: Center(child: Text('Mon', semanticsLabel: 'Monday')),
                ),
                Expanded(
                  child: Center(child: Text('Tue', semanticsLabel: 'Tuesday')),
                ),
                Expanded(
                  child: Center(
                    child: Text('Wed', semanticsLabel: 'Wednesday'),
                  ),
                ),
                Expanded(
                  child: Center(child: Text('Thu', semanticsLabel: 'Thursday')),
                ),
                Expanded(
                  child: Center(child: Text('Fri', semanticsLabel: 'Friday')),
                ),
                Expanded(
                  child: Center(child: Text('Sat', semanticsLabel: 'Saturday')),
                ),
                Expanded(
                  child: Center(child: Text('Sun', semanticsLabel: 'Sunday')),
                ),
              ],
            ),
            const SizedBox(height: 6),
            for (final row in rows)
              Row(
                children: [
                  for (final day in row)
                    Expanded(
                      child: day == null
                          ? const SizedBox(height: 74)
                          : _buildRamadanDayCell(day),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Tracker'),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppPalette.backgroundGradient,
        ),
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  semanticsLabel: 'Loading tracker data',
                ),
              )
            : RefreshIndicator(
                onRefresh: _loadTrackerData,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.checklist,
                                  color: AppPalette.accent,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Prayer Tracker',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Today — $_completedCount of ${_trackedPrayers.length} prayers logged',
                              style: const TextStyle(
                                color: AppPalette.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            for (final prayer in _trackedPrayers)
                              CheckboxListTile(
                                value: _prayerStatuses[prayer] ?? false,
                                contentPadding: EdgeInsets.zero,
                                title: Text(prayer),
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                                onChanged: (value) {
                                  if (value == null) return;
                                  _togglePrayer(prayer, value);
                                },
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildRamadanTrackerCard(),
                  ],
                ),
              ),
      ),
    );
  }
}
