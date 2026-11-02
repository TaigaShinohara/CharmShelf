import 'dart:io';

import 'package:yaml/yaml.dart';

const _animationPresetSubtle = 'subtle';
const _animationPresetStandard = 'standard';
const _animationPresetDynamic = 'dynamic';

/// template_config.yaml の内容を読み込み、lib/core/config/app_config.dart を生成し直します。
///
/// 目的:
/// - テンプレート開発中（このリポジトリで flutter run する時）に、
///   YAMLのテーマ色などを変更しても即座に反映できるようにする。
///
/// 使い方:
///   dart run scripts/update_config.dart
///   dart run scripts/update_config.dart --project /path/to/project
///
/// NOTE:
/// - YAMLは実行時に読むのではなく、Dartへ落とし込む設計です（AppConfig）。
/// - 変更をUIで見るには、コマンド実行後に「Hot Restart」またはアプリ再起動が必要な場合があります。
const _usage = '''
Usage: dart run scripts/update_config.dart [--project <path>]

Options:
  --project <path>    project root (template_config.yaml があるディレクトリ). Default: current directory
  --help, -h          show this help
''';

Future<void> main(List<String> args) async {
  if (_hasFlag(args, '--help') || _hasFlag(args, '-h')) {
    stdout.writeln(_usage);
    return;
  }

  final projectArg = _arg(args, '--project');
  var projectRoot = projectArg != null
      ? Directory(projectArg).absolute
      : Directory.current.absolute;

  // scripts/ ディレクトリで実行されがちなので、1階層上も自動で見る
  if (!_configFile(projectRoot).existsSync() &&
      _configFile(projectRoot.parent).existsSync()) {
    projectRoot = projectRoot.parent;
  }

  if (!_configFile(projectRoot).existsSync()) {
    stderr.writeln('❌ template_config.yaml not found.');
    stderr.writeln('   projectRoot: ${projectRoot.path}');
    stderr.writeln('');
    stderr.writeln('ヒント: プロジェクトルートで実行するか、--project を指定してください。');
    stderr.writeln(_usage);
    exitCode = 64;
    return;
  }

  try {
    await _generateAppConfig(projectRoot);
  } catch (e) {
    stderr.writeln('❌ Failed to update AppConfig: $e');
    exitCode = 1;
  }
}

File _configFile(Directory projectRoot) =>
    File('${projectRoot.path}/template_config.yaml');

String? _arg(List<String> args, String name) {
  final i = args.indexOf(name);
  if (i == -1) return null;
  if (i + 1 >= args.length) return null;
  return args[i + 1];
}

bool _hasFlag(List<String> args, String name) => args.contains(name);

Future<void> _generateAppConfig(Directory projectRoot) async {
  final configFile = _configFile(projectRoot);

  final yamlText = configFile.readAsStringSync();
  final dynamic root = loadYaml(yamlText);
  if (root is! YamlMap) {
    throw StateError('template_config.yaml is not a map.');
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
  final externalLegalUrl = s(['app', 'external_legal_url'], def: '');

  // Platform
  final webEnabled = b(['platform', 'web', 'enabled'], def: false);
  final watchOsEnabled = b(['platform', 'watch_os', 'enabled'], def: false);
  final wearOsEnabled = b(['platform', 'wear_os', 'enabled'], def: false);

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
  final libraryFabAutoHide = b([
    'features',
    'library_fab_auto_hide',
  ], def: true);

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

  // テーマ色
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

  // LocaleリストのDartコードを生成
  final localesLiteral = supportedLocales
      .map((code) => '    ${_localeConstructor(code)},')
      .join('\n');

  String hex(int color) =>
      '0x${color.toRadixString(16).toUpperCase().padLeft(8, '0')}';

  final outFile = File('${projectRoot.path}/lib/core/config/app_config.dart');
  outFile.parent.createSync(recursive: true);
  outFile.writeAsStringSync('''import 'package:flutter/widgets.dart';

/// アプリ設定（GENERATED）
///
/// このファイルは `scripts/update_config.dart` または `scripts/create_app.dart` が
/// `template_config.yaml` から生成します。
///
/// 量産時の「切り替えスイッチ」は template_config.yaml です。
class AppConfig {
  static const String appName = ${_dartString(appName)};
  static const String packageName = ${_dartString(packageName)};
  static const int minAge = $minAge;
  static const String externalLegalUrl = ${_dartString(externalLegalUrl)};

  static const Features features = Features(
    webEnabled: $webEnabled,
    watchOsEnabled: $watchOsEnabled,
    wearOsEnabled: $wearOsEnabled,
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
    libraryFabAutoHide: $libraryFabAutoHide,
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

  static const TierConfig tiers = TierConfig(
    s: ${_dartString(s(['tiers', 's'], def: 'S'))},
    a: ${_dartString(s(['tiers', 'a'], def: 'A'))},
    b: ${_dartString(s(['tiers', 'b'], def: 'B'))},
    c: ${_dartString(s(['tiers', 'c'], def: 'C'))},
    d: ${_dartString(s(['tiers', 'd'], def: 'D'))},
  );

  static const double textScaleMax = $textScaleMax;
  static const String orientation = ${_dartString(orientation)};
}

class TierConfig {
  const TierConfig({
    required this.s,
    required this.a,
    required this.b,
    required this.c,
    required this.d,
  });

  final String s;
  final String a;
  final String b;
  final String c;
  final String d;
}

class Features {
  const Features({
    required this.webEnabled,
    required this.watchOsEnabled,
    required this.wearOsEnabled,
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
    required this.libraryFabAutoHide,

    required this.uiShowcaseEnabled,
    required this.uiShowcaseChatEnabled,
    required this.uiShowcaseTimelineEnabled,
    required this.uiShowcaseVideoEnabled,
    required this.uiShowcaseShortsEnabled,
    required this.uiShowcaseSwipeCardEnabled,
  });

  final bool webEnabled;
  final bool watchOsEnabled;
  final bool wearOsEnabled;
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
  final bool libraryFabAutoHide;

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

  stdout.writeln('✅ Updated: ${outFile.path}');
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
  if (v is num) return v.toInt(); // YAMLが 13 → 13.0 になるケースに対応
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

int _hexColorAt(YamlMap root, List<String> path, {required int def}) {
  final v = _at(root, path);
  if (v is! String) return def;
  return _parseHexColor(v, def: def);
}

int _parseHexColor(String hex, {required int def}) {
  var s = hex.trim();
  if (s.startsWith('#')) s = s.substring(1);
  if (s.isEmpty) return def;

  // 3桁 (#RGB) → 6桁 (#RRGGBB)
  if (s.length == 3) {
    s = '${s[0]}${s[0]}${s[1]}${s[1]}${s[2]}${s[2]}';
  }
  if (s.length != 6) return def;

  final parsed = int.tryParse(s, radix: 16);
  if (parsed == null) return def;

  // 0xRRGGBB → 0xFFRRGGBB
  return 0xFF000000 | parsed;
}

String _localeConstructor(String code) {
  if (code.contains('_')) {
    final parts = code.split('_');
    final language = parts[0];
    final second = parts[1];

    // 例: zh_Hant
    if (second.length == 4 && second[0] == second[0].toUpperCase()) {
      return "Locale.fromSubtags(languageCode: '$language', scriptCode: '$second')";
    }

    // 例: pt_BR
    return "Locale('$language', '$second')";
  }

  return "Locale('$code')";
}

String _dartString(String s) {
  final escaped = s.replaceAll('\\', r'\\').replaceAll("'", r"\'");
  return "'$escaped'";
}
