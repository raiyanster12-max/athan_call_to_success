import 'package:flutter_test/flutter_test.dart';
import 'package:athan_call_to_success/prayer_service.dart';

void main() {
  // New York City coordinates used as stable reference point.
  const double nyLat = 40.7128;
  const double nyLng = -74.0060;

  group('PrayerService.getTimesForDate', () {
    test('returns non-null prayer times for valid coordinates', () {
      final times = PrayerService.getTimesForDate(
        nyLat,
        nyLng,
        DateTime(2025, 6, 15),
      );
      expect(times, isNotNull);
    });

    test('fajr is before dhuhr, dhuhr before asr, asr before maghrib, maghrib before isha', () {
      final times = PrayerService.getTimesForDate(
        nyLat,
        nyLng,
        DateTime(2025, 6, 15),
      );
      expect(times.fajr.isBefore(times.dhuhr), isTrue);
      expect(times.dhuhr.isBefore(times.asr), isTrue);
      expect(times.asr.isBefore(times.maghrib), isTrue);
      expect(times.maghrib.isBefore(times.isha), isTrue);
    });

    test('fajr is in the early morning (before noon)', () {
      final times = PrayerService.getTimesForDate(
        nyLat,
        nyLng,
        DateTime(2025, 6, 15),
      );
      expect(times.fajr.hour, lessThan(12));
    });

    test('different dates produce different prayer times', () {
      final june = PrayerService.getTimesForDate(nyLat, nyLng, DateTime(2025, 6, 15));
      final december = PrayerService.getTimesForDate(nyLat, nyLng, DateTime(2025, 12, 15));
      expect(june.fajr, isNot(equals(december.fajr)));
    });
  });

  group('PrayerService.getObligatoryPrayers', () {
    test('returns exactly 5 prayers', () {
      final times = PrayerService.getTimesForDate(nyLat, nyLng, DateTime(2025, 6, 15));
      final prayers = PrayerService.getObligatoryPrayers(times);
      expect(prayers.length, equals(5));
    });

    test('prayer names are Fajr/Dhuhr/Asr/Maghrib/Isha in order', () {
      final times = PrayerService.getTimesForDate(nyLat, nyLng, DateTime(2025, 6, 15));
      final prayers = PrayerService.getObligatoryPrayers(times);
      final names = prayers.map((p) => p.name).toList();
      expect(names, equals(['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha']));
    });

    test('prayer times are in ascending order', () {
      final times = PrayerService.getTimesForDate(nyLat, nyLng, DateTime(2025, 6, 15));
      final prayers = PrayerService.getObligatoryPrayers(times);
      for (int i = 0; i < prayers.length - 1; i++) {
        expect(
          prayers[i].time.isBefore(prayers[i + 1].time),
          isTrue,
          reason: '${prayers[i].name} should be before ${prayers[i + 1].name}',
        );
      }
    });
  });

  group('PrayerService.getNextPrayer', () {
    test('returns a prayer whose time is after the reference time', () {
      // Use a fixed time just before Fajr so the next prayer is well-defined.
      final ref = DateTime(2025, 6, 15, 3, 0); // 3:00 AM
      final next = PrayerService.getNextPrayer(nyLat, nyLng, now: ref);
      expect(next.time.isAfter(ref), isTrue);
    });

    test('returns Fajr when ref is after Isha (wraps to next day)', () {
      // 11:59 PM — after all prayers for the day.
      final ref = DateTime(2025, 6, 15, 23, 59);
      final next = PrayerService.getNextPrayer(nyLat, nyLng, now: ref);
      expect(next.name, equals('Fajr'));
      // Should be tomorrow's Fajr.
      expect(next.time.day, equals(16));
    });

    test('result name is one of the 5 obligatory prayers', () {
      final ref = DateTime(2025, 6, 15, 12, 0);
      final next = PrayerService.getNextPrayer(nyLat, nyLng, now: ref);
      expect(
        ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'].contains(next.name),
        isTrue,
      );
    });

    test('returns Dhuhr when ref is between Fajr and Dhuhr', () {
      final times = PrayerService.getTimesForDate(nyLat, nyLng, DateTime(2025, 6, 15));
      // One minute after Fajr → next should be Dhuhr.
      final ref = times.fajr.add(const Duration(minutes: 1));
      final next = PrayerService.getNextPrayer(nyLat, nyLng, now: ref);
      expect(next.name, equals('Dhuhr'));
    });
  });
}
