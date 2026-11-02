import 'dart:io';

final _sourceExtensions = <String>{'.dart', '.yaml', '.yml', '.arb'};
final _excludedSegments = <String>{
  '.dart_tool',
  '.git',
  'build',
  'gen_l10n',
  'debug',
};
final _excludedFiles = <String>{
  'lib/core/logger/app_logger.dart',
  'scripts/maintenance/check_audit_patterns.dart',
};

final _rules = <({RegExp pattern, String message, bool includeTests})>[
  (
    pattern: RegExp(r'(^|[^A-Za-z])print\s*\('),
    message: 'print() ではなく AppLogger を使用してください',
    includeTests: true,
  ),
  (
    pattern: RegExp(r'debugPrint\s*\('),
    message: 'debugPrint() ではなく AppLogger を使用してください',
    includeTests: true,
  ),
  (
    pattern: RegExp(
      r'''(api[_-]?key|secret|password)\s*[:=]\s*['\"][^'\"]{8,}['\"]''',
      caseSensitive: false,
    ),
    message: '機密情報らしきリテラルが含まれています',
    includeTests: false,
  ),
  (
    pattern: RegExp(r'AESMode\.ecb'),
    message: '認証されないAES-ECBは使用できません',
    includeTests: true,
  ),
  (
    pattern: RegExp(r'(?<![A-Za-z])Random\(\)'),
    message: 'セキュリティ用途ではRandom.secure()を使用してください',
    includeTests: false,
  ),
  (
    pattern: RegExp(r'delete\s*\(\s*recursive\s*:\s*true'),
    message: '再帰削除は監査済み境界へ集約し、明示的に許可してください',
    includeTests: false,
  ),
];

final _wholeFileRules =
    <({RegExp pattern, String message, String allowTag, bool includeTests})>[
      (
        pattern: RegExp(r'delete\s*\(\s*recursive\s*:\s*true', multiLine: true),
        message: '改行を含む再帰削除は監査済み境界へ集約してください',
        allowTag: 'audit: allow-file-io',
        includeTests: false,
      ),
    ];

final _requiredFilePatterns = <({String path, RegExp pattern, String message})>[
  (
    path: 'android/app/src/main/AndroidManifest.xml',
    pattern: RegExp(r'android:allowBackup\s*=\s*"false"'),
    message: 'Androidの自動バックアップを無効化してください',
  ),
  (
    path: 'android/app/src/main/AndroidManifest.xml',
    pattern: RegExp(r'android:fullBackupContent\s*=\s*"@xml/backup_rules"'),
    message: 'Android 11以前のバックアップ除外規則を接続してください',
  ),
  (
    path: 'android/app/src/main/AndroidManifest.xml',
    pattern: RegExp(
      r'android:dataExtractionRules\s*=\s*"@xml/data_extraction_rules"',
    ),
    message: 'Android 12以降のデータ抽出除外規則を接続してください',
  ),
  for (final domain in ['root', 'file', 'database', 'sharedpref', 'external'])
    (
      path: 'android/app/src/main/res/xml/backup_rules.xml',
      pattern: RegExp('<exclude domain="$domain" path="\\."\\s*/>'),
      message: 'Androidバックアップから$domain領域を除外してください',
    ),
  (
    path: 'android/app/src/main/res/xml/data_extraction_rules.xml',
    pattern: RegExp(r'<cloud-backup>'),
    message: 'Androidクラウドバックアップ除外規則が必要です',
  ),
  (
    path: 'android/app/src/main/res/xml/data_extraction_rules.xml',
    pattern: RegExp(r'<device-transfer>'),
    message: 'Android端末間転送の除外規則が必要です',
  ),
  (
    path: 'android/app/build.gradle.kts',
    pattern: RegExp(r'environmentVariable\("ALLOW_DEBUG_RELEASE_SIGNING"\)'),
    message: 'debug鍵によるreleaseビルドは明示的なローカル許可に限定してください',
  ),
  (
    path: 'android/app/build.gradle.kts',
    pattern: RegExp(r'"ANDROID_KEYSTORE_PATH"'),
    message: '秘密値をファイルへ固定せず環境変数から正式署名できる経路を維持してください',
  ),
  (
    path: 'android/app/build.gradle.kts',
    pattern: RegExp(r'else if\s*\(allowDebugReleaseSigning\)'),
    message: 'debug release署名を明示的な許可条件で囲んでください',
  ),
  (
    path: 'android/app/build.gradle.kts',
    pattern: RegExp(r'else if\s*\(releaseBuildRequested\)'),
    message: '正式鍵がないreleaseタスクを拒否してください',
  ),
  (
    path: 'ios/Runner/AppDelegate.swift',
    pattern: RegExp(r'case "setExcludedFromBackup"'),
    message: 'iOS私有領域のバックアップ除外チャネルが必要です',
  ),
  (
    path: 'ios/Runner/AppDelegate.swift',
    pattern: RegExp(r'requestedURL\.path\.hasPrefix\(containerPath\)'),
    message: 'iOSバックアップ除外対象をアプリコンテナ内に制限してください',
  ),
  (
    path: 'ios/Runner/AppDelegate.swift',
    pattern: RegExp(r'values\.isExcludedFromBackup\s*=\s*true'),
    message: 'iOS私有領域へバックアップ除外属性を設定してください',
  ),
  for (final trigger in ['push', 'pull_request', 'workflow_dispatch'])
    (
      path: '.github/workflows/ci.yml',
      pattern: RegExp('^\\s*$trigger\\s*:', multiLine: true),
      message: '公開CIの$trigger入口を維持してください',
    ),
  (
    path: '.github/workflows/ci.yml',
    pattern: RegExp(r'flutter build apk --debug'),
    message: '公開CIは署名情報が不要なDebug APKを検証してください',
  ),
  (
    path: 'fastlane/Fastfile',
    pattern: RegExp(r'jarsigner -verify #\{aab_path\}'),
    message: 'Android配布前にAAB署名を検証してください',
  ),
  (
    path: 'fastlane/Fastfile',
    pattern: RegExp(r'certificate\.include\?\("Android Debug"\)'),
    message: 'Android Debug証明書の配布を拒否してください',
  ),
  (
    path: 'fastlane/Fastfile',
    pattern: RegExp(r'android/upload_certificate\.sha256'),
    message: 'AAB署名証明書を承認済みupload証明書と照合してください',
  ),
  (
    path: 'fastlane/Fastfile',
    pattern: RegExp(r'Tempfile\.new'),
    message: 'Google Play資格情報はOS一時ファイルとして作成してください',
  ),
  (
    path: 'fastlane/Fastfile',
    pattern: RegExp(r'chmod\(0o600\)'),
    message: 'Google Play資格情報の一時ファイルを0600へ制限してください',
  ),
  (
    path: 'android/upload_certificate.sha256',
    pattern: RegExp(
      r'^(?:YOUR_UPLOAD_CERTIFICATE_SHA256|(?:[0-9A-F]{2}:){31}[0-9A-F]{2})\s*$',
      multiLine: true,
    ),
    message: '公開用placeholderまたは自身のupload証明書SHA-256指紋を保存してください',
  ),
  (
    path: 'scripts/build_signed_android_release.zsh',
    pattern: RegExp(r'android/upload_certificate\.sha256'),
    message: 'ローカル正式AABも承認済みupload証明書と照合してください',
  ),
  (
    path: 'scripts/build_signed_android_release.zsh',
    pattern: RegExp(r'python3 scripts/check_distribution_config\.py android'),
    message: '未設定のAndroid配布は署名やビルドの前に停止してください',
  ),
  (
    path: 'scripts/build_ios_release_candidate.zsh',
    pattern: RegExp(r'python3 scripts/check_distribution_config\.py ios'),
    message: '未設定のiOS exportは署名やビルドの前に停止してください',
  ),
];

final _forbiddenFilePatterns =
    <({String path, RegExp pattern, String message})>[
      (
        path: 'ios/Runner/AppDelegate.swift',
        pattern: RegExp(r'\b(?:print|debugPrint|NSLog)\s*\('),
        message: 'iOSネイティブ境界で私有URLを無保護のログへ出力しないでください',
      ),
      (
        path: 'fastlane/Fastfile',
        pattern: RegExp(r'Dir\.pwd.*google_play_service_account\.json'),
        message: 'Google Play資格情報をリポジトリ内へ作成しないでください',
      ),
      (
        path: 'ios/Runner/Info.plist',
        pattern: RegExp(r'NSUbiquitousContainers'),
        message: 'iCloudコンテナを暗黙に有効化しないでください',
      ),
      (
        path: '.github/workflows/ci.yml',
        pattern: RegExp(r'^\s*pull_request_target\s*:', multiLine: true),
        message: '公開CIはpull_request_targetで未信頼コードを実行しないでください',
      ),
      (
        path: '.github/workflows/ci.yml',
        pattern: RegExp(r'\bsecrets\.'),
        message: '公開Debug CIへ配布資格情報を渡さないでください',
      ),
      (
        path: '.github/workflows/ci.yml',
        pattern: RegExp(r'flutter build (?:apk|appbundle|ios|ipa) --release'),
        message: '公開Debug CIでrelease成果物を生成しないでください',
      ),
      (
        path: 'fastlane/Fastfile',
        pattern: RegExp(r'jarsigner -verify -strict'),
        message: '自己署名upload証明書を誤拒否する-strictを使用しないでください',
      ),
    ];

Future<void> main() async {
  final roots = ['lib', 'scripts'];
  final violations = <String>[];

  for (final root in roots) {
    final type = FileSystemEntity.typeSync(root);
    if (type == FileSystemEntityType.notFound) continue;
    final entities = type == FileSystemEntityType.directory
        ? Directory(root).list(recursive: true, followLinks: false)
        : Stream<FileSystemEntity>.value(File(root));
    await for (final entity in entities) {
      if (entity is! File || !_shouldAudit(entity.path)) continue;
      final lines = await entity.readAsLines();
      final content = lines.join('\n');
      if (_normalPath(entity.path) == 'lib/app/app.dart' &&
          content.contains('TextScaleWrapper(')) {
        violations.add('${entity.path}: アプリ全体でOSの文字サイズを上書きしないでください');
      }
      if (_normalPath(entity.path) ==
              'lib/features/settings/presentation/settings_page.dart' &&
          !content.contains('content: l10n.privacyPolicyCurrentContent,')) {
        violations.add('${entity.path}: 事実確認済みの現行プライバシーポリシーを表示してください');
      }
      if (_isUserInterfaceDart(entity.path)) {
        for (final lineNumber in _iconButtonsWithoutTooltip(content)) {
          violations.add(
            '${entity.path}:$lineNumber: IconButtonにはローカライズされたtooltipを指定してください',
          );
        }
        for (final lineNumber in _iconButtonsWithLiteralTooltip(content)) {
          violations.add(
            '${entity.path}:$lineNumber: IconButtonのtooltipはARBまたはMaterialLocalizationsから取得してください',
          );
        }
        for (final lineNumber in _iconButtonsWithSmallTapTarget(content)) {
          violations.add(
            '${entity.path}:$lineNumber: IconButtonのタップ領域は48×48dp以上にしてください',
          );
        }
        for (final lineNumber in _popupMenusWithoutTooltip(content)) {
          violations.add(
            '${entity.path}:$lineNumber: PopupMenuButtonには用途を示すtooltipを指定してください',
          );
        }
        for (final lineNumber in _floatingButtonsWithoutTooltip(content)) {
          violations.add(
            '${entity.path}:$lineNumber: FloatingActionButtonには用途を示すtooltipを指定してください',
          );
        }
      }
      for (final rule in _wholeFileRules) {
        if (!rule.includeTests && entity.path.startsWith('test/')) continue;
        if (rule.pattern.hasMatch(content) &&
            !content.contains(rule.allowTag)) {
          violations.add('${entity.path}: ${rule.message}');
        }
      }
      for (var index = 0; index < lines.length; index++) {
        final line = lines[index];
        final trimmed = line.trimLeft();
        if (trimmed.startsWith('//') || line.contains('audit: allow')) continue;
        if (_containsUnsupportedPrivacyGuarantee(line)) {
          violations.add('${entity.path}:${index + 1}: 保証不能なプライバシー断定が含まれています');
        }
        if (_isUserInterfaceDart(entity.path) &&
            _containsHardcodedJapaneseUiLiteral(line)) {
          violations.add('${entity.path}:${index + 1}: ユーザー向け日本語をARBへ移してください');
        }
        for (final rule in _rules) {
          if (!rule.includeTests && entity.path.startsWith('test/')) continue;
          if (rule.pattern.hasMatch(line)) {
            violations.add('${entity.path}:${index + 1}: ${rule.message}');
          }
        }
      }
    }
  }

  for (final rule in _requiredFilePatterns) {
    final file = File(rule.path);
    if (!await file.exists()) {
      violations.add('${rule.path}: 必須ファイルがありません: ${rule.message}');
      continue;
    }
    final content = await file.readAsString();
    if (!rule.pattern.hasMatch(content)) {
      violations.add('${rule.path}: ${rule.message}');
    }
  }
  for (final rule in _forbiddenFilePatterns) {
    final file = File(rule.path);
    if (!await file.exists()) continue;
    final content = await file.readAsString();
    if (rule.pattern.hasMatch(content)) {
      // 特定の違反のみを許容するタグがあるか確認
      final allowTag =
          'audit: allow-${rule.message.hashCode.toRadixString(16)}';
      if (!content.contains(allowTag)) {
        violations.add(
          '${rule.path}: ${rule.message} (To allow, add "$allowTag")',
        );
      }
    }
  }

  await _auditWorkflowSecurity(violations);

  if (violations.isNotEmpty) {
    stderr.writeln('監査違反を検出しました:');
    for (final violation in violations) {
      stderr.writeln('  $violation');
    }
    exitCode = 1;
    return;
  }
  stdout.writeln('監査パターンチェック: OK'); // audit: allow
}

Future<void> _auditWorkflowSecurity(List<String> violations) async {
  final workflowDirectory = Directory('.github/workflows');
  if (!await workflowDirectory.exists()) return;

  await for (final entity in workflowDirectory.list(followLinks: false)) {
    if (entity is! File ||
        !(entity.path.endsWith('.yml') || entity.path.endsWith('.yaml'))) {
      continue;
    }
    final content = await entity.readAsString();
    if (!RegExp(
      r'^permissions:\s*\n\s{2}contents:\s*read\s*$',
      multiLine: true,
    ).hasMatch(content)) {
      violations.add('${entity.path}: workflow権限をcontents: readに制限してください');
    }

    final actionUses = RegExp(
      r'^\s*(?:-\s*)?uses:\s*([^\s#]+)',
      multiLine: true,
    ).allMatches(content);
    for (final match in actionUses) {
      final reference = match.group(1)!;
      if (reference.startsWith('./')) continue;
      final separator = reference.lastIndexOf('@');
      final revision = separator < 0 ? '' : reference.substring(separator + 1);
      if (!RegExp(r'^[0-9a-f]{40}$').hasMatch(revision)) {
        violations.add(
          '${entity.path}: 外部Actionは40桁のコミットSHAに固定してください: $reference',
        );
      }
    }

    final checkoutCount = RegExp(r'uses:\s*actions/checkout@[0-9a-f]{40}')
        .allMatches(content)
        .length;
    final nonPersistentCheckoutCount = RegExp(r'persist-credentials:\s*false')
        .allMatches(content)
        .length;
    if (checkoutCount != nonPersistentCheckoutCount) {
      violations.add('${entity.path}: checkoutの資格情報永続化をすべて無効にしてください');
    }

    if (RegExp(
      r'^ {4}env:\s*\n(?:(?: {6}.*)?\n)*? {6}.*secrets\.',
      multiLine: true,
    ).hasMatch(content)) {
      violations.add('${entity.path}: ジョブ全体にシークレットを公開せず必要なステップだけに限定してください');
    }
  }
}

bool _containsUnsupportedPrivacyGuarantee(String line) {
  final normalized = line.toLowerCase();
  return line.contains('外部に漏れる心配') ||
      line.contains('データは外に送られません') ||
      line.contains('アプリ内に安全に保存') ||
      line.contains('アプリ専用領域に安全にコピー') ||
      normalized.contains('100% local storage') ||
      normalized.contains('never leaves your device') ||
      normalized.contains('no data is sent outside') ||
      normalized.contains('safely copied into the app') ||
      normalized.contains('safely copied to app storage') ||
      normalized.contains('save files safely in app storage') ||
      normalized.contains('100% secure');
}

bool _isUserInterfaceDart(String path) {
  final normalized = path.replaceAll('\\', '/');
  return normalized.endsWith('.dart') &&
      (normalized.contains('/presentation/') ||
          normalized.contains('/shared/widgets/'));
}

bool _containsHardcodedJapaneseUiLiteral(String line) {
  final hasJapanese = RegExp(r'[ぁ-んァ-ヶ一-龯]').hasMatch(line);
  if (!hasJapanese) return false;
  return RegExp(
    r'''(?:Text|AppText)\s*\(\s*['"]|(?:hint|semanticLabel|label|title)\s*:\s*['"]''',
  ).hasMatch(line);
}

bool _shouldAudit(String path) {
  final normalized = _normalPath(path);
  if (_excludedFiles.contains(normalized)) return false;
  final segments = normalized.split('/');
  if (segments.any(_excludedSegments.contains) ||
      normalized.endsWith('.g.dart') ||
      normalized.endsWith('.freezed.dart')) {
    return false;
  }
  final dot = normalized.lastIndexOf('.');
  return dot >= 0 && _sourceExtensions.contains(normalized.substring(dot));
}

String _normalPath(String path) => path.replaceAll('\\', '/');

Iterable<int> _iconButtonsWithoutTooltip(String content) sync* {
  for (final call in _iconButtonCalls(content)) {
    if (!_hasDirectNamedArgument(call.invocation, 'tooltip')) {
      yield call.lineNumber;
    }
  }
}

Iterable<int> _iconButtonsWithSmallTapTarget(String content) sync* {
  for (final call in _iconButtonCalls(content)) {
    final constraints = RegExp(
      r'\bconstraints\s*:\s*(?:const\s+)?BoxConstraints(?:\.tightFor)?\(([^)]*)\)',
      dotAll: true,
    ).firstMatch(call.invocation);
    final constraintBody = constraints?.group(1);
    final minimumSize = RegExp(
      r'\bminimumSize\s*:\s*(?:const\s+)?Size\(\s*([0-9.]+)\s*,\s*([0-9.]+)\s*\)',
    ).firstMatch(call.invocation);

    final explicitlySmall =
        constraintBody != null &&
        (constraintBody.trim().isEmpty ||
            _hasDimensionBelowMinimum(constraintBody));
    final smallMinimumSize =
        minimumSize != null &&
        (double.parse(minimumSize.group(1)!) < 48 ||
            double.parse(minimumSize.group(2)!) < 48);
    final compactWithoutMinimum =
        call.invocation.contains('visualDensity: VisualDensity.compact') &&
        constraints == null &&
        minimumSize == null;

    if (explicitlySmall || smallMinimumSize || compactWithoutMinimum) {
      yield call.lineNumber;
    }
  }
}

Iterable<int> _iconButtonsWithLiteralTooltip(String content) sync* {
  final literalTooltip = RegExp(r'''\btooltip\s*:\s*(?:const\s+)?(?:r)?['"]''');
  for (final call in _iconButtonCalls(content)) {
    if (literalTooltip.hasMatch(call.invocation)) yield call.lineNumber;
  }
}

Iterable<int> _popupMenusWithoutTooltip(String content) sync* {
  final starts = RegExp(r'(?<![A-Za-z0-9_])PopupMenuButton(?:<[^>\n]+>)?\s*\(');
  for (final call in _constructorCalls(content, starts)) {
    if (!_hasDirectNamedArgument(call.invocation, 'tooltip')) {
      yield call.lineNumber;
    }
  }
}

Iterable<int> _floatingButtonsWithoutTooltip(String content) sync* {
  final starts = RegExp(r'(?<![A-Za-z0-9_])FloatingActionButton\s*\(');
  for (final call in _constructorCalls(content, starts)) {
    if (!_hasDirectNamedArgument(call.invocation, 'tooltip')) {
      yield call.lineNumber;
    }
  }
}

bool _hasDimensionBelowMinimum(String source) {
  final dimensions = RegExp(
    r'\b(?:minWidth|minHeight|width|height)\s*:\s*([0-9.]+)',
  ).allMatches(source);
  return dimensions.any((match) => double.parse(match.group(1)!) < 48);
}

Iterable<({int lineNumber, String invocation})> _iconButtonCalls(
  String content,
) sync* {
  final starts = RegExp(
    r'(?<![A-Za-z0-9_])IconButton(?:\.(?:filled|filledTonal|outlined))?\s*\(',
  );
  yield* _constructorCalls(content, starts);
}

Iterable<({int lineNumber, String invocation})> _constructorCalls(
  String content,
  RegExp starts,
) sync* {
  for (final match in starts.allMatches(content)) {
    final lineStart = content.lastIndexOf('\n', match.start) + 1;
    final lineEnd = content.indexOf('\n', match.start);
    final sourceLine = content.substring(
      lineStart,
      lineEnd == -1 ? content.length : lineEnd,
    );
    if (sourceLine.trimLeft().startsWith('//')) continue;

    final openParenthesis = content.indexOf('(', match.start);
    final end = _matchingParenthesis(content, openParenthesis);
    if (end == null) continue;
    final invocation = content.substring(openParenthesis + 1, end);
    yield (
      lineNumber: '\n'.allMatches(content.substring(0, match.start)).length + 1,
      invocation: invocation,
    );
  }
}

int? _matchingParenthesis(String source, int start) {
  var depth = 0;
  var quote = '';
  var escaped = false;
  var lineComment = false;
  var blockComment = false;

  for (var index = start; index < source.length; index++) {
    final char = source[index];
    final next = index + 1 < source.length ? source[index + 1] : '';

    if (lineComment) {
      if (char == '\n') lineComment = false;
      continue;
    }
    if (blockComment) {
      if (char == '*' && next == '/') {
        blockComment = false;
        index++;
      }
      continue;
    }
    if (quote.isNotEmpty) {
      if (escaped) {
        escaped = false;
      } else if (char == r'\') {
        escaped = true;
      } else if (char == quote) {
        quote = '';
      }
      continue;
    }
    if (char == '/' && next == '/') {
      lineComment = true;
      index++;
      continue;
    }
    if (char == '/' && next == '*') {
      blockComment = true;
      index++;
      continue;
    }
    if (char == "'" || char == '"') {
      quote = char;
      continue;
    }
    if (char == '(') {
      depth++;
    } else if (char == ')') {
      depth--;
      if (depth == 0) return index;
    }
  }
  return null;
}

bool _hasDirectNamedArgument(String source, String name) {
  var parenthesisDepth = 0;
  var bracketDepth = 0;
  var braceDepth = 0;
  var quote = '';
  var escaped = false;
  var lineComment = false;
  var blockComment = false;

  for (var index = 0; index < source.length; index++) {
    final char = source[index];
    final next = index + 1 < source.length ? source[index + 1] : '';

    if (lineComment) {
      if (char == '\n') lineComment = false;
      continue;
    }
    if (blockComment) {
      if (char == '*' && next == '/') {
        blockComment = false;
        index++;
      }
      continue;
    }
    if (quote.isNotEmpty) {
      if (escaped) {
        escaped = false;
      } else if (char == r'\') {
        escaped = true;
      } else if (char == quote) {
        quote = '';
      }
      continue;
    }
    if (char == '/' && next == '/') {
      lineComment = true;
      index++;
      continue;
    }
    if (char == '/' && next == '*') {
      blockComment = true;
      index++;
      continue;
    }
    if (char == "'" || char == '"') {
      quote = char;
      continue;
    }

    final isTopLevel =
        parenthesisDepth == 0 && bracketDepth == 0 && braceDepth == 0;
    if (isTopLevel && source.startsWith(name, index)) {
      final before = index == 0 ? '' : source[index - 1];
      var cursor = index + name.length;
      while (cursor < source.length && RegExp(r'\s').hasMatch(source[cursor])) {
        cursor++;
      }
      final hasBoundaryBefore =
          before.isEmpty || !RegExp(r'[A-Za-z0-9_]').hasMatch(before);
      if (hasBoundaryBefore &&
          cursor < source.length &&
          source[cursor] == ':') {
        return true;
      }
    }

    switch (char) {
      case '(':
        parenthesisDepth++;
      case ')':
        parenthesisDepth--;
      case '[':
        bracketDepth++;
      case ']':
        bracketDepth--;
      case '{':
        braceDepth++;
      case '}':
        braceDepth--;
    }
  }
  return false;
}
