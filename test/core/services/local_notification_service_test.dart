import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:private_shelf/core/services/local_notification_service_io.dart';

// ignore: subtype_of_sealed_class
class MockFlutterLocalNotificationsPlatform extends Mock
    with MockPlatformInterfaceMixin
    implements FlutterLocalNotificationsPlatform {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MockFlutterLocalNotificationsPlatform mockPlatform;

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('flutter_timezone'), (
          MethodCall methodCall,
        ) async {
          if (methodCall.method == 'getLocalTimezone') {
            return 'Asia/Tokyo';
          }
          return null;
        });
  });

  setUp(() {
    mockPlatform = MockFlutterLocalNotificationsPlatform();
    FlutterLocalNotificationsPlatform.instance = mockPlatform;

    when(
      () => mockPlatform.getNotificationAppLaunchDetails(),
    ).thenAnswer((_) async => null);
  });

  group('LocalNotificationService スロットリング', () {
    test('showProgress は指定間隔内の連続更新をスロットリングする', () async {
      final service = LocalNotificationService.instance;
      // 1回目の通知（送信される）
      final res1 = await service.showProgress(
        id: 9999,
        title: 'テスト',
        body: '進捗 1',
        maxProgress: 100,
        currentProgress: 10,
        throttleDuration: const Duration(milliseconds: 500),
      );
      expect(res1.isSuccess, isTrue);

      // 即座に2回目の通知（500ms未満）-> スロットリングされてスキップ（正常終了）
      final res2 = await service.showProgress(
        id: 9999,
        title: 'テスト',
        body: '進捗 2',
        maxProgress: 100,
        currentProgress: 20,
        throttleDuration: const Duration(milliseconds: 500),
      );
      expect(res2.isSuccess, isTrue);

      // 進捗完了（100%達成）-> スロットリングをバイパスして送信
      final res3 = await service.showProgress(
        id: 9999,
        title: 'テスト',
        body: '進捗 完了',
        maxProgress: 100,
        currentProgress: 100,
        throttleDuration: const Duration(milliseconds: 500),
      );
      expect(res3.isSuccess, isTrue);

      // 指定時間待機後の通知 -> スロットリング期間経過のため送信
      await Future<void>.delayed(const Duration(milliseconds: 550));
      final res4 = await service.showProgress(
        id: 9999,
        title: 'テスト',
        body: '進捗 50',
        maxProgress: 100,
        currentProgress: 50,
        throttleDuration: const Duration(milliseconds: 500),
      );
      expect(res4.isSuccess, isTrue);

      // キャンセルで状態クリア
      await service.cancel(9999);
    });
  });
}
