import 'package:adhan/adhan.dart';

class PrayerScheduleItem {
  const PrayerScheduleItem({required this.name, required this.time});

  final String name;
  final DateTime time;
}

class NextPrayerInfo {
  const NextPrayerInfo({required this.name, required this.time});

  final String name;
  final DateTime time;
}

class PrayerService {
  static CalculationParameters _buildParameters() {
    final params = CalculationMethod.north_america.getParameters();
    params.madhab = Madhab.shafi;
    return params;
  }

  // This function calculates times locally without any API calls
  static PrayerTimes getTimes(double lat, double lng) {
    return getTimesForDate(lat, lng, DateTime.now());
  }

  static PrayerTimes getTimesForDate(double lat, double lng, DateTime date) {
    final coordinates = Coordinates(lat, lng);

    return PrayerTimes(
      coordinates,
      DateComponents.from(date),
      _buildParameters(),
    );
  }

  static List<PrayerScheduleItem> getObligatoryPrayers(PrayerTimes times) {
    return [
      PrayerScheduleItem(name: 'Fajr', time: times.fajr),
      PrayerScheduleItem(name: 'Dhuhr', time: times.dhuhr),
      PrayerScheduleItem(name: 'Asr', time: times.asr),
      PrayerScheduleItem(name: 'Maghrib', time: times.maghrib),
      PrayerScheduleItem(name: 'Isha', time: times.isha),
    ];
  }

  static NextPrayerInfo getNextPrayer(double lat, double lng, {DateTime? now}) {
    final reference = now ?? DateTime.now();
    final today = getTimesForDate(lat, lng, reference);

    for (final prayer in getObligatoryPrayers(today)) {
      if (prayer.time.isAfter(reference)) {
        return NextPrayerInfo(name: prayer.name, time: prayer.time);
      }
    }

    final tomorrow = getTimesForDate(lat, lng, reference.add(const Duration(days: 1)));
    return NextPrayerInfo(name: 'Fajr', time: tomorrow.fajr);
  }
}