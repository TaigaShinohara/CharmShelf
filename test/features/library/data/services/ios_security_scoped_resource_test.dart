import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:private_shelf/features/library/data/services/ios_security_scoped_resource.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late IosSecurityScopedResource resource;
  final log = <MethodCall>[];

  setUp(() {
    resource = IosSecurityScopedResource();
    log.clear();

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel(
            'com.example.private_shelf/security_scoped_resource',
          ),
          (MethodCall methodCall) async {
            log.add(methodCall);
            switch (methodCall.method) {
              case 'createBookmark':
                final path = methodCall.arguments['path'] as String;
                if (path == '/invalid/path') return null;
                if (path == '/error/path') {
                  throw PlatformException(code: 'ERROR');
                }
                return 'bookmark_data_for_$path';
              case 'resolveBookmark':
                final bookmark = methodCall.arguments['bookmark'] as String;
                if (bookmark == 'invalid_bookmark') return null;
                if (bookmark == 'error_bookmark') {
                  throw PlatformException(code: 'RESOLVE_FAILED');
                }
                return '/resolved/path';
              case 'stopAccessing':
                final path = methodCall.arguments['path'] as String;
                if (path == '/error/stop') {
                  throw PlatformException(code: 'STOP_FAILED');
                }
                return true;
              case 'stopAllAccessing':
                return true;
              default:
                return null;
            }
          },
        );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel(
            'com.example.private_shelf/security_scoped_resource',
          ),
          null,
        );
  });

  group('IosSecurityScopedResource Tests', () {
    test('Bookmark境界の失敗ログにパス・例外本文・detailsを含めない', () async {
      const sentinel = '/private/sensitive-media-fixture.jpg';
      final messages = <String>[];
      final previousDebugPrint = debugPrint;
      debugPrint = (String? message, {int? wrapWidth}) {
        if (message != null) messages.add(message);
      };
      addTearDown(() => debugPrint = previousDebugPrint);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel(
              'com.example.private_shelf/security_scoped_resource',
            ),
            (_) async => throw PlatformException(
              code: 'TEST_ERROR',
              message: sentinel,
              details: {'path': sentinel},
            ),
          );
      expect(await resource.createBookmark(sentinel), isNull);
      expect(await resource.resolveBookmark(sentinel), isNull);
      await resource.stopAccessing(sentinel);
      await resource.stopAllAccessing();
      expect(messages.length, 4);
      expect(messages.join().contains(sentinel), isFalse);
      expect(messages.join().contains('TEST_ERROR'), isFalse);
    });

    test('厳密な解放はnativeのfalseを成功扱いしない', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel(
              'com.example.private_shelf/security_scoped_resource',
            ),
            (_) async => false,
          );
      await expectLater(
        resource.stopAccessingStrict('/test/resource'),
        throwsA(
          isA<PlatformException>().having(
            (e) => e.code,
            'code',
            'STOP_ACCESS_FAILED',
          ),
        ),
      );
    });

    test('全件の厳密な解放はnativeのfalseを成功扱いしない', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel(
              'com.example.private_shelf/security_scoped_resource',
            ),
            (_) async => false,
          );
      await expectLater(
        resource.stopAllAccessingStrict(),
        throwsA(
          isA<PlatformException>().having(
            (e) => e.code,
            'code',
            'STOP_ALL_ACCESS_FAILED',
          ),
        ),
      );
    });

    test('createBookmark: 正常系でBase64 Bookmarkデータを返す', () async {
      final result = await resource.createBookmark('/valid/dir');
      expect(result, 'bookmark_data_for_/valid/dir');
      expect(log.single.method, 'createBookmark');
      expect(log.single.arguments, {'path': '/valid/dir'});
    });

    test('createBookmark: 無効パス時はnullを返す', () async {
      final result = await resource.createBookmark('/invalid/path');
      expect(result, isNull);
    });

    test('createBookmark: プラットフォーム例外発生時にクラッシュせずnullを返す', () async {
      final result = await resource.createBookmark('/error/path');
      expect(result, isNull);
    });

    test('resolveBookmark: 正常系で解決されたパスを返す', () async {
      final result = await resource.resolveBookmark('valid_bookmark');
      expect(result, '/resolved/path');
      expect(log.single.method, 'resolveBookmark');
      expect(log.single.arguments, {'bookmark': 'valid_bookmark'});
    });

    test('resolveBookmark: 無効ブックマーク時はnullを返す', () async {
      final result = await resource.resolveBookmark('invalid_bookmark');
      expect(result, isNull);
    });

    test('resolveBookmark: プラットフォーム例外発生時にクラッシュせずnullを返す', () async {
      final result = await resource.resolveBookmark('error_bookmark');
      expect(result, isNull);
    });

    test('stopAccessing: 正常系でアクセス権解放MethodCallを送信する', () async {
      await resource.stopAccessing('/valid/dir');
      expect(log.single.method, 'stopAccessing');
      expect(log.single.arguments, {'path': '/valid/dir'});
    });

    test('stopAccessing: プラットフォーム例外発生時もクラッシュせず安全に完了する', () async {
      await expectLater(resource.stopAccessing('/error/stop'), completes);
    });

    test('stopAllAccessing: すべてのアクセス権解放MethodCallを送信する', () async {
      await resource.stopAllAccessing();
      expect(log.single.method, 'stopAllAccessing');
      expect(log.single.arguments, isNull);
    });
  });
}
