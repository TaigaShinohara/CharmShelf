import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:private_shelf/core/services/local_notification_service_io.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'timezone failure can retry and DST schedules preserve their instants',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      FlutterLocalNotificationsPlatform.instance =
          AndroidFlutterLocalNotificationsPlugin();
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final calls = <MethodCall>[];
      var timezoneRequests = 0;
      messenger.setMockMethodCallHandler(
        const MethodChannel('flutter_timezone'),
        (call) async {
          timezoneRequests++;
          if (timezoneRequests == 1) {
            throw PlatformException(code: 'temporarily_unavailable');
          }
          return {'identifier': 'America/New_York'};
        },
      );
      messenger.setMockMethodCallHandler(
        const MethodChannel('dexterous.com/flutter/local_notifications'),
        (call) async {
          calls.add(call);
          if (call.method == 'initialize') return true;
          if (call.method == 'getNotificationAppLaunchDetails') {
            return {'notificationLaunchedApp': false};
          }
          return null;
        },
      );
      addTearDown(() {
        messenger.setMockMethodCallHandler(
          const MethodChannel('flutter_timezone'),
          null,
        );
        messenger.setMockMethodCallHandler(
          const MethodChannel('dexterous.com/flutter/local_notifications'),
          null,
        );
      });

      final service = LocalNotificationService.instance;
      Future<bool> schedule(int id, DateTime time) async =>
          (await service.scheduleAt(
            id: id,
            title: 'Synthetic reminder',
            body: 'DST regression',
            scheduledTime: time,
            payload: '/synthetic',
          )).isSuccess;

      final beforeJump = DateTime.utc(2027, 3, 14, 6, 30);
      final afterJump = DateTime.utc(2027, 3, 14, 7, 30);
      expect(await schedule(9101, beforeJump), isFalse);
      expect(calls.where((c) => c.method == 'zonedSchedule'), isEmpty);
      expect(await schedule(9101, beforeJump), isTrue);
      expect(await schedule(9102, afterJump), isTrue);
      expect(timezoneRequests, 2);
      final scheduled = calls
          .where((c) => c.method == 'zonedSchedule')
          .toList();
      expect(scheduled, hasLength(2));
      for (final (index, expected) in [beforeJump, afterJump].indexed) {
        final args = scheduled[index].arguments as Map;
        expect(args['timeZoneName'], 'America/New_York');
        expect(
          DateTime.parse(args['scheduledDateTimeISO8601'] as String).toUtc(),
          expected,
        );
        expect(
          args['scheduledDateTime'],
          index == 0 ? '2027-03-14T01:30:00' : '2027-03-14T03:30:00',
        );
        expect(args['payload'], '/synthetic');
      }
    },
  );
}
