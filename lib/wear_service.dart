import 'dart:convert';
import 'package:adhan/adhan.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'db_helper.dart';
import 'prayer_service.dart';
import 'notification_service.dart';

class WearTrackerNotifier extends ChangeNotifier {
  void notify() => notifyListeners();
}

class WearService {
  WearService._();
  static final WearService instance = WearService._();

  static const MethodChannel _channel = MethodChannel('com.example.athan/wear');

  /// Notifier to alert UI screens (like TrackerPage) when watch changes tracker state.
  static final WearTrackerNotifier trackerChangeNotifier = WearTrackerNotifier();

  bool _initialized = false;

  void initialize() {
    if (_initialized) return;
    _channel.setMethodCallHandler(_handleMethodCall);
    _initialized = true;
    debugPrint('[WEAR_SERVICE] Initialized Wear OS sync service');
  }

  Future<void> _handleMethodCall(MethodCall call) async {
    debugPrint('[WEAR_SERVICE] Method call received: ${call.method}');
    switch (call.method) {
      case 'onTrackerUpdatedFromWatch':
        final jsonStr = call.arguments as String?;
        if (jsonStr != null) {
          await _handleTrackerUpdateFromWatch(jsonStr);
        }
        break;
      case 'onRequestSync':
        await syncLatestStateToWatch();
        break;
      case 'onStopAthanFromWatch':
        await NotificationService.instance.stopAllPlayback();
        break;
      default:
        debugPrint('[WEAR_SERVICE] Unhandled method call: ${call.method}');
    }
  }

  Future<void> _handleTrackerUpdateFromWatch(String jsonStr) async {
    try {
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;
      final prayerName = data['prayerName'] as String?;
      final completed = data['completed'] as bool?;
      if (prayerName != null && completed != null) {
        final todayKey = DateFormat('yyyy-MM-dd').format(DateTime.now());
        debugPrint('[WEAR_SERVICE] Saving tracker update from watch: $prayerName = $completed');
        await DBHelper.setPrayerCompleted(
          dateKey: todayKey,
          prayerName: prayerName,
          completed: completed,
        );
        // Alert Dart listeners
        trackerChangeNotifier.notify();
      }
    } catch (e) {
      debugPrint('[WEAR_SERVICE] Error parsing tracker update from watch: $e');
    }
  }

  /// Calculates prayer times and tracker status and pushes the data to the Wear OS watch.
  Future<void> syncLatestStateToWatch() async {
    try {
      final latStr = await DBHelper.getSetting('last_known_lat');
      final lngStr = await DBHelper.getSetting('last_known_lng');
      if (latStr == null || lngStr == null) {
        debugPrint('[WEAR_SERVICE] Sync skipped: No cached location coordinates found');
        return;
      }

      final lat = double.parse(latStr);
      final lng = double.parse(lngStr);
      final today = DateTime.now();
      final todayKey = DateFormat('yyyy-MM-dd').format(today);

      // Get calculated prayer times
      final times = PrayerService.getTimesForDate(lat, lng, today);
      final fmt = DateFormat('hh:mm a');
      
      final prayerTimesMap = {
        'Fajr': fmt.format(times.fajr),
        'Sunrise': fmt.format(times.sunrise),
        'Dhuhr': fmt.format(times.dhuhr),
        'Asr': fmt.format(times.asr),
        'Maghrib': fmt.format(times.maghrib),
        'Isha': fmt.format(times.isha),
      };

      // Get tracker state
      final dbTracker = await DBHelper.getPrayerLogForDate(todayKey);
      final trackerMap = {
        'Fajr': dbTracker['Fajr'] ?? false,
        'Dhuhr': dbTracker['Dhuhr'] ?? false,
        'Asr': dbTracker['Asr'] ?? false,
        'Maghrib': dbTracker['Maghrib'] ?? false,
        'Isha': dbTracker['Isha'] ?? false,
      };

      // Get next prayer details
      final coords = Coordinates(lat, lng);
      // adhan package calculation logic
      final params = CalculationMethod.muslim_world_league.getParameters()
        ..madhab = Madhab.shafi;
      final adhanTimes = PrayerTimes(coords, DateComponents.from(today), params);
      
      final nextPrayer = adhanTimes.nextPrayer();
      final nextPrayerName = nextPrayer == Prayer.none ? 'Fajr' : nextPrayer.name.toUpperCase()[0] + nextPrayer.name.substring(1);
      
      // Get next prayer time format (HH:mm)
      DateTime? nextTime;
      if (nextPrayer == Prayer.none) {
        // Next day's Fajr
        final tomorrow = today.add(const Duration(days: 1));
        final tomTimes = PrayerTimes(coords, DateComponents.from(tomorrow), params);
        nextTime = tomTimes.fajr;
      } else {
        nextTime = adhanTimes.timeForPrayer(nextPrayer);
      }
      
      final nextPrayerTimeStr = nextTime != null ? DateFormat('HH:mm').format(nextTime) : '';

      final syncPayload = {
        'lat': lat,
        'lng': lng,
        'prayerTimes': prayerTimesMap,
        'tracker': trackerMap,
        'nextPrayerName': nextPrayerName,
        'nextPrayerTime': nextPrayerTimeStr,
      };

      final jsonStr = jsonEncode(syncPayload);
      debugPrint('[WEAR_SERVICE] Syncing payload to watch: $jsonStr');
      
      await _channel.invokeMethod('syncData', jsonStr);
    } catch (e) {
      debugPrint('[WEAR_SERVICE] Error compiling sync payload: $e');
    }
  }

  /// Sends a real-time message trigger to the watch when the phone plays the Athan notification.
  Future<void> sendAthanNotification(String prayerName) async {
    try {
      debugPrint('[WEAR_SERVICE] Sending Athan notification trigger to watch: $prayerName');
      await _channel.invokeMethod('sendAthanNotification', prayerName);
    } catch (e) {
      debugPrint('[WEAR_SERVICE] Error sending Athan notification message to watch: $e');
    }
  }
}
