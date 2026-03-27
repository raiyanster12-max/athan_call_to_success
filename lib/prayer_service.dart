import 'package:adhan/adhan.dart';

class PrayerService {
  // This function calculates times locally without any API calls
  static PrayerTimes getTimes(double lat, double lng) {
    final coordinates = Coordinates(lat, lng);
    
    // Choose the calculation method (North America is usually 'north_america')
    final params = CalculationMethod.north_america.getParameters();
    params.madhab = Madhab.shafi; // Or Madhab.hanafi depending on preference

    final date = DateTime.now();
    return PrayerTimes.today(coordinates, params);
  }
}