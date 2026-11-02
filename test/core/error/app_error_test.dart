import 'package:flutter_test/flutter_test.dart';
import 'package:private_shelf/core/error/app_error.dart';

void main() {
  group('AppError', () {
    test('基本的なコンストラクタでエラーを作成できる', () {
      const error = AppError(
        message: 'Test error',
        category: ErrorCategory.unknown,
        severity: ErrorSeverity.warning,
      );

      expect(error.message, 'Test error');
      expect(error.category, ErrorCategory.unknown);
      expect(error.severity, ErrorSeverity.warning);
      expect(error.originalError, isNull);
      expect(error.stackTrace, isNull);
    });

    test('originalErrorとstackTraceを含むエラーを作成できる', () {
      final originalException = Exception('Original');
      final stack = StackTrace.current;

      final error = AppError(
        message: 'Wrapped error',
        category: ErrorCategory.database,
        severity: ErrorSeverity.critical,
        originalError: originalException,
        stackTrace: stack,
      );

      expect(error.originalError, originalException);
      expect(error.stackTrace, stack);
    });
  });

  group('AppError.network', () {
    test('ネットワークエラーを作成できる', () {
      final error = AppError.network('Connection failed');

      expect(error.message, 'Connection failed');
      expect(error.category, ErrorCategory.network);
      expect(error.severity, ErrorSeverity.warning);
    });

    test('重大度をカスタマイズできる', () {
      final error = AppError.network(
        'Critical network failure',
        severity: ErrorSeverity.critical,
      );

      expect(error.severity, ErrorSeverity.critical);
    });
  });

  group('AppError.database', () {
    test('データベースエラーを作成できる', () {
      final error = AppError.database('Query failed');

      expect(error.message, 'Query failed');
      expect(error.category, ErrorCategory.database);
      expect(error.severity, ErrorSeverity.warning);
    });

    test('元の例外を含めることができる', () {
      final original = Exception('DB connection lost');
      final error = AppError.database('Database error', original: original);

      expect(error.originalError, original);
    });
  });

  group('AppError.auth', () {
    test('認証エラーを作成できる', () {
      final error = AppError.auth('Invalid credentials');

      expect(error.message, 'Invalid credentials');
      expect(error.category, ErrorCategory.auth);
      expect(error.severity, ErrorSeverity.warning);
    });
  });

  group('AppError.validation', () {
    test('バリデーションエラーを作成できる', () {
      final error = AppError.validation('Field is required');

      expect(error.message, 'Field is required');
      expect(error.category, ErrorCategory.validation);
      expect(error.severity, ErrorSeverity.info);
    });
  });

  group('AppError.unknown', () {
    test('不明なエラーを作成できる', () {
      final error = AppError.unknown('Something went wrong');

      expect(error.message, 'Something went wrong');
      expect(error.category, ErrorCategory.unknown);
      expect(error.severity, ErrorSeverity.critical);
    });

    test('重大度をカスタマイズできる', () {
      final error = AppError.unknown(
        'Minor unknown issue',
        severity: ErrorSeverity.info,
      );

      expect(error.severity, ErrorSeverity.info);
    });
  });

  group('ErrorSeverity', () {
    test('3つの重大度レベルがある', () {
      expect(ErrorSeverity.values.length, 3);
      expect(ErrorSeverity.values, contains(ErrorSeverity.critical));
      expect(ErrorSeverity.values, contains(ErrorSeverity.warning));
      expect(ErrorSeverity.values, contains(ErrorSeverity.info));
    });
  });

  group('ErrorCategory', () {
    test('9つのカテゴリがある', () {
      expect(ErrorCategory.values.length, 9);
      expect(ErrorCategory.values, contains(ErrorCategory.network));
      expect(ErrorCategory.values, contains(ErrorCategory.database));
      expect(ErrorCategory.values, contains(ErrorCategory.auth));
      expect(ErrorCategory.values, contains(ErrorCategory.validation));
      expect(ErrorCategory.values, contains(ErrorCategory.file));
      expect(ErrorCategory.values, contains(ErrorCategory.permission));
      expect(ErrorCategory.values, contains(ErrorCategory.system));
      expect(ErrorCategory.values, contains(ErrorCategory.ui));
      expect(ErrorCategory.values, contains(ErrorCategory.unknown));
    });
  });
}
