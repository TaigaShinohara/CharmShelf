import 'package:flutter_test/flutter_test.dart';
import 'package:private_shelf/core/logger/app_logger.dart';
import 'package:private_shelf/core/logger/log_level.dart';
import 'package:private_shelf/core/logger/log_tag.dart';

void main() {
  group('AppLogger', () {
    setUp(() {
      // テスト用に最低レベルをverboseに設定
      AppLogger.setMinLevel(LogLevel.verbose);
    });

    test('setMinLevelで最小ログレベルを変更できる', () {
      AppLogger.setMinLevel(LogLevel.warning);
      expect(AppLogger.minLevel, LogLevel.warning);

      AppLogger.setMinLevel(LogLevel.verbose);
      expect(AppLogger.minLevel, LogLevel.verbose);
    });

    test('各ログレベルのメソッドが例外を投げずに実行される', () {
      // エラーが発生しないことを確認
      expect(() => AppLogger.v(LogTag.app, 'Verbose message'), returnsNormally);
      expect(() => AppLogger.d(LogTag.app, 'Debug message'), returnsNormally);
      expect(() => AppLogger.i(LogTag.app, 'Info message'), returnsNormally);
      expect(() => AppLogger.w(LogTag.app, 'Warning message'), returnsNormally);
      expect(() => AppLogger.e(LogTag.app, 'Error message'), returnsNormally);
    });

    test('エラーとスタックトレース付きでログを出力できる', () {
      expect(
        () => AppLogger.e(
          LogTag.db,
          'Database error',
          Exception('Test exception'),
          StackTrace.current,
        ),
        returnsNormally,
      );
    });

    test('separatorが例外を投げずに実行される', () {
      expect(() => AppLogger.separator(), returnsNormally);
      expect(() => AppLogger.separator('Label'), returnsNormally);
    });

    test('jsonメソッドが例外を投げずに実行される', () {
      expect(
        () => AppLogger.json(LogTag.app, 'Test data', {'key': 'value'}),
        returnsNormally,
      );
    });

    test('startTimerとendTimerでパフォーマンス計測ができる', () {
      final stopwatch = AppLogger.startTimer(
        LogTag.lifecycle,
        'Test operation',
      );

      expect(stopwatch.isRunning, true);

      // 少し待機
      Future.delayed(const Duration(milliseconds: 10));

      expect(
        () => AppLogger.endTimer(LogTag.lifecycle, 'Test operation', stopwatch),
        returnsNormally,
      );

      expect(stopwatch.isRunning, false);
    });

    test('最小レベル未満のログは出力されない（内部的に）', () {
      AppLogger.setMinLevel(LogLevel.error);

      // これらは最小レベル未満なので出力されないが、エラーにはならない
      expect(
        () => AppLogger.v(LogTag.app, 'Should not print'),
        returnsNormally,
      );
      expect(
        () => AppLogger.d(LogTag.app, 'Should not print'),
        returnsNormally,
      );
      expect(
        () => AppLogger.i(LogTag.app, 'Should not print'),
        returnsNormally,
      );
      expect(
        () => AppLogger.w(LogTag.app, 'Should not print'),
        returnsNormally,
      );

      // エラーレベルは出力される
      expect(() => AppLogger.e(LogTag.app, 'Should print'), returnsNormally);

      // リセット
      AppLogger.setMinLevel(LogLevel.verbose);
    });
  });

  group('LogLevel', () {
    test('5つのログレベルがある', () {
      expect(LogLevel.values.length, 5);
    });

    test('ログレベルに適切な優先度が設定されている', () {
      expect(LogLevel.verbose.priority, lessThan(LogLevel.debug.priority));
      expect(LogLevel.debug.priority, lessThan(LogLevel.info.priority));
      expect(LogLevel.info.priority, lessThan(LogLevel.warning.priority));
      expect(LogLevel.warning.priority, lessThan(LogLevel.error.priority));
    });

    test('各レベルにアイコンが設定されている', () {
      for (final level in LogLevel.values) {
        expect(level.icon, isNotEmpty);
      }
    });
  });

  group('LogTag', () {
    test('ログタグが定義されている', () {
      expect(LogTag.values, isNotEmpty);
    });

    test('主要なタグが存在する', () {
      expect(LogTag.values, contains(LogTag.app));
      expect(LogTag.values, contains(LogTag.db));
      expect(LogTag.values, contains(LogTag.lifecycle));
    });
  });
}
