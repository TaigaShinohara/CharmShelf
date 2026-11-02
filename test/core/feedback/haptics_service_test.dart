import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:private_shelf/core/feedback/haptics_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HapticsService', () {
    final log = <MethodCall>[];

    setUp(() {
      log.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (
            methodCall,
          ) async {
            log.add(methodCall);
            return null;
          });
      HapticsService.updateUserEnabled(true);
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
      HapticsService.updateUserEnabled(true);
    });

    test('isEnabled の初期値と updateUserEnabled による切り替え', () {
      HapticsService.updateUserEnabled(true);
      expect(HapticsService.isEnabled, isTrue);

      HapticsService.updateUserEnabled(false);
      expect(HapticsService.isEnabled, isFalse);

      HapticsService.updateUserEnabled(true);
      expect(HapticsService.isEnabled, isTrue);
    });

    test('有効（ON）のときプラットフォームのHapticFeedbackが呼び出される', () async {
      HapticsService.updateUserEnabled(true);

      await HapticsService.lightTap();
      expect(
        log.any(
          (call) =>
              call.method == 'HapticFeedback.vibrate' &&
              call.arguments == 'HapticFeedbackType.lightImpact',
        ),
        isTrue,
      );

      log.clear();
      await HapticsService.heavyTap();
      expect(
        log.any(
          (call) =>
              call.method == 'HapticFeedback.vibrate' &&
              call.arguments == 'HapticFeedbackType.heavyImpact',
        ),
        isTrue,
      );

      log.clear();
      await HapticsService.selection();
      expect(
        log.any(
          (call) =>
              call.method == 'HapticFeedback.vibrate' &&
              call.arguments == 'HapticFeedbackType.selectionClick',
        ),
        isTrue,
      );
    });

    test('無効（OFF）のときプラットフォームのHapticFeedbackが一切呼び出されない', () async {
      HapticsService.updateUserEnabled(false);

      await HapticsService.lightTap();
      await HapticsService.mediumTap();
      await HapticsService.heavyTap();
      await HapticsService.lightImpact();
      await HapticsService.mediumImpact();
      await HapticsService.heavyImpact();
      await HapticsService.selection();
      await HapticsService.selectionClick();
      await HapticsService.success();
      await HapticsService.error();

      expect(log, isEmpty);
    });
  });
}
