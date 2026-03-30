import 'package:flutter/material.dart';
import 'package:hijri_date/hijri.dart';
import 'package:intl/intl.dart';

import 'masjid_page.dart';
import 'qibla_page.dart';
import 'settings_page.dart';

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

  void _openSettings(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SettingsPage()),
    );
  }

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
      appBar: AppBar(
        title: const Text('More'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () => _openSettings(context),
          ),
        ],
      ),
      body: ListView(
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
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Selected: $_selectedGregorianLabel',
                    style: const TextStyle(color: Colors.black87),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _selectedHijriLabel,
                    // WCAG 1.4.3: accessible contrast for secondary text
                    style: const TextStyle(color: Color(0xFF616161)),
                  ),
                  const SizedBox(height: 12),
                  CalendarDatePicker(
                    initialDate: _selectedDate,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                    onDateChanged: _setSelectedDate,
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
                  leading: const Icon(Icons.explore_outlined),
                  title: const Text('Qibla Compass'),
                  subtitle: const Text('Find the direction of the Kaaba'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const QiblaPage()),
                  ),
                ),
                const Divider(height: 0),
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
    );
  }
}
