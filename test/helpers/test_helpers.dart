import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override, ProviderListenable;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:private_shelf/gen_l10n/app_localizations.dart';

/// テスト用のSharedPreferencesを初期化
///
/// テストの setUp() で呼び出してください。
///
/// 使用例:
/// ```dart
/// setUp(() {
///   setupMockSharedPreferences({'key': 'value'});
/// });
/// ```
void setupMockSharedPreferences([Map<String, Object> values = const {}]) {
  SharedPreferences.setMockInitialValues(values);
}

/// ローカライズされたMaterialAppでウィジェットをラップ
///
/// 使用例:
/// ```dart
/// await tester.pumpWidget(createLocalizedApp(MyWidget()));
/// ```
Widget createLocalizedApp(
  Widget child, {
  ThemeData? theme,
  Locale locale = const Locale('ja'),
}) {
  return MaterialApp(
    theme: theme,
    locale: locale,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('ja'), Locale('en')],
    home: Scaffold(body: child),
  );
}

/// Riverpodを使用したローカライズ済みアプリを作成
///
/// 使用例:
/// ```dart
/// await tester.pumpWidget(
///   createProviderApp(MyWidget(), overrides: [...]),
/// );
/// ```
Widget createProviderApp(
  Widget child, {
  List<Override> overrides = const [],
  ThemeData? theme,
  Locale locale = const Locale('ja'),
}) {
  return ProviderScope(
    retry: (_, _) => null,
    overrides: overrides,
    child: createLocalizedApp(child, theme: theme, locale: locale),
  );
}

/// ProviderContainerを作成してテスト後に自動破棄
///
/// 使用例:
/// ```dart
/// final container = createTestContainer(overrides: [...]);
/// addTearDown(container.dispose);
/// ```
ProviderContainer createTestContainer({
  List<Override> overrides = const [],
  ProviderContainer? parent,
}) {
  return ProviderContainer(retry: (_, _) => null, overrides: overrides, parent: parent);
}

/// 非同期処理を待機するユーティリティ
///
/// pumpAndSettleがタイムアウトする場合に使用
Future<void> pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 5),
}) async {
  final endTime = DateTime.now().add(timeout);

  while (DateTime.now().isBefore(endTime)) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty) {
      return;
    }
  }

  throw TestFailure('Widget not found within timeout: $finder');
}

/// Provider の状態が特定の値になるまで待機
Future<T> waitForProviderValue<T>(
  ProviderContainer container,
  ProviderListenable<T> provider,
  bool Function(T value) condition, {
  Duration timeout = const Duration(seconds: 5),
}) async {
  final completer = Completer<T>();

  final subscription = container.listen<T>(provider, (previous, next) {
    if (condition(next) && !completer.isCompleted) {
      completer.complete(next);
    }
  });

  // 現在の値をチェック
  final currentValue = container.read(provider);
  if (condition(currentValue)) {
    subscription.close();
    return currentValue;
  }

  try {
    return await completer.future.timeout(timeout);
  } finally {
    subscription.close();
  }
}
