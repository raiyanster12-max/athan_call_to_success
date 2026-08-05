import 'package:flutter_test/flutter_test.dart';
import 'package:athan_call_to_success/notification_service.dart';
import 'package:athan_call_to_success/db_helper.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    messenger.setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/android_alarm_manager'),
      (MethodCall methodCall) async {
        return true;
      },
    );

    messenger.setMockMethodCallHandler(
      const MethodChannel('flutter_timezone'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'getLocalTimezone') return 'UTC';
        return null;
      },
    );

    messenger.setMockMethodCallHandler(
      const MethodChannel('dexterous.com/flutter/local_notifications'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'initialize') return true;
        return null;
      },
    );

    messenger.setMockMethodCallHandler(
      const MethodChannel('com.example.googlecast'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'isConnected') return false;
        return null;
      },
    );

    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async {
        return '.';
      },
    );

    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/shared_preferences'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'getAll') return <String, dynamic>{};
        return null;
      },
    );
  });

  setUp(() async {
    // Start each test with an in-memory database to avoid "database is locked" errors
    databaseFactory = databaseFactoryFfi;
    sqfliteFfiInit();
    DBHelper.testDatabasePath = inMemoryDatabasePath;
  });

  tearDown(() {
    DBHelper.testDatabasePath = null;
  });

  group('NotificationService Diagnostic', () {
    test('NotificationService.instance can be initialized without WearService', () async {
      final ns = NotificationService.instance;
      await ns.initialize();
    });

    test('scheduleRollingPrayerNotifications completes without errors', () async {
      final ns = NotificationService.instance;
      await ns.initialize();
      
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      
      try {
        await ns.scheduleRollingPrayerNotifications(latitude: 40.7128, longitude: -74.0060);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  });
}
