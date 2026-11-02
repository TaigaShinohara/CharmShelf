import 'dart:io';

import 'package:yaml/yaml.dart';

const _animationPresetSubtle = 'subtle';
const _animationPresetStandard = 'standard';
const _animationPresetDynamic = 'dynamic';

/// Usage メッセージ
const _usage = '''
Usage: dart run scripts/create_app.dart --name <app_name>

必須:
  --name <name>           アプリ名（snake_case推奨）

オプション:
  --help                  このヘルプを表示
  --release-optimized     リリース用に軽量化して生成（DIPを除外）

実行内容:
  1. flutter create で新規プロジェクト作成（親ディレクトリに ../<name>）
  2. テンプレートファイルをコピー
  3. パッケージ名を一括置換
  4. AppConfig を生成
  5. flutter pub get で依存取得
  6. build_runner でコード生成（*.g.dart）

例:
  dart run scripts/create_app.dart --name my_app
''';

Future<void> main(List<String> args) async {
  // --help フラグ
  if (_hasFlag(args, '--help') || _hasFlag(args, '-h')) {
    stdout.writeln(_usage);
    return;
  }

  final name = _arg(args, '--name');
  final releaseOptimized = _hasFlag(args, '--release-optimized');

  if (name == null || name.trim().isEmpty) {
    stderr.writeln(_usage);
    exitCode = 64;
    return;
  }

  // テンプレートルートはスクリプトの親ディレクトリ（scripts/ の上）から特定
  final templateRoot = _getTemplateRoot();
  final webEnabled = _readWebEnabled(templateRoot);
  final outDir = '../$name';
  final dest = Directory(outDir).absolute;

  // 生成先が既に存在する場合はエラーで中断
  if (dest.existsSync()) {
    stderr.writeln('');
    stderr.writeln('エラー: 出力先ディレクトリが既に存在します。');
    stderr.writeln('  ${dest.path}');
    stderr.writeln('');
    stderr.writeln('上書きによるデータ損失を防ぐため、処理を中断します。');
    stderr.writeln('既存ディレクトリは変更しません。別の --name を指定してください。');
    exitCode = 1;
    return;
  }

  // 出力先がテンプレート配下なら、生成物と元プロジェクトの混在を防ぐため中断
  if (_isUnderOrEqual(dest.path, templateRoot.path)) {
    stderr.writeln('');
    stderr.writeln('エラー: 出力先がテンプレートディレクトリ内にあります。');
    stderr.writeln('  出力先: ${dest.path}');
    stderr.writeln('  テンプレート: ${templateRoot.path}');
    stderr.writeln('');
    stderr.writeln('元プロジェクトの変更を防ぐため、処理を中断します。');
    stderr.writeln('テンプレート外に作成される別の --name を指定してください。');
    exitCode = 1;
    return;
  }

  try {
    // Reject private release notes, contact drift and authoring metadata before
    // creating or copying anything into a new app.
    await _run('python3', [
      '${templateRoot.path}/scripts/maintenance/check_private_content.py',
      '--root',
      templateRoot.path,
      '--sources-only',
    ]);
    stdout.writeln('Creating Flutter app at: ${dest.path}');
    await _run('flutter', ['create', '--org', 'com.example', dest.path]);

    // Webを使わない場合は、flutter create が生成した web/ を削除しておく
    if (!webEnabled) {
      final webDir = Directory('${dest.path}/web');
      if (webDir.existsSync()) {
        await webDir.delete(recursive: true); // audit: allow-file-io
        stdout.writeln('Removed web/ directory (web.enabled=false)');
      }
    }

    // Copy template assets (avoid ios/android because flutter create already made them).
    // Agent instructions are project-specific, so do not copy AGENTS.md or tool-specific rules.
    final toCopy = <String>[
      '.github',
      '.vscode',
      'docs',
      'lib',
      'test',
      'assets',
      if (webEnabled) 'web',
      'scripts',
      'analysis_options.yaml',
      '.gitignore',
      'l10n.yaml',
      'template_blueprint.yaml',
      'template_config.yaml',
      'pubspec.yaml',
    ];

    for (final rel in toCopy) {
      final srcPath = '${templateRoot.path}/$rel';
      final dstPath = '${dest.path}/$rel';
      final src = FileSystemEntity.typeSync(srcPath);
      if (src == FileSystemEntityType.notFound) continue;

      if (src == FileSystemEntityType.directory) {
        await _copyDir(Directory(srcPath), Directory(dstPath));
      } else {
        await _copyFile(File(srcPath), File(dstPath));
      }
    }

    // Update package name in pubspec and imports
    await _replaceInTree(
      dir: Directory('${dest.path}/lib'),
      find: 'package:template/',
      replace: 'package:$name/',
    );
    await _replaceInTree(
      dir: Directory('${dest.path}/test'),
      find: 'package:template/',
      replace: 'package:$name/',
    );

    final pubspecFile = File('${dest.path}/pubspec.yaml');
    if (pubspecFile.existsSync()) {
      var pubspec = pubspecFile.readAsStringSync();
      pubspec = pubspec.replaceFirst(
        RegExp(r'^name:\s*.+$', multiLine: true),
        'name: $name',
      );
      pubspecFile.writeAsStringSync(pubspec);
    }

    // Optional: release optimization (DIP removal)
    if (releaseOptimized) {
      stdout.writeln('');
      stdout.writeln('Applying release optimizations (DIP removal)...');
      await _applyReleaseOptimizations(dest);
    }

    // Generate AppConfig from template_config.yaml (this is the "switch" source of truth)
    await _generateAppConfig(dest);

    // Copy optional ARB files based on supported_locales
    stdout.writeln('Copying localization files...');
    await _copyOptionalArbFiles(templateRoot, dest);
    // Update l10n.yaml to use configured default_locale as template
    await _updateL10nYaml(dest);

    // Patch iOS/Android platform configs (permissions, receivers, etc.)
    stdout.writeln('Patching platform configurations...');
    await _patchAndroidManifest(dest);
    await _patchInfoPlist(dest);

    // flutter create が作成した .dart_tool を削除
    // pubspec.yaml がテンプレートに置き換わり依存関係が変わるため、
    // 古い .dart_tool が残っていると pub get が不整合で失敗することがある
    final dartToolDir = Directory('${dest.path}/.dart_tool');
    if (dartToolDir.existsSync()) {
      await dartToolDir.delete(recursive: true); // audit: allow-file-io
      stdout.writeln('Removed .dart_tool (ensuring clean state for pub get)');
    }

    stdout.writeln('Running flutter pub get...');
    await _run('flutter', ['pub', 'get'], workingDirectory: dest.path);

    // build_runner でコード生成（*.g.dart など）
    stdout.writeln('');
    stdout.writeln('Running build_runner (generating *.g.dart files)...');
    await _run('dart', [
      'run',
      'build_runner',
      'build',
    ], workingDirectory: dest.path);

    stdout.writeln('');
    stdout.writeln('✅ App generated successfully at: ${dest.path}');

    stdout.writeln('');
    stdout.writeln('Next steps:');
    stdout.writeln('  cd ${dest.path}');
    stdout.writeln('  flutter run');
  } on ProcessException catch (e) {
    stderr.writeln('');
    stderr.writeln('❌ コマンド実行に失敗しました: ${e.executable} ${e.arguments.join(' ')}');
    stderr.writeln('   終了コード: ${e.errorCode}');
    exitCode = e.errorCode;
  } catch (e) {
    stderr.writeln('');
    stderr.writeln('❌ エラーが発生しました: $e');
    exitCode = 1;
  }
}

String? _arg(List<String> args, String name) {
  final i = args.indexOf(name);
  if (i == -1) return null;
  if (i + 1 >= args.length) return null;
  return args[i + 1];
}

/// フラグ（値を取らないオプション）の存在チェック
bool _hasFlag(List<String> args, String name) {
  return args.contains(name);
}

// ---------------------------------------------------------------------------
// Release optimizations (build-time pruning by generator script)
// ---------------------------------------------------------------------------

Future<void> _applyReleaseOptimizations(Directory dest) async {
  await _disableDipInTemplateConfig(dest);
  await _stripDipReferencesFromSource(dest);
  await _deleteDipSourceTree(dest);
}

Future<void> _disableDipInTemplateConfig(Directory dest) async {
  final configFile = File('${dest.path}/template_config.yaml');
  if (!configFile.existsSync()) return;

  final yamlText = configFile.readAsStringSync();
  final dynamic root = loadYaml(yamlText);
  if (root is! YamlMap) return;

  // 既に false なら何もしない（テンプレに追従）
  final dipEnabled = _boolAt(root, ['features', 'dip', 'enabled'], def: true);
  if (!dipEnabled) return;

  // Bug 5 fix: dip セクション内の enabled のみ対象にする。
  // 「dip:」行を見つけ、その直後の「enabled: true」を置換。
  // NOTE: YAMLパーサで再シリアライズするとコメント等が失われるため、テキスト置換で対応。
  final dipPattern = RegExp(
    r'(^\s*dip:\s*\n(?:\s*#[^\n]*\n)*\s*enabled:\s*)true(\s*(?:\n|$))',
    multiLine: true,
  );
  final next = yamlText.replaceFirst(dipPattern, r'$1false$2');
  if (next != yamlText) {
    configFile.writeAsStringSync(next);
    stdout.writeln(
      '  Patched: template_config.yaml (features.dip.enabled=false)',
    );
  }
}

Future<void> _stripDipReferencesFromSource(Directory dest) async {
  // main.dart: DIP初期化ブロックとimportを除去
  final mainFile = File('${dest.path}/lib/main.dart');
  if (mainFile.existsSync()) {
    var s = mainFile.readAsStringSync();
    s = s.replaceAll(
      RegExp(r"^import 'core/debug/dip\.dart';\s*$", multiLine: true),
      '',
    );
    s = s.replaceAll(
      RegExp(r'''
\s*// DIP（Developer In-App Panel）の初期化\s*
\s*if\s*\(FeatureFlags\.enableDip\)\s*\{\s*
\s*initializeDip\(\);\s*
\s*AppLogger\.d\(LogTag\.app,\s*'DIP（開発者パネル）を初期化'\);\s*
\s*\}\s*
''', multiLine: true),
      '',
    );
    mainFile.writeAsStringSync(s);
    stdout.writeln('  Patched: lib/main.dart (removed DIP references)');
  }

  // app.dart: DIP依存（provider/watch + wrapper + debug options）を除去
  final appFile = File('${dest.path}/lib/app/app.dart');
  if (appFile.existsSync()) {
    var s = appFile.readAsStringSync();
    s = s.replaceAll(
      RegExp(r"^import '\.\./core/debug/dip\.dart';\s*$", multiLine: true),
      '',
    );
    // DIP状態のwatchブロックを削除（コメント付きブロック丸ごと）
    s = s.replaceAll(
      RegExp(r'''
\s*// DIP関連の状態\s*
[\s\S]*?final customColors = FeatureFlags\.enableDip[\s\S]*?: null;\s*
''', multiLine: true),
      '',
    );
    // MaterialApp.router のデバッグオプション行を削除
    s = s.replaceAll(RegExp(r'^\s*// DIPデバッグオプション\s*$', multiLine: true), '');
    s = s.replaceAll(
      RegExp(
        r'^\s*showPerformanceOverlay:\s*showPerformanceOverlay,\s*$',
        multiLine: true,
      ),
      '',
    );
    s = s.replaceAll(
      RegExp(
        r'^\s*debugShowCheckedModeBanner:\s*widgetInspectorState\.showDebugBanner,\s*$',
        multiLine: true,
      ),
      '',
    );
    s = s.replaceAll(
      RegExp(
        r'^\s*showSemanticsDebugger:\s*widgetInspectorState\.showSemanticsDebugger,\s*$',
        multiLine: true,
      ),
      '',
    );
    // locale: locale, を削除（DIP由来のため）
    s = s.replaceAll(RegExp(r'^\s*locale:\s*locale,\s*$', multiLine: true), '');
    // themeのcustomColors参照（primary/secondary）を通常のAppTheme.*に戻すため、引数ごと削除
    s = s.replaceAll(
      RegExp(
        r'^\s*primaryColor:\s*customColors\?\.primaryColor,\s*$',
        multiLine: true,
      ),
      '',
    );
    s = s.replaceAll(
      RegExp(
        r'^\s*secondaryColor:\s*customColors\?\.secondaryColor,\s*$',
        multiLine: true,
      ),
      '',
    );

    // builder のtextScale分岐（DIP由来）を削除して child だけ返す
    s = s.replaceAll(
      RegExp(r'''
\s*builder:\s*\(context,\s*child\)\s*\{\s*
[\s\S]*?
\s*return child \?\? const SizedBox\.shrink\(\);\s*
\s*\},\s*
''', multiLine: true),
      '',
    );

    // DIPジェスチャーラッパーを削除
    s = s.replaceAll(
      RegExp(r'''
\s*// DIPジェスチャーラッパーで囲む\s*
\s*if\s*\(FeatureFlags\.enableDip\)\s*\{\s*
\s*app = DipGestureWrapper\(child: app\);\s*
\s*\}\s*
''', multiLine: true),
      '',
    );

    appFile.writeAsStringSync(s);
    stdout.writeln('  Patched: lib/app/app.dart (removed DIP references)');
  }

  // settings_page.dart: 開発者オプション（DIP）を削除
  final settingsFile = File(
    '${dest.path}/lib/features/settings/presentation/settings_page.dart',
  );
  if (settingsFile.existsSync()) {
    var s = settingsFile.readAsStringSync();
    s = s.replaceAll(
      RegExp(
        r"^import '\.\./\.\./\.\./core/debug/dip\.dart';\s*$",
        multiLine: true,
      ),
      '',
    );
    // DIPセクション全体を削除
    s = s.replaceAll(
      RegExp(r'''
\s*// 開発者オプション（DIPが有効な場合のみ表示）\s*
\s*if\s*\(FeatureFlags\.enableDip\)\s*
\s*SettingsSection\([\s\S]*?\),\s*
''', multiLine: true),
      '',
    );
    settingsFile.writeAsStringSync(s);
    stdout.writeln(
      '  Patched: lib/features/settings/presentation/settings_page.dart (removed DIP section)',
    );
  }
}

Future<void> _deleteDipSourceTree(Directory dest) async {
  final dir = Directory('${dest.path}/lib/core/debug');
  if (!dir.existsSync()) return;
  await dir.delete(recursive: true); // audit: allow-file-io
  stdout.writeln('  Removed: lib/core/debug/ (DIP sources)');
}

/// テンプレートルートをスクリプト位置から特定
/// `scripts/create_app.dart` の親の親がテンプレートルート
Directory _getTemplateRoot() {
  // dart run scripts/create_app.dart で実行された場合
  // Platform.script は file:///path/to/template/scripts/create_app.dart
  final scriptUri = Platform.script;
  if (scriptUri.scheme == 'file') {
    final scriptFile = File.fromUri(scriptUri);
    // scripts/ の親がテンプレートルート
    return scriptFile.parent.parent.absolute;
  }
  // フォールバック: カレントディレクトリ
  return Directory.current.absolute;
}

/// パスを正規化（../ や ./ を解決）
String _normalizePath(String path) {
  // Uriを使って .. や . を解決
  final uri = Uri.file(path);
  return uri.normalizePath().toFilePath();
}

/// path1 が path2 と同一、または path2 配下にあるかチェック
bool _isUnderOrEqual(String path1, String path2) {
  // 両方を正規化して比較（../ などを解決）
  final normalized1 = _normalizePath(Directory(path1).absolute.path);
  final normalized2 = _normalizePath(Directory(path2).absolute.path);
  // 同一パス
  if (normalized1 == normalized2) return true;
  // path1 が path2 配下（path2/ で始まる）
  final prefix = normalized2.endsWith('/') ? normalized2 : '$normalized2/';
  return normalized1.startsWith(prefix);
}

bool _readWebEnabled(Directory templateRoot) {
  try {
    final configFile = File('${templateRoot.path}/template_config.yaml');
    if (!configFile.existsSync()) return false;
    final yamlText = configFile.readAsStringSync();
    final dynamic root = loadYaml(yamlText);
    if (root is! YamlMap) return false;
    return _boolAt(root, ['platform', 'web', 'enabled'], def: false);
  } catch (_) {
    return false;
  }
}

Future<void> _generateAppConfig(Directory dest) async {
  final configFile = File('${dest.path}/template_config.yaml');
  if (!configFile.existsSync()) {
    stdout.writeln(
      'template_config.yaml not found. Skip AppConfig generation.',
    );
    return;
  }

  final yamlText = configFile.readAsStringSync();
  final dynamic root = loadYaml(yamlText);
  if (root is! YamlMap) {
    stdout.writeln(
      'template_config.yaml is not a map. Skip AppConfig generation.',
    );
    return;
  }

  bool b(List<String> path, {required bool def}) =>
      _boolAt(root, path, def: def);
  String s(List<String> path, {required String def}) =>
      _stringAt(root, path, def: def);
  double d(List<String> path, {required double def}) =>
      _doubleAt(root, path, def: def);
  int i(List<String> path, {required int def}) => _intAt(root, path, def: def);

  final appName = s(['app', 'name'], def: 'MyApp');
  final packageName = s(['app', 'package_name'], def: 'com.example.myapp');
  final minAge = i(['app', 'min_age'], def: 13);

  // Platform
  final webEnabled = b(['platform', 'web', 'enabled'], def: false);

  final tabBarEnabled = b(['features', 'tab_bar', 'enabled'], def: true);
  final localAuthEnabled = b(['features', 'local_auth', 'enabled'], def: false);
  final onboardingEnabled = b(['features', 'onboarding', 'enabled'], def: true);
  final appReviewEnabled = b(['features', 'app_review', 'enabled'], def: false);
  final tutorialEnabled = b(['features', 'tutorial', 'enabled'], def: false);
  final forceUpdateEnabled = b([
    'features',
    'force_update',
    'enabled',
  ], def: false);
  final deepLinkEnabled = b(['features', 'deep_link', 'enabled'], def: false);
  final deepLinkScheme = s(['features', 'deep_link', 'scheme'], def: 'myapp');

  final darkModeEnabled = b(['features', 'dark_mode', 'enabled'], def: true);
  final i18nEnabled = b(['features', 'i18n', 'enabled'], def: true);

  final hapticsEnabled = b(['feedback', 'haptics', 'enabled'], def: true);
  final soundEnabled = b(['feedback', 'sound', 'enabled'], def: true);
  final dipEnabled = b(['features', 'dip', 'enabled'], def: true);

  // UI showcase (reference UIs for future app variants)
  final uiShowcaseEnabled = b([
    'features',
    'ui_showcase',
    'enabled',
  ], def: false);
  final uiShowcaseChatEnabled = b([
    'features',
    'ui_showcase',
    'chat',
  ], def: true);
  final uiShowcaseTimelineEnabled = b([
    'features',
    'ui_showcase',
    'timeline',
  ], def: true);
  final uiShowcaseVideoEnabled = b([
    'features',
    'ui_showcase',
    'video',
  ], def: true);
  final uiShowcaseShortsEnabled = b([
    'features',
    'ui_showcase',
    'shorts',
  ], def: true);
  final uiShowcaseSwipeCardEnabled = b([
    'features',
    'ui_showcase',
    'swipe_card',
  ], def: true);

  final defaultLocale = s(['features', 'i18n', 'default_locale'], def: 'ja');
  final supportedLocales = _stringListAt(
    root,
    ['features', 'i18n', 'supported_locales'],
    def: const ['ja', 'en'],
  );

  final textScaleMax = d(['system', 'text_scale_max'], def: 1.3);
  final orientation = s(['system', 'orientation'], def: 'portrait');

  // テーマ色の読み込み
  int c(List<String> path, {required int def}) =>
      _hexColorAt(root, path, def: def);

  final primaryColor = c(['theme', 'primary_color'], def: 0xFF6366F1);
  final secondaryColor = c(['theme', 'secondary_color'], def: 0xFFEC4899);
  final successColor = c(['theme', 'success_color'], def: 0xFF10B981);
  final warningColor = c(['theme', 'warning_color'], def: 0xFFF59E0B);
  final errorColor = c(['theme', 'error_color'], def: 0xFFEF4444);
  final infoColor = c(['theme', 'info_color'], def: 0xFF3B82F6);
  final backgroundColor = c(['theme', 'background_color'], def: 0xFFFFFFFF);
  final surfaceColor = c(['theme', 'surface_color'], def: 0xFFF8FAFC);
  final scaffoldColor = c(['theme', 'scaffold_color'], def: 0xFFFAFAFA);
  final shadowColor = c(['theme', 'shadow_color'], def: 0xFF000000);
  final overlayColor = c(['theme', 'overlay_color'], def: 0xFF000000);
  final borderColor = c(['theme', 'border_color'], def: 0xFFE2E8F0);
  final textPrimaryColor = c(['theme', 'text_primary_color'], def: 0xFF1E293B);
  final textSecondaryColor = c([
    'theme',
    'text_secondary_color',
  ], def: 0xFF64748B);
  final textDisabledColor = c([
    'theme',
    'text_disabled_color',
  ], def: 0xFF94A3B8);
  final useMaterial3 = b(['theme', 'use_material3'], def: true);

  // アニメーション設定
  final animationEnabled = b(['animation', 'enabled'], def: true);
  final animationPreset = s([
    'animation',
    'preset',
  ], def: _animationPresetStandard).trim();

  final presetDurations = _animationPresetDurations(animationPreset);
  final instantMs = i([
    'animation',
    'duration',
    'instant',
  ], def: presetDurations.instantMs);
  final fastMs = i([
    'animation',
    'duration',
    'fast',
  ], def: presetDurations.fastMs);
  final normalMs = i([
    'animation',
    'duration',
    'normal',
  ], def: presetDurations.normalMs);
  final slowMs = i([
    'animation',
    'duration',
    'slow',
  ], def: presetDurations.slowMs);
  final pageMs = i([
    'animation',
    'duration',
    'page',
  ], def: presetDurations.pageMs);
  final staggerDelayMs = i([
    'animation',
    'stagger_delay',
  ], def: presetDurations.staggerDelayMs);

  final localesLiteral = supportedLocales
      .map((code) => '    ${_localeConstructor(code)},')
      .join('\n');

  // int を 16進数リテラル文字列に変換
  String hex(int color) =>
      '0x${color.toRadixString(16).toUpperCase().padLeft(8, '0')}';

  final outFile = File('${dest.path}/lib/core/config/app_config.dart');
  outFile.parent.createSync(recursive: true);
  outFile.writeAsStringSync('''import 'package:flutter/widgets.dart';

/// アプリ設定（GENERATED）
///
/// このファイルは `scripts/create_app.dart` が `template_config.yaml` から生成します。
/// 量産時の「切り替えスイッチ」は template_config.yaml です。
class AppConfig {
  static const String appName = ${_dartString(appName)};
  static const String packageName = ${_dartString(packageName)};
  static const int minAge = $minAge;

  static const Features features = Features(
    webEnabled: $webEnabled,
    tabBarEnabled: $tabBarEnabled,
    localAuthEnabled: $localAuthEnabled,
    onboardingEnabled: $onboardingEnabled,
    appReviewEnabled: $appReviewEnabled,
    tutorialEnabled: $tutorialEnabled,
    forceUpdateEnabled: $forceUpdateEnabled,
    deepLinkEnabled: $deepLinkEnabled,
    deepLinkScheme: ${_dartString(deepLinkScheme)},
    darkModeEnabled: $darkModeEnabled,
    i18nEnabled: $i18nEnabled,
    hapticsEnabled: $hapticsEnabled,
    soundEnabled: $soundEnabled,
    dipEnabled: $dipEnabled,
    uiShowcaseEnabled: $uiShowcaseEnabled,
    uiShowcaseChatEnabled: $uiShowcaseChatEnabled,
    uiShowcaseTimelineEnabled: $uiShowcaseTimelineEnabled,
    uiShowcaseVideoEnabled: $uiShowcaseVideoEnabled,
    uiShowcaseShortsEnabled: $uiShowcaseShortsEnabled,
    uiShowcaseSwipeCardEnabled: $uiShowcaseSwipeCardEnabled,
  );

  static const ThemeConfig theme = ThemeConfig(
    primaryColor: ${hex(primaryColor)},
    secondaryColor: ${hex(secondaryColor)},
    successColor: ${hex(successColor)},
    warningColor: ${hex(warningColor)},
    errorColor: ${hex(errorColor)},
    infoColor: ${hex(infoColor)},
    backgroundColor: ${hex(backgroundColor)},
    surfaceColor: ${hex(surfaceColor)},
    scaffoldColor: ${hex(scaffoldColor)},
    shadowColor: ${hex(shadowColor)},
    overlayColor: ${hex(overlayColor)},
    borderColor: ${hex(borderColor)},
    textPrimaryColor: ${hex(textPrimaryColor)},
    textSecondaryColor: ${hex(textSecondaryColor)},
    textDisabledColor: ${hex(textDisabledColor)},
    useMaterial3: $useMaterial3,
  );

  static const AnimationConfig animation = AnimationConfig(
    enabled: $animationEnabled,
    preset: ${_dartString(_normalizeAnimationPreset(animationPreset))},
    instant: Duration(milliseconds: $instantMs),
    fast: Duration(milliseconds: $fastMs),
    normal: Duration(milliseconds: $normalMs),
    slow: Duration(milliseconds: $slowMs),
    page: Duration(milliseconds: $pageMs),
    staggerDelay: Duration(milliseconds: $staggerDelayMs),
  );

  static const List<Locale> supportedLocales = <Locale>[
$localesLiteral
  ];

  static const String defaultLocale = ${_dartString(defaultLocale)};

  static const double textScaleMax = $textScaleMax;
  static const String orientation = ${_dartString(orientation)};
}

class Features {
  const Features({
    required this.webEnabled,
    required this.tabBarEnabled,
    required this.localAuthEnabled,
    required this.onboardingEnabled,
    required this.appReviewEnabled,
    required this.tutorialEnabled,
    required this.forceUpdateEnabled,
    required this.deepLinkEnabled,
    required this.deepLinkScheme,
    required this.darkModeEnabled,
    required this.i18nEnabled,
    required this.hapticsEnabled,
    required this.soundEnabled,
    required this.dipEnabled,
    required this.uiShowcaseEnabled,
    required this.uiShowcaseChatEnabled,
    required this.uiShowcaseTimelineEnabled,
    required this.uiShowcaseVideoEnabled,
    required this.uiShowcaseShortsEnabled,
    required this.uiShowcaseSwipeCardEnabled,
  });

  final bool webEnabled;
  final bool tabBarEnabled;
  final bool localAuthEnabled;
  final bool onboardingEnabled;
  final bool appReviewEnabled;
  final bool tutorialEnabled;
  final bool forceUpdateEnabled;
  final bool deepLinkEnabled;
  final String deepLinkScheme;
  final bool darkModeEnabled;
  final bool i18nEnabled;
  final bool hapticsEnabled;
  final bool soundEnabled;
  final bool dipEnabled;

  final bool uiShowcaseEnabled;
  final bool uiShowcaseChatEnabled;
  final bool uiShowcaseTimelineEnabled;
  final bool uiShowcaseVideoEnabled;
  final bool uiShowcaseShortsEnabled;
  final bool uiShowcaseSwipeCardEnabled;
}

class ThemeConfig {
  const ThemeConfig({
    required this.primaryColor,
    required this.secondaryColor,
    required this.successColor,
    required this.warningColor,
    required this.errorColor,
    required this.infoColor,
    required this.backgroundColor,
    required this.surfaceColor,
    required this.scaffoldColor,
    required this.shadowColor,
    required this.overlayColor,
    required this.borderColor,
    required this.textPrimaryColor,
    required this.textSecondaryColor,
    required this.textDisabledColor,
    required this.useMaterial3,
  });

  final int primaryColor;
  final int secondaryColor;
  final int successColor;
  final int warningColor;
  final int errorColor;
  final int infoColor;
  final int backgroundColor;
  final int surfaceColor;
  final int scaffoldColor;
  final int shadowColor;
  final int overlayColor;
  final int borderColor;
  final int textPrimaryColor;
  final int textSecondaryColor;
  final int textDisabledColor;
  final bool useMaterial3;
}

class AnimationConfig {
  const AnimationConfig({
    required this.enabled,
    required this.preset,
    required this.instant,
    required this.fast,
    required this.normal,
    required this.slow,
    required this.page,
    required this.staggerDelay,
  });

  final bool enabled;
  final String preset;
  final Duration instant;
  final Duration fast;
  final Duration normal;
  final Duration slow;
  final Duration page;
  final Duration staggerDelay;

  /// プリセットに基づく標準カーブ
  Curve get defaultCurve => switch (preset) {
        '$_animationPresetSubtle' => Curves.easeOut,
        '$_animationPresetDynamic' => Curves.easeOutBack,
        _ => Curves.easeOutCubic,
      };

  /// 少し強調したい場面向け（バウンス寄り）
  Curve get emphasizedCurve => switch (preset) {
        '$_animationPresetSubtle' => Curves.easeOutCubic,
        _ => Curves.easeOutBack,
      };
}
''');

  stdout.writeln('Generated: ${outFile.path}');
}

String _normalizeAnimationPreset(String preset) {
  final p = preset.trim();
  if (p == _animationPresetSubtle) return _animationPresetSubtle;
  if (p == _animationPresetDynamic) return _animationPresetDynamic;
  return _animationPresetStandard;
}

({
  int instantMs,
  int fastMs,
  int normalMs,
  int slowMs,
  int pageMs,
  int staggerDelayMs,
})
_animationPresetDurations(String preset) {
  final p = _normalizeAnimationPreset(preset);
  return switch (p) {
    _animationPresetSubtle => (
      instantMs: 80,
      fastMs: 150,
      normalMs: 200,
      slowMs: 350,
      pageMs: 250,
      staggerDelayMs: 40,
    ),
    _animationPresetDynamic => (
      instantMs: 120,
      fastMs: 250,
      normalMs: 400,
      slowMs: 600,
      pageMs: 450,
      staggerDelayMs: 60,
    ),
    _ => (
      instantMs: 100,
      fastMs: 200,
      normalMs: 300,
      slowMs: 500,
      pageMs: 350,
      staggerDelayMs: 50,
    ),
  };
}

bool _boolAt(YamlMap root, List<String> path, {required bool def}) {
  final v = _at(root, path);
  return v is bool ? v : def;
}

String _stringAt(YamlMap root, List<String> path, {required String def}) {
  final v = _at(root, path);
  return v is String && v.trim().isNotEmpty ? v : def;
}

int _intAt(YamlMap root, List<String> path, {required int def}) {
  final v = _at(root, path);
  // YAMLは整数値をdoubleとしてパースする場合がある (例: 13 → 13.0)
  if (v is num) return v.toInt();
  return def;
}

double _doubleAt(YamlMap root, List<String> path, {required double def}) {
  final v = _at(root, path);
  if (v is num) return v.toDouble();
  return def;
}

List<String> _stringListAt(
  YamlMap root,
  List<String> path, {
  required List<String> def,
}) {
  final v = _at(root, path);
  if (v is YamlList) {
    final list = <String>[];
    for (final e in v) {
      if (e is String && e.trim().isNotEmpty) list.add(e.trim());
    }
    if (list.isNotEmpty) return list;
  }
  return def;
}

dynamic _at(YamlMap root, List<String> path) {
  dynamic cur = root;
  for (final key in path) {
    if (cur is YamlMap && cur.containsKey(key)) {
      cur = cur[key];
    } else {
      return null;
    }
  }
  return cur;
}

/// ロケールコードから Locale コンストラクタ文字列を生成
/// - "en" → "Locale('en')"
/// - "zh_Hant" → "Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant')"
/// - "pt_BR" → "Locale('pt', 'BR')"
String _localeConstructor(String code) {
  if (code.contains('_')) {
    final parts = code.split('_');
    final language = parts[0];
    final second = parts[1];

    // スクリプトコード（4文字、先頭大文字）の場合
    // 例: zh_Hant, zh_Hans
    if (second.length == 4 && second[0] == second[0].toUpperCase()) {
      return "Locale.fromSubtags(languageCode: '$language', scriptCode: '$second')";
    }

    // カントリーコード（2文字大文字）の場合
    // 例: pt_BR, en_US
    return "Locale('$language', '$second')";
  }

  // シンプルな言語コード
  return "Locale('$code')";
}

String _dartString(String s) {
  // 順序: バックスラッシュを先にエスケープ、次にクォート
  // 元の問題: r"\\'" は3文字(\\')で、'を\\'に置換していた（正しくは\'）
  final escaped = s.replaceAll('\\', r'\\').replaceAll("'", r"\'");
  return "'$escaped'";
}

/// HEX色文字列（#RRGGBB または #RGB）を int（0xFFRRGGBB）に変換
int _hexColorAt(YamlMap root, List<String> path, {required int def}) {
  final v = _at(root, path);
  if (v is! String) return def;
  return _parseHexColor(v, def: def);
}

int _parseHexColor(String hex, {required int def}) {
  var s = hex.trim();
  if (s.startsWith('#')) s = s.substring(1);
  if (s.isEmpty) return def;

  // 3桁 (#RGB) → 6桁 (#RRGGBB) に展開
  if (s.length == 3) {
    s = '${s[0]}${s[0]}${s[1]}${s[1]}${s[2]}${s[2]}';
  }

  if (s.length != 6) return def;

  final parsed = int.tryParse(s, radix: 16);
  if (parsed == null) return def;

  // 0xRRGGBB → 0xFFRRGGBB（アルファ値を追加）
  return 0xFF000000 | parsed;
}

Future<void> _run(
  String executable,
  List<String> arguments, {
  String? workingDirectory,
}) async {
  final result = await Process.run(
    executable,
    arguments,
    workingDirectory: workingDirectory,
    runInShell: true,
  );

  if (result.stdout is String && (result.stdout as String).isNotEmpty) {
    stdout.write(result.stdout);
  }
  if (result.stderr is String && (result.stderr as String).isNotEmpty) {
    stderr.write(result.stderr);
  }

  if (result.exitCode != 0) {
    throw ProcessException(
      executable,
      arguments,
      'Process failed',
      result.exitCode,
    );
  }
}

Future<void> _copyFile(File src, File dst) async {
  dst.parent.createSync(recursive: true);
  await src.copy(dst.path);
}

bool shouldCopyTemplateEntry(String name) =>
    !const {
      '.git',
      '.dart_tool',
      'build',
      'coverage',
      '__pycache__',
      '.DS_Store',
    }.contains(name) &&
    !name.endsWith('.pyc');

Future<void> _copyDir(Directory src, Directory dst) async {
  if (!dst.existsSync()) dst.createSync(recursive: true);
  await for (final entity in src.list(recursive: false, followLinks: false)) {
    // ディレクトリURIは末尾スラッシュがあり pathSegments.last が空文字になるため
    // 空でない最後のセグメントを取得する
    final name = entity.uri.pathSegments.where((s) => s.isNotEmpty).last;
    if (!shouldCopyTemplateEntry(name)) continue;
    final newPath = '${dst.path}/$name';
    if (entity is Directory) {
      await _copyDir(entity, Directory(newPath));
    } else if (entity is File) {
      await _copyFile(entity, File(newPath));
    }
  }
}

Future<void> _replaceInTree({
  required Directory dir,
  required String find,
  required String replace,
}) async {
  if (!dir.existsSync()) return;

  await for (final entity in dir.list(recursive: true, followLinks: false)) {
    if (entity is! File) continue;
    if (!entity.path.endsWith('.dart')) continue;
    final text = entity.readAsStringSync();
    if (!text.contains(find)) continue;
    entity.writeAsStringSync(text.replaceAll(find, replace));
  }
}

// =============================================================================
// Platform Configuration Patching
// =============================================================================

/// AndroidManifest.xml にパーミッションとレシーバーを追加
Future<void> _patchAndroidManifest(Directory dest) async {
  final manifestFile = File(
    '${dest.path}/android/app/src/main/AndroidManifest.xml',
  );
  if (!manifestFile.existsSync()) {
    stderr.writeln('Warning: AndroidManifest.xml not found. Skip patching.');
    return;
  }

  var content = manifestFile.readAsStringSync();
  var changed = false;

  // 1. パーミッションを追加（<manifest ...> の直後）
  const permissions = '''
    <uses-permission android:name="android.permission.CAMERA" />

    <!-- ローカル通知 -->
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />
    <uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM" />
    <uses-permission android:name="android.permission.USE_EXACT_ALARM" />
    <uses-permission android:name="android.permission.VIBRATE" />

    <!-- 接続状態チェック -->
    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />

''';

  // パーミッションが既に存在するかチェック
  if (!content.contains('android.permission.POST_NOTIFICATIONS')) {
    // <manifest ...> タグの終わりを見つけて直後に挿入
    final manifestTagEnd = RegExp(r'<manifest[^>]*>');
    final match = manifestTagEnd.firstMatch(content);
    if (match != null) {
      final insertPos = match.end;
      content =
          '${content.substring(0, insertPos)}\n$permissions${content.substring(insertPos)}';
      changed = true;
    }
  }

  // 2. 通知レシーバーを追加（</application> の直前）
  const receivers = '''
        <!-- flutter_local_notifications: 再起動後に通知を再スケジュール -->
        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" />
        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED"/>
                <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
                <action android:name="android.intent.action.QUICKBOOT_POWERON" />
                <category android:name="android.intent.category.DEFAULT" />
            </intent-filter>
        </receiver>
''';

  // レシーバーが既に存在するかチェック
  if (!content.contains('ScheduledNotificationBootReceiver')) {
    // </application> の直前に挿入
    content = content.replaceFirst(
      '</application>',
      '$receivers    </application>',
    );
    changed = true;
  }

  // 3. Deep link（custom scheme）を追加（MainActivityの</activity>直前）
  final scheme = _readDeepLinkScheme(dest);
  final activityRe = RegExp(
    r'<activity[^>]*android:name="[^"]*MainActivity"[^>]*>',
  );
  final activityMatch = activityRe.firstMatch(content);
  if (!content.contains('android:name="flutter_deeplinking_enabled"') &&
      activityMatch != null) {
    const deepLinkOptOut = '''
            <!-- app_links is the only validated deep-link entry point. -->
            <meta-data android:name="flutter_deeplinking_enabled" android:value="false" />
''';
    content =
        '${content.substring(0, activityMatch.end)}\n$deepLinkOptOut${content.substring(activityMatch.end)}';
    changed = true;
  }
  if (!content.contains('android:scheme="$scheme"')) {
    final m = activityRe.firstMatch(content);
    if (m != null) {
      final close = content.indexOf('</activity>', m.end);
      if (close != -1) {
        const marker = 'android.intent.action.VIEW';
        final activityBlock = content.substring(m.start, close);
        if (!activityBlock.contains(marker)) {
          final intentFilter =
              '''
        <!-- Deep link (custom scheme) -->
        <intent-filter>
            <action android:name="android.intent.action.VIEW"/>
            <category android:name="android.intent.category.DEFAULT"/>
            <category android:name="android.intent.category.BROWSABLE"/>
            <data android:scheme="$scheme" />
        </intent-filter>
''';
          content =
              '${content.substring(0, close)}$intentFilter${content.substring(close)}';
          changed = true;
        }
      }
    }
  }

  if (changed) {
    manifestFile.writeAsStringSync(content);
    stdout.writeln('  Patched: AndroidManifest.xml');
  } else {
    stdout.writeln('  AndroidManifest.xml already patched.');
  }
}

/// Info.plist に使用目的と URL スキームを追加
Future<void> _patchInfoPlist(Directory dest) async {
  final plistFile = File('${dest.path}/ios/Runner/Info.plist');
  if (!plistFile.existsSync()) {
    stderr.writeln('Warning: Info.plist not found. Skip patching.');
    return;
  }

  var content = plistFile.readAsStringSync();
  var changed = false;

  if (!content.contains('<key>FlutterDeepLinkingEnabled</key>')) {
    const deepLinkOptOut = '''
	<key>FlutterDeepLinkingEnabled</key>
	<false/>
''';
    content = insertBeforeRootPlistDictEnd(content, deepLinkOptOut);
    changed = true;
  }

  for (final key in const [
    'LSSupportsOpeningDocumentsInPlace',
    'UIFileSharingEnabled',
  ]) {
    final enabledPattern = RegExp('<key>$key</key>\\s*<true\\s*/>');
    if (enabledPattern.hasMatch(content)) {
      content = content.replaceFirst(
        enabledPattern,
        '<key>$key</key>\n\t<false/>',
      );
      changed = true;
    }
  }

  // 使用目的の説明を追加
  const usageDescriptions = '''
	<key>NSCameraUsageDescription</key>
	<string>プロフィール画像の撮影にカメラを使用します。</string>
	<key>NSPhotoLibraryUsageDescription</key>
	<string>プロフィール画像を選択するために写真ライブラリにアクセスします。</string>
''';

  // 既に存在するかチェック
  if (!content.contains('NSCameraUsageDescription')) {
    // </dict> の直前に挿入
    content = insertBeforeRootPlistDictEnd(content, usageDescriptions);
    changed = true;
  }

  // URL scheme（ディープリンク）
  final scheme = _readDeepLinkScheme(dest);
  if (!content.contains('<key>CFBundleURLTypes</key>')) {
    final urlTypes =
        '''
	<key>CFBundleURLTypes</key>
	<array>
		<dict>
			<key>CFBundleTypeRole</key>
			<string>Editor</string>
			<key>CFBundleURLSchemes</key>
			<array>
				<string>$scheme</string>
			</array>
		</dict>
	</array>
''';
    content = insertBeforeRootPlistDictEnd(content, urlTypes);
    changed = true;
  } else if (!content.contains('<string>$scheme</string>')) {
    // 既存のURLSchemes配列に scheme を追加（最初の1箇所のみ）
    final schemesArrayRe = RegExp(
      r'(<key>CFBundleURLSchemes</key>\s*<array>)([\s\S]*?)(</array>)',
    );
    final m = schemesArrayRe.firstMatch(content);
    if (m != null) {
      final insertPos = m.end - '</array>'.length;
      content =
          '${content.substring(0, insertPos)}\n\t\t\t\t<string>$scheme</string>${content.substring(insertPos)}';
      changed = true;
    }
  }

  // ローカライズ設定（CFBundleLocalizations）を追加
  final localizations = _readSupportedLocales(dest);
  if (!content.contains('<key>CFBundleLocalizations</key>')) {
    final localeStrings = localizations
        .map((l) => '\t\t<string>${_iosLocaleCode(l)}</string>')
        .join('\n');
    final localizationsBlock =
        '''
\t<key>CFBundleLocalizations</key>
\t<array>
$localeStrings
\t</array>
''';
    content = insertBeforeRootPlistDictEnd(content, localizationsBlock);
    changed = true;
  }

  if (changed) {
    plistFile.writeAsStringSync(content);
    stdout.writeln('  Patched: Info.plist');
  } else {
    stdout.writeln('  Info.plist already patched.');
  }
}

String insertBeforeRootPlistDictEnd(String content, String block) {
  final rootDictEnd = content.lastIndexOf('</dict>');
  if (rootDictEnd == -1) {
    throw const FormatException('Info.plist root dict is missing');
  }
  return '${content.substring(0, rootDictEnd)}$block${content.substring(rootDictEnd)}';
}

/// supported_locales に基づいて optional/ から ARB ファイルをコピー
Future<void> _copyOptionalArbFiles(
  Directory templateRoot,
  Directory dest,
) async {
  final configFile = File('${dest.path}/template_config.yaml');
  if (!configFile.existsSync()) {
    stdout.writeln('  template_config.yaml not found. Skip ARB copy.');
    return;
  }

  final yamlText = configFile.readAsStringSync();
  final dynamic root = loadYaml(yamlText);
  if (root is! YamlMap) {
    stdout.writeln('  template_config.yaml is not a map. Skip ARB copy.');
    return;
  }

  final supportedLocales = _stringListAt(
    root,
    ['features', 'i18n', 'supported_locales'],
    def: const ['ja', 'en'],
  );

  // デフォルト言語（ja, en）は既にコピー済みなのでスキップ
  const defaultLocales = {'ja', 'en'};
  final optionalLocales = supportedLocales
      .where((l) => !defaultLocales.contains(l))
      .toList();

  if (optionalLocales.isEmpty) {
    stdout.writeln('  No optional locales to copy.');
    return;
  }

  final optionalDir = Directory('${templateRoot.path}/lib/l10n/optional');
  final destL10nDir = Directory('${dest.path}/lib/l10n');

  if (!optionalDir.existsSync()) {
    stderr.writeln('  Warning: optional/ directory not found. Skip ARB copy.');
    return;
  }

  for (final locale in optionalLocales) {
    // locale コード → ファイル名のマッピング
    // zh_Hant → app_zh_Hant.arb, zh → app_zh.arb
    final arbFileName = 'app_$locale.arb';
    final srcFile = File('${optionalDir.path}/$arbFileName');
    final dstFile = File('${destL10nDir.path}/$arbFileName');

    if (srcFile.existsSync()) {
      await _copyFile(srcFile, dstFile);
      stdout.writeln('  Copied: $arbFileName');
    } else {
      stderr.writeln('  Warning: $arbFileName not found in optional/');
    }
  }
}

/// default_locale に基づいて l10n.yaml を更新
Future<void> _updateL10nYaml(Directory dest) async {
  final configFile = File('${dest.path}/template_config.yaml');
  if (!configFile.existsSync()) return;

  final yamlText = configFile.readAsStringSync();
  final dynamic root = loadYaml(yamlText);
  if (root is! YamlMap) return;

  final defaultLocale = _stringAt(root, [
    'features',
    'i18n',
    'default_locale',
  ], def: 'en');

  // デフォルトが "en" なら何もしない（既にテンプレートが app_en.arb）
  if (defaultLocale == 'en') {
    stdout.writeln('  l10n.yaml: default locale is en (no change needed).');
    return;
  }

  final l10nFile = File('${dest.path}/l10n.yaml');
  if (!l10nFile.existsSync()) {
    stderr.writeln('  Warning: l10n.yaml not found.');
    return;
  }

  var content = l10nFile.readAsStringSync();
  final templateArbPattern = RegExp(
    r'^template-arb-file:\s*\S+',
    multiLine: true,
  );
  final newTemplateArb = 'template-arb-file: app_$defaultLocale.arb';

  if (templateArbPattern.hasMatch(content)) {
    content = content.replaceFirst(templateArbPattern, newTemplateArb);
    l10nFile.writeAsStringSync(content);
    stdout.writeln(
      '  Updated l10n.yaml: template-arb-file -> app_$defaultLocale.arb',
    );
  }
}

String _readDeepLinkScheme(Directory dest) {
  try {
    final configFile = File('${dest.path}/template_config.yaml');
    if (!configFile.existsSync()) return 'myapp';
    final yamlText = configFile.readAsStringSync();
    final dynamic root = loadYaml(yamlText);
    if (root is! YamlMap) return 'myapp';
    final scheme = _stringAt(root, [
      'features',
      'deep_link',
      'scheme',
    ], def: 'myapp');
    // URL schemeは [a-zA-Z][a-zA-Z0-9+.-]* が基本
    final normalized = scheme.trim();
    if (normalized.isEmpty) return 'myapp';
    return normalized;
  } catch (_) {
    return 'myapp';
  }
}

List<String> _readSupportedLocales(Directory dest) {
  try {
    final configFile = File('${dest.path}/template_config.yaml');
    if (!configFile.existsSync()) return ['ja', 'en'];
    final yamlText = configFile.readAsStringSync();
    final dynamic root = loadYaml(yamlText);
    if (root is! YamlMap) return ['ja', 'en'];
    return _stringListAt(
      root,
      ['features', 'i18n', 'supported_locales'],
      def: const ['ja', 'en'],
    );
  } catch (_) {
    return ['ja', 'en'];
  }
}

/// ロケールコードをiOS用に変換
/// - "zh_Hant" → "zh-Hant"
/// - "pt_BR" → "pt-BR"
/// - "ja" → "ja"
String _iosLocaleCode(String code) {
  return code.replaceAll('_', '-');
}
