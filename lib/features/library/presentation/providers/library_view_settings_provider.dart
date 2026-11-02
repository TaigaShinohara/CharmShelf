import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:private_shelf/core/providers/setting_notifier.dart';
import 'package:private_shelf/features/library/domain/models/media_filter.dart';

part 'library_view_settings_provider.g.dart';

/// ビューワーのページ送り方向。
enum ViewerPageDirection { leftToRight, rightToLeft }

/// ビューワーのページ送り方向を永続化する。
@riverpod
class ViewerPageDirectionAsync extends _$ViewerPageDirectionAsync
    with SettingNotifierMixin<ViewerPageDirection> {
  @override
  String get key => 'viewer_page_direction';

  @override
  ViewerPageDirection get defaultValue => ViewerPageDirection.leftToRight;

  @override
  Future<ViewerPageDirection> build() => buildSetting();

  @override
  ViewerPageDirection readFromPrefs(SharedPreferences prefs) {
    final index = prefs.getInt(key) ?? defaultValue.index;
    if (index < 0 || index >= ViewerPageDirection.values.length) {
      return defaultValue;
    }
    return ViewerPageDirection.values[index];
  }

  @override
  Future<void> writeToPrefs(
    SharedPreferences prefs,
    ViewerPageDirection value,
  ) async {
    await prefs.setInt(key, value.index);
  }
}

@riverpod
ViewerPageDirection viewerPageDirection(Ref ref) {
  return ref.watch(viewerPageDirectionAsyncProvider).value ??
      ViewerPageDirection.leftToRight;
}

/// ライブラリ全体のデフォルト表示モード（グリッド/リスト）を永続化する
@riverpod
class GlobalViewModeAsync extends _$GlobalViewModeAsync
    with SettingNotifierMixin<ViewMode> {
  @override
  String get key => 'global_library_view_mode';

  @override
  ViewMode get defaultValue => ViewMode.list;

  @override
  Future<ViewMode> build() => buildSetting();

  @override
  ViewMode readFromPrefs(SharedPreferences prefs) {
    final name = prefs.getString(key);
    if (name == null) return defaultValue;
    return ViewMode.values.firstWhere(
      (e) => e.name == name,
      orElse: () => defaultValue,
    );
  }

  @override
  Future<void> writeToPrefs(SharedPreferences prefs, ViewMode value) async {
    await prefs.setString(key, value.name);
  }
}

/// ライブラリ全体の簡易表示モードを永続化する
@riverpod
class GlobalSimpleDisplayAsync extends _$GlobalSimpleDisplayAsync
    with SettingNotifierMixin<bool> {
  @override
  String get key => 'global_library_simple_display';

  @override
  bool get defaultValue => false;

  @override
  Future<bool> build() => buildSetting();

  @override
  bool readFromPrefs(SharedPreferences prefs) =>
      prefs.getBool(key) ?? defaultValue;

  @override
  Future<void> writeToPrefs(SharedPreferences prefs, bool value) async {
    await prefs.setBool(key, value);
  }
}

/// 同期的にアクセスするためのヘルパー
@riverpod
ViewMode globalViewMode(Ref ref) {
  return ref.watch(globalViewModeAsyncProvider).value ?? ViewMode.list;
}

@riverpod
bool globalSimpleDisplay(Ref ref) {
  return ref.watch(globalSimpleDisplayAsyncProvider).value ?? false;
}
