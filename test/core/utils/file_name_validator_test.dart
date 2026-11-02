import 'package:flutter_test/flutter_test.dart';
import 'package:private_shelf/core/utils/file_name_validator.dart';

void main() {
  group('FileNameValidator', () {
    test('有効なファイル名を正しく検証できること', () {
      expect(FileNameValidator.isValid('sample.jpg'), isTrue);
      expect(FileNameValidator.isValid('日本語ファイル名.mp4'), isTrue);
      expect(FileNameValidator.isValid('document-2026_08.pdf'), isTrue);
      expect(FileNameValidator.isValid('Folder Name With Spaces'), isTrue);
      expect(FileNameValidator.isValid('.hidden_file'), isTrue);
    });

    test('空文字や空白のみは empty エラーになること', () {
      expect(FileNameValidator.validate(null), FileNameValidationError.empty);
      expect(FileNameValidator.validate(''), FileNameValidationError.empty);
      expect(FileNameValidator.validate('   '), FileNameValidationError.empty);
    });

    test('OS禁則文字が含まれる場合は invalidCharacters エラーになること', () {
      expect(
        FileNameValidator.validate('file/name.txt'),
        FileNameValidationError.invalidCharacters,
      );
      expect(
        FileNameValidator.validate(r'file\name.txt'),
        FileNameValidationError.invalidCharacters,
      );
      expect(
        FileNameValidator.validate('file:name.txt'),
        FileNameValidationError.invalidCharacters,
      );
      expect(
        FileNameValidator.validate('file*name.txt'),
        FileNameValidationError.invalidCharacters,
      );
      expect(
        FileNameValidator.validate('file?name.txt'),
        FileNameValidationError.invalidCharacters,
      );
      expect(
        FileNameValidator.validate('file"name.txt'),
        FileNameValidationError.invalidCharacters,
      );
      expect(
        FileNameValidator.validate('file<name.txt'),
        FileNameValidationError.invalidCharacters,
      );
      expect(
        FileNameValidator.validate('file>name.txt'),
        FileNameValidationError.invalidCharacters,
      );
      expect(
        FileNameValidator.validate('file|name.txt'),
        FileNameValidationError.invalidCharacters,
      );
    });

    test('システム予約名は reservedName エラーになること', () {
      expect(
        FileNameValidator.validate('.'),
        FileNameValidationError.reservedName,
      );
      expect(
        FileNameValidator.validate('..'),
        FileNameValidationError.reservedName,
      );
      expect(
        FileNameValidator.validate('CON'),
        FileNameValidationError.reservedName,
      );
      expect(
        FileNameValidator.validate('nul.txt'),
        FileNameValidationError.reservedName,
      );
      expect(
        FileNameValidator.validate('AUX'),
        FileNameValidationError.reservedName,
      );
    });

    test('255文字を超える場合は tooLong エラーになること', () {
      final longName = '${'a' * 256}.txt';
      expect(
        FileNameValidator.validate(longName),
        FileNameValidationError.tooLong,
      );

      final validLongName = '${'a' * 251}.txt'; // 255文字
      expect(FileNameValidator.validate(validLongName), isNull);
    });
  });
}
