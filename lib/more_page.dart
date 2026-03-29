import 'package:flutter/material.dart';
import 'package:hijri_date/hijri.dart';
import 'package:intl/intl.dart';

import 'masjid_page.dart';
import 'settings_page.dart';

class MorePage extends StatelessWidget {
  const MorePage({super.key});

  String get _gregorianLabel =>
      DateFormat('EEEE, MMMM d, y').format(DateTime.now());

  String get _hijriLabel =>
      HijriDate.fromDate(DateTime.now()).toFormat('DDDD, MMMM dd, yyyy');

  void _openSettings(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SettingsPage()),
    );
  }

  void _openMasjidFinder(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const MasjidPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
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
              child: Row(
                children: [
                  const Icon(
                    Icons.calendar_month_rounded,
                    color: Color(0xFF00796B),
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _gregorianLabel,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _hijriLabel,
                          style: const TextStyle(color: Colors.black54),
                        ),
                      ],
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
    );
  }
}
