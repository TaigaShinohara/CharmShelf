import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'unsaved_data_provider.g.dart';

/// 未保存データを持つ画面のキーを管理するプロバイダー
///
/// 各画面で編集中のデータがある場合、screenKeyを登録することで
/// タブ切り替え時やルート復帰時に確認ダイアログを表示できます。
@Riverpod(keepAlive: true)
class UnsavedDataKeys extends _$UnsavedDataKeys {
  @override
  Set<String> build() => {};

  /// 未保存状態としてマーク
  void markAsUnsaved(String screenKey) {
    state = {...state, screenKey};
  }

  /// 保存済み状態としてマーク（キーを削除）
  void markAsSaved(String screenKey) {
    state = {...state}..remove(screenKey);
  }

  /// 全てクリア
  void clearAll() {
    state = {};
  }

  /// 未保存データがあるかどうか
  bool get hasUnsavedData => state.isNotEmpty;
}

/// 未保存状態としてマークするヘルパー関数
void markAsUnsaved(WidgetRef ref, String screenKey) {
  ref.read(unsavedDataKeysProvider.notifier).markAsUnsaved(screenKey);
}

/// 保存済み状態としてマークするヘルパー関数
void markAsSaved(WidgetRef ref, String screenKey) {
  ref.read(unsavedDataKeysProvider.notifier).markAsSaved(screenKey);
}

/// 未保存データがあるかどうかをチェックするヘルパー関数
bool hasUnsavedData(WidgetRef ref) {
  return ref.read(unsavedDataKeysProvider).isNotEmpty;
}
