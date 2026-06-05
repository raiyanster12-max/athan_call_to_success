import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hijri_date/hijri.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_palette.dart';
import 'db_helper.dart';
import 'widget_service.dart';

class TrackerPage extends StatefulWidget {
  const TrackerPage({super.key});

  @override
  State<TrackerPage> createState() => _TrackerPageState();
}

class _TrackerPageState extends State<TrackerPage> {
  static const String _ramadanStatusStoragePrefix = 'ramadan_status_year_';
  static const String _prayerStatusStoragePrefix = 'prayer_status_date_';
  static const List<String> _trackedPrayers = [
    'Fajr',
    'Dhuhr',
    'Asr',
    'Maghrib',
    'Isha',
  ];

  bool _isLoading = true;
  bool _isBackupBusy = false;
  bool _isDatabaseAvailable = true;
  String _databaseErrorMessage = '';
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
    // On web/PWA, use shared_preferences (backed by browser local storage).
    if (kIsWeb) {
      final prayerStatuses = await _loadWebPrayerStatuses(_todayKey);
      final ramadanDates = _buildRamadanDatesForYear(_currentYear);
      final savedRamadanStatuses = await _loadWebRamadanStatuses(_currentYear);
      if (!mounted) return;
      setState(() {
        _prayerStatuses = {
          for (final prayer in _trackedPrayers)
            prayer: prayerStatuses[prayer] ?? false,
        };
        _ramadanDates = ramadanDates;
        _ramadanStatuses = savedRamadanStatuses;
        _isDatabaseAvailable = true;
        _databaseErrorMessage = '';
        _isLoading = false;
      });
      return;
    }

    try {
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
        _isDatabaseAvailable = true;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isDatabaseAvailable = false;
        _databaseErrorMessage = 'Error loading tracker data: ${e.toString()}';
        _isLoading = false;
      });
    }
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

  String _prayerStorageKey(String dateKey) =>
      '$_prayerStatusStoragePrefix$dateKey';

  Future<Map<String, bool>> _loadWebPrayerStatuses(String dateKey) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prayerStorageKey(dateKey));
    if (raw == null || raw.trim().isEmpty) {
      return <String, bool>{};
    }

    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map((key, value) => MapEntry(key, value == true));
    } catch (_) {
      return <String, bool>{};
    }
  }

  Future<void> _saveWebPrayerStatuses(String dateKey) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = <String, bool>{
      for (final prayer in _trackedPrayers)
        prayer: _prayerStatuses[prayer] ?? false,
    };
    await prefs.setString(_prayerStorageKey(dateKey), jsonEncode(payload));
  }

  Future<Map<String, String>> _loadWebRamadanStatuses(int year) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_ramadanStorageKey(year));
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

  Future<void> _saveWebRamadanStatuses() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _ramadanStorageKey(_currentYear),
      jsonEncode(_ramadanStatuses),
    );
  }


  Future<String> _buildRamadanTrackerCsv() async {
    if (_ramadanDates.isEmpty) return 'No Ramadan dates found';

    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final rawRamadan = prefs.getString(_ramadanStorageKey(_currentYear));
      Map<String, String> ramadanStatus = {};
      if (rawRamadan != null && rawRamadan.isNotEmpty) {
        try {
          final decoded = jsonDecode(rawRamadan) as Map<String, dynamic>;
          ramadanStatus = decoded.map(
            (k, v) => MapEntry(k, v?.toString() ?? ''),
          );
        } catch (_) {
          // Continue with empty statuses
        }
      }

      final csv = StringBuffer();
      csv.writeln('Date,Hijri Day,Gregorian Date,Status');
      for (final date in _ramadanDates) {
        final dateKey = _dateKey(date);
        final hijriDay = HijriDate.fromDate(date).hDay;
        final gregDate = DateFormat('MMM d, yyyy').format(date);
        final status = ramadanStatus[dateKey] ?? 'Pending';
        csv.writeln('$dateKey,$hijriDay,$gregDate,$status');
      }
      return csv.toString();
    }

    final payload = await DBHelper.exportTrackerData();
    final ramadanStatusByYear =
        (payload['ramadanStatusByYear'] as Map?)?.cast<String, Map>() ??
        <String, Map>{};
    final ramadanStatus =
        ramadanStatusByYear[_currentYear.toString()]?.cast<String, String>() ??
        <String, String>{};

    final csv = StringBuffer();
    csv.writeln('Date,Hijri Day,Gregorian Date,Status');
    for (final date in _ramadanDates) {
      final dateKey = _dateKey(date);
      final hijriDay = HijriDate.fromDate(date).hDay;
      final gregDate = DateFormat('MMM d, yyyy').format(date);
      final status = ramadanStatus[dateKey] ?? 'Pending';
      csv.writeln('$dateKey,$hijriDay,$gregDate,$status');
    }
    return csv.toString();
  }

  Future<void> _exportTrackerAsCsv() async {
    setState(() {
      _isBackupBusy = true;
    });

    try {
      final ramadanCsv = await _buildRamadanTrackerCsv();

      await Clipboard.setData(ClipboardData(text: ramadanCsv));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ramadan tracker exported as CSV to clipboard.'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Export failed: $e'),
          duration: const Duration(seconds: 3),
        ),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _isBackupBusy = false;
      });
    }
  }

  Future<void> _importTrackerFromCsv(String csvText) async {
    setState(() {
      _isBackupBusy = true;
    });

    try {
      final lines = csvText.split('\n').where((l) => l.isNotEmpty).toList();

      for (final line in lines) {
        final trimmed = line.trim();

        // Skip header rows
        if (trimmed.startsWith('Date,')) continue;

        final parts = trimmed.split(',');
        if (parts.isEmpty) continue;

        // Import only Ramadan tracker data
        if (parts.length >= 4) {
          final dateKey = parts[0].trim();
          final status = parts[3].trim().toLowerCase();

          if (status != 'pending' && status.isNotEmpty) {
            if (kIsWeb) {
              final prefs = await SharedPreferences.getInstance();
              final rawRamadan = prefs.getString(_ramadanStorageKey(_currentYear));
              Map<String, String> statuses = {};
              if (rawRamadan != null && rawRamadan.isNotEmpty) {
                try {
                  final decoded = jsonDecode(rawRamadan) as Map<String, dynamic>;
                  statuses =
                      decoded.map((k, v) => MapEntry(k, v?.toString() ?? ''));
                } catch (_) {}
              }
              statuses[dateKey] = status;
              await prefs.setString(
                _ramadanStorageKey(_currentYear),
                jsonEncode(statuses),
              );
            } else {
              final rawRamadan = await DBHelper.getSetting(
                _ramadanStorageKey(_currentYear),
              );
              Map<String, String> statuses = {};
              if (rawRamadan != null && rawRamadan.isNotEmpty) {
                try {
                  final decoded = jsonDecode(rawRamadan) as Map<String, dynamic>;
                  statuses =
                      decoded.map((k, v) => MapEntry(k, v?.toString() ?? ''));
                } catch (_) {}
              }
              statuses[dateKey] = status;
              await DBHelper.setSetting(
                _ramadanStorageKey(_currentYear),
                jsonEncode(statuses),
              );
            }
          }
        }
      }

      await _loadTrackerData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ramadan tracker imported from CSV successfully.'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Import failed: $e'),
          duration: const Duration(seconds: 3),
        ),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _isBackupBusy = false;
      });
    }
  }

  Future<void> _pasteAndImportCsv() async {
    final controller = TextEditingController();
    final pasted = await Clipboard.getData('text/plain');
    controller.text = pasted?.text ?? '';

    if (!mounted) return;
    final csvText = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Import Ramadan Tracker CSV'),
        content: SizedBox(
          width: 520,
          child: TextField(
            controller: controller,
            maxLines: 12,
            minLines: 8,
            decoration: const InputDecoration(
              hintText: 'Paste Ramadan tracker CSV data here',
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: const Text('Import'),
          ),
        ],
      ),
    );

    if (csvText == null || csvText.trim().isEmpty) {
      return;
    }

    await _importTrackerFromCsv(csvText);
    controller.dispose();
  }


  Future<void> _showBackupRestoreDialog() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Export & Import Ramadan Tracker'),
        content: const Text(
          'Export Ramadan tracker as CSV (compatible with Excel and spreadsheets). Import restores from pasted CSV and replaces existing Ramadan history on this device.',
        ),
        actions: [
          TextButton(
            onPressed: _isBackupBusy
                ? null
                : () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
          OutlinedButton.icon(
            onPressed: _isBackupBusy
                ? null
                : () async {
                    Navigator.of(dialogContext).pop();
                    await _pasteAndImportCsv();
                  },
            icon: const Icon(Icons.file_download_outlined),
            label: const Text('Import CSV'),
          ),
          ElevatedButton.icon(
            onPressed: _isBackupBusy
                ? null
                : () async {
                    Navigator.of(dialogContext).pop();
                    await _exportTrackerAsCsv();
                  },
            icon: const Icon(Icons.file_upload_outlined),
            label: const Text('Export CSV'),
          ),
        ],
      ),
    );
  }

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
    if (kIsWeb) {
      await _saveWebRamadanStatuses();
      return;
    }
    await DBHelper.setSetting(
      _ramadanStorageKey(_currentYear),
      jsonEncode(_ramadanStatuses),
    );
  }

  Future<void> _togglePrayer(String prayer, bool value) async {
    if (!_isDatabaseAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot save: Database not available on this platform'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    if (kIsWeb) {
      setState(() {
        _prayerStatuses[prayer] = value;
      });
      try {
        await _saveWebPrayerStatuses(_todayKey);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error saving prayer status: $e'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
      return;
    }

    try {
      await DBHelper.setPrayerCompleted(
        dateKey: _todayKey,
        prayerName: prayer,
        completed: value,
      );
      if (!mounted) return;
      setState(() {
        _prayerStatuses[prayer] = value;
      });
      unawaited(WidgetService.updateTrackerOnly(Map<String, bool>.from(_prayerStatuses)));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving prayer status: $e'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  String _dateKey(DateTime date) => DateFormat('yyyy-MM-dd').format(date);

  Future<void> _toggleRamadanStatus(DateTime date) async {
    if (!_isDatabaseAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot save: Database not available on this platform'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
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
    try {
      await _saveRamadanStatuses();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving Ramadan status: $e'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _selectAllRamadanDays() async {
    if (!_isDatabaseAvailable || _ramadanDates.isEmpty) {
      return;
    }

    setState(() {
      _ramadanStatuses = {
        for (final date in _ramadanDates) _dateKey(date): 'done',
      };
    });

    try {
      await _saveRamadanStatuses();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All Ramadan days marked as done.'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving Ramadan status: $e'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
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
    Color statusColor = AppPalette.of(context).textMuted;
    Color backgroundColor = AppPalette.of(context).surface;

    // WCAG 4.1.2: determine semantic status label for screen readers
    String statusLabel;
    if (status == 'done') {
      statusIcon = Icons.check_circle;
      statusColor = AppPalette.accent;
      backgroundColor = AppPalette.of(context).surfaceRaised;
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
                color: isToday ? AppPalette.accent : AppPalette.of(context).outline,
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
                  style: TextStyle(
                    fontSize: 11,
                    color: AppPalette.of(context).textSecondary,
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
            Text(
              'Tap each day to cycle: pending -> done -> missed -> pending.',
              style: TextStyle(color: AppPalette.of(context).textSecondary),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: _selectAllRamadanDays,
                icon: const Icon(Icons.done_all),
                label: const Text('Select All'),
              ),
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

  Widget _buildBackupRestoreCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.import_export, color: AppPalette.accent),
                const SizedBox(width: 8),
                Text(
                  'Export & Import Ramadan Tracker',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Export your Ramadan tracker as CSV (for spreadsheets) or import CSV data on this device.',
              style: TextStyle(color: AppPalette.of(context).textSecondary),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                OutlinedButton.icon(
                  onPressed: _isBackupBusy ? null : _pasteAndImportCsv,
                  icon: const Icon(Icons.file_download_outlined),
                  label: const Text('Import CSV'),
                ),
                ElevatedButton.icon(
                  onPressed: _isBackupBusy ? null : _exportTrackerAsCsv,
                  icon: const Icon(Icons.file_upload_outlined),
                  label: const Text('Export as CSV'),
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
      backgroundColor: AppPalette.pageBackground,
      appBar: AppBar(
        backgroundColor: AppPalette.pageBackground,
        foregroundColor: const Color(0xFFE8E6FF),
        title: const Text('Tracker'),
        actions: [
          IconButton(
            tooltip: 'Export and import Ramadan tracker CSV',
            onPressed: _isLoading || _isBackupBusy
                ? null
                : _showBackupRestoreDialog,
            icon: const Icon(Icons.import_export),
          ),
        ],
      ),
      body: Container(
        color: AppPalette.pageBackground,
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  semanticsLabel: 'Loading tracker data',
                ),
              )
            : !_isDatabaseAvailable
            ? Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 48,
                            color: AppPalette.of(context).textSecondary,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Tracker Unavailable',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _databaseErrorMessage,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppPalette.of(context).textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              )
            : RefreshIndicator(
                onRefresh: _loadTrackerData,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 920),
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
                                  style: TextStyle(
                                    color: AppPalette.of(context).textSecondary,
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
              ),
      ),
    );
  }
}
