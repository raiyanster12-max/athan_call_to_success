import 'package:adhan/adhan.dart';
import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'prayer_service.dart';

class WidgetService {
  static bool get _supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static const List<Map<String, String>> _verses = [
    {
      'arabic': 'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ',
      'translation': 'In the name of Allah, the Entirely Merciful, the Especially Merciful.',
      'reference': 'Al-Fatihah 1:1',
    },
    {
      'arabic': 'قُلْ هُوَ اللَّهُ أَحَدٌ ۝ اللَّهُ الصَّمَدُ',
      'translation': 'Say: He is Allah, the One. Allah, the Eternal Refuge.',
      'reference': 'Al-Ikhlas 112:1-2',
    },
    {
      'arabic': 'اللَّهُ لَا إِلَٰهَ إِلَّا هُوَ الْحَيُّ الْقَيُّومُ',
      'translation': 'Allah — there is no deity except Him, the Ever-Living, the Sustainer.',
      'reference': 'Al-Baqarah 2:255',
    },
    {
      'arabic': 'وَالْعَصْرِ ۝ إِنَّ الْإِنسَانَ لَفِي خُسْرٍ',
      'translation': 'By time. Indeed, mankind is in loss.',
      'reference': 'Al-Asr 103:1-2',
    },
    {
      'arabic': 'إِنَّا أَعْطَيْنَاكَ الْكَوْثَرَ',
      'translation': 'Indeed, We have granted you Al-Kawthar.',
      'reference': 'Al-Kawthar 108:1',
    },
    {
      'arabic': 'فَإِنَّ مَعَ الْعُسْرِ يُسْرًا ۝ إِنَّ مَعَ الْعُسْرِ يُسْرًا',
      'translation': 'For indeed, with hardship will be ease. Indeed, with hardship will be ease.',
      'reference': 'Ash-Sharh 94:5-6',
    },
    {
      'arabic': 'وَعَسَىٰ أَن تَكْرَهُوا شَيْئًا وَهُوَ خَيْرٌ لَّكُمْ',
      'translation': 'But perhaps you hate a thing and it is good for you.',
      'reference': 'Al-Baqarah 2:216',
    },
    {
      'arabic': 'إِنَّ اللَّهَ مَعَ الصَّابِرِينَ',
      'translation': 'Indeed, Allah is with the patient.',
      'reference': 'Al-Baqarah 2:153',
    },
    {
      'arabic': 'حَسْبُنَا اللَّهُ وَنِعْمَ الْوَكِيلُ',
      'translation': 'Sufficient for us is Allah, and He is the best Disposer of affairs.',
      'reference': 'Al Imran 3:173',
    },
    {
      'arabic': 'إِنَّ مَعَ الْعُسْرِ يُسْرًا',
      'translation': 'Indeed, with hardship will be ease.',
      'reference': 'Ash-Sharh 94:6',
    },
    {
      'arabic': 'وَقُل رَّبِّ زِدْنِي عِلْمًا',
      'translation': 'And say: My Lord, increase me in knowledge.',
      'reference': 'Ta-Ha 20:114',
    },
    {
      'arabic': 'رَبَّنَا آتِنَا فِي الدُّنْيَا حَسَنَةً وَفِي الْآخِرَةِ حَسَنَةً',
      'translation': 'Our Lord, give us in this world good and in the Hereafter good.',
      'reference': 'Al-Baqarah 2:201',
    },
    {
      'arabic': 'وَهُوَ مَعَكُمْ أَيْنَ مَا كُنتُمْ',
      'translation': 'And He is with you wherever you are.',
      'reference': 'Al-Hadid 57:4',
    },
    {
      'arabic': 'أَلَا بِذِكْرِ اللَّهِ تَطْمَئِنُّ الْقُلُوبُ',
      'translation': 'Verily, in the remembrance of Allah do hearts find rest.',
      'reference': 'Ar-Ra\'d 13:28',
    },
  ];

  static Map<String, String> get _todayVerse {
    final day = DateTime.now().difference(DateTime(DateTime.now().year, 1, 1)).inDays;
    return _verses[day % _verses.length];
  }

  static Future<void> updateAll({
    required double lat,
    required double lng,
    Map<String, bool> prayerLog = const {},
    String city = '',
  }) async {
    if (!_supported) return;
    final fmt = DateFormat.jm();

    // Prayer times
    final times = PrayerService.getTimes(lat, lng);
    await HomeWidget.saveWidgetData('widget_fajr_time', fmt.format(times.fajr));
    await HomeWidget.saveWidgetData('widget_dhuhr_time', fmt.format(times.dhuhr));
    await HomeWidget.saveWidgetData('widget_asr_time', fmt.format(times.asr));
    await HomeWidget.saveWidgetData('widget_maghrib_time', fmt.format(times.maghrib));
    await HomeWidget.saveWidgetData('widget_isha_time', fmt.format(times.isha));

    // Next prayer
    final next = PrayerService.getNextPrayer(lat, lng);
    await HomeWidget.saveWidgetData('widget_next_prayer_name', next.name);
    await HomeWidget.saveWidgetData('widget_next_prayer_time', fmt.format(next.time));

    // City
    if (city.isNotEmpty) await HomeWidget.saveWidgetData('widget_city', city);

    // Prayer tracker
    int done = 0;
    for (final prayer in ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha']) {
      final completed = prayerLog[prayer] ?? false;
      await HomeWidget.saveWidgetData('widget_tracker_${prayer.toLowerCase()}', completed);
      if (completed) done++;
    }
    await HomeWidget.saveWidgetData('widget_tracker_count', '$done/5');

    // Qibla
    final qibla = Qibla(Coordinates(lat, lng));
    final bearing = qibla.direction;
    await HomeWidget.saveWidgetData('widget_qibla_bearing', '${bearing.toStringAsFixed(0)}°');
    await HomeWidget.saveWidgetData('widget_qibla_direction', _bearingToCompass(bearing));

    // Quran verse of the day
    final verse = _todayVerse;
    await HomeWidget.saveWidgetData('widget_quran_arabic', verse['arabic']);
    await HomeWidget.saveWidgetData('widget_quran_translation', verse['translation']);
    await HomeWidget.saveWidgetData('widget_quran_reference', verse['reference']);

    await _notifyAll();
  }

  static Future<void> updateTrackerOnly(Map<String, bool> prayerLog) async {
    if (!_supported) return;
    int done = 0;
    for (final prayer in ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha']) {
      final completed = prayerLog[prayer] ?? false;
      await HomeWidget.saveWidgetData('widget_tracker_${prayer.toLowerCase()}', completed);
      if (completed) done++;
    }
    await HomeWidget.saveWidgetData('widget_tracker_count', '$done/5');
    await HomeWidget.updateWidget(androidName: 'PrayerTrackerWidgetProvider');
  }

  static Future<void> cacheLocation(double lat, double lng, {String city = ''}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('widget_cached_lat', lat);
    await prefs.setDouble('widget_cached_lng', lng);
    if (city.isNotEmpty) await prefs.setString('widget_cached_city', city);
  }

  static Future<void> updateFromCache({Map<String, bool> prayerLog = const {}}) async {
    if (!_supported) return;
    final prefs = await SharedPreferences.getInstance();
    final lat = prefs.getDouble('widget_cached_lat');
    final lng = prefs.getDouble('widget_cached_lng');
    if (lat != null && lng != null) {
      final city = prefs.getString('widget_cached_city') ?? '';
      await updateAll(lat: lat, lng: lng, prayerLog: prayerLog, city: city);
    } else {
      await _updateQuranOnly();
    }
  }

  static Future<void> _updateQuranOnly() async {
    if (!_supported) return;
    final verse = _todayVerse;
    await HomeWidget.saveWidgetData('widget_quran_arabic', verse['arabic']);
    await HomeWidget.saveWidgetData('widget_quran_translation', verse['translation']);
    await HomeWidget.saveWidgetData('widget_quran_reference', verse['reference']);
    await HomeWidget.updateWidget(androidName: 'QuranWidgetProvider');
  }

  static Future<void> _notifyAll() async {
    await HomeWidget.updateWidget(androidName: 'NextPrayerWidgetProvider');
    await HomeWidget.updateWidget(androidName: 'PrayerTimesWidgetProvider');
    await HomeWidget.updateWidget(androidName: 'PrayerTrackerWidgetProvider');
    await HomeWidget.updateWidget(androidName: 'QuranWidgetProvider');
    await HomeWidget.updateWidget(androidName: 'QiblaWidgetProvider');
  }

  static String _bearingToCompass(double bearing) {
    const dirs = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    return dirs[((bearing + 22.5) / 45).floor() % 8];
  }
}
