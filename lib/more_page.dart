import 'package:flutter/material.dart';
import 'package:hijri_date/hijri.dart';
import 'package:intl/intl.dart';

import 'app_palette.dart';
import 'masjid_page.dart';


class MorePage extends StatefulWidget {
  const MorePage({super.key});

  @override
  State<MorePage> createState() => _MorePageState();
}

class _MorePageState extends State<MorePage> {
  bool _showMasjidFinder = false;
  DateTime _selectedDate = DateTime.now();

  String get _selectedGregorianLabel =>
      DateFormat('EEEE, MMMM d, y').format(_selectedDate);

  String get _selectedHijriLabel =>
      HijriDate.fromDate(_selectedDate).toFormat('DDDD, MMMM dd, yyyy');

  void _openMasjidFinder(BuildContext context) {
    setState(() => _showMasjidFinder = true);
  }

  void _setSelectedDate(DateTime date) {
    setState(() => _selectedDate = date);
  }

  void _jumpToToday() {
    final now = DateTime.now();
    setState(() {
      _selectedDate = DateTime(now.year, now.month, now.day);
    });
  }

  void _closeMasjidFinder() {
    setState(() => _showMasjidFinder = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_showMasjidFinder) {
      return MasjidPage(onBack: _closeMasjidFinder);
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('More'),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppPalette.backgroundGradient,
        ),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Calendar View',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Selected: $_selectedGregorianLabel',
                      style: const TextStyle(color: AppPalette.textSecondary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _selectedHijriLabel,
                      style: const TextStyle(color: AppPalette.textMuted),
                    ),
                    const SizedBox(height: 12),
                    Theme(
                      data: Theme.of(context).copyWith(
                        colorScheme: Theme.of(context).colorScheme.copyWith(
                          primary: AppPalette.accent,
                          onSurface: AppPalette.textPrimary,
                        ),
                      ),
                      child: CalendarDatePicker(
                        initialDate: _selectedDate,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                        onDateChanged: _setSelectedDate,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: OutlinedButton.icon(
                        onPressed: _jumpToToday,
                        icon: const Icon(Icons.today_outlined),
                        label: const Text('Today'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.mosque_outlined),
                    title: const Text('Masjid Finder'),
                    subtitle: const Text('Find nearby and saved masjids'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _openMasjidFinder(context),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
