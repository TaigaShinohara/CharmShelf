import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:private_shelf/core/services/clipboard_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;
  late ClipboardService service;
  String? clipboardContent;

  setUp(() {
    clipboardContent = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (methodCall) async {
          if (methodCall.method == 'Clipboard.setData') {
            final args = methodCall.arguments as Map<dynamic, dynamic>?;
            clipboardContent = args?['text'] as String?;
            return null;
          }
          if (methodCall.method == 'Clipboard.getData') {
            if (clipboardContent != null) {
              return <String, dynamic>{'text': clipboardContent};
            }
            return null;
          }
          if (methodCall.method == 'HapticFeedback.vibrate') {
            return null;
          }
          return null;
        });

    container = ProviderContainer();
    service = container.read(clipboardServiceProvider);
  });

  tearDown(() {
    container.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  group('ClipboardService', () {
    test('空文字のコピーはバリデーションエラーとなる', () async {
      final result = await service.copyText('', triggerHaptics: false);
      expect(result.isFailure, isTrue);
      expect(clipboardContent, isNull);
    });

    test('有効な文字列をクリップボードに正常にコピーできる', () async {
      final result = await service.copyText(
        'Hello World',
        triggerHaptics: false,
      );
      expect(result.isSuccess, isTrue);
      expect(clipboardContent, equals('Hello World'));

      final getResult = await service.getText();
      expect(getResult.isSuccess, isTrue);
      expect(getResult.dataOrNull, equals('Hello World'));
    });
  });
}
