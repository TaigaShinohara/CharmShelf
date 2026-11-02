import 'package:private_shelf/gen_l10n/app_localizations.dart';

/// ファイル名・ディレクトリ名の検証エラー種別
enum FileNameValidationError {
  /// 未入力または空白のみ
  empty,

  /// 使用不可文字（\ / : * ? " < > | 制御文字）が含まれる
  invalidCharacters,

  /// 最大文字数（255文字）を超過
  tooLong,

  /// システム予約名（CON, PRN, AUX, NUL, ., .. 等）
  reservedName,

  /// 先頭または末尾に不正な空白・ピリオドが存在
  invalidBoundary,
}

/// ファイルシステムにおけるファイル名・ディレクトリ名の安全性検証ユーティリティ
class FileNameValidator {
  FileNameValidator._();

  /// ファイル名の最大文字数 (バイト制限ではなくUTF-16長基準)
  static const int maxFileNameLength = 255;

  /// OSで使用不可能な文字の正規表現
  /// \ / : * ? " < > | および 0x00〜0x1F の制御文字
  static final RegExp _invalidCharsRegex = RegExp(r'[\/\\:*?"<>|\x00-\x1F]');

  /// Windows等のシステム予約名
  static const Set<String> _reservedNames = {
    '.',
    '..',
    'CON',
    'PRN',
    'AUX',
    'NUL',
    'COM1',
    'COM2',
    'COM3',
    'COM4',
    'COM5',
    'COM6',
    'COM7',
    'COM8',
    'COM9',
    'LPT1',
    'LPT2',
    'LPT3',
    'LPT4',
    'LPT5',
    'LPT6',
    'LPT7',
    'LPT8',
    'LPT9',
  };

  /// ファイル名・ディレクトリ名の安全性を検証する
  ///
  /// 問題がない場合は `null` を返し、問題がある場合は該当する [FileNameValidationError] を返す。
  static FileNameValidationError? validate(String? name) {
    if (name == null || name.trim().isEmpty) {
      return FileNameValidationError.empty;
    }

    final trimmed = name.trim();

    if (trimmed.length > maxFileNameLength) {
      return FileNameValidationError.tooLong;
    }

    if (_invalidCharsRegex.hasMatch(name)) {
      return FileNameValidationError.invalidCharacters;
    }

    // 先頭または末尾の不正なピリオド/スペースチェック（.で始まる隠しファイル以外でピリオドのみ等）
    if (trimmed == '.' || trimmed == '..') {
      return FileNameValidationError.reservedName;
    }

    // Windows予約名（拡張子を除いたベース名での大文字小文字無視比較）
    final baseWithoutExt = trimmed.contains('.')
        ? trimmed.substring(0, trimmed.indexOf('.'))
        : trimmed;
    if (_reservedNames.contains(baseWithoutExt.toUpperCase())) {
      return FileNameValidationError.reservedName;
    }

    return null;
  }

  /// ファイル名・ディレクトリ名が安全かどうかを判定する
  static bool isValid(String? name) => validate(name) == null;

  /// ローカライズされたエラーメッセージを取得する（UIバリデーション用）
  static String? validateWithL10n(String? name, AppLocalizations l10n) {
    final error = validate(name);
    if (error == null) return null;

    switch (error) {
      case FileNameValidationError.empty:
        return l10n.validationFileNameEmpty;
      case FileNameValidationError.invalidCharacters:
      case FileNameValidationError.invalidBoundary:
        return l10n.validationFileNameInvalidChars;
      case FileNameValidationError.tooLong:
        return l10n.validationFileNameTooLong;
      case FileNameValidationError.reservedName:
        return l10n.validationFileNameReserved;
    }
  }
}
