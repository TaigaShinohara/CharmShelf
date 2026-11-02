import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'library_fab_visibility_provider.g.dart';

/// ライブラリ画面のFAB（追加ボタン）の表示状態を管理するプロバイダー。
///
/// 下にスクロールすると非表示になり、上にスクロールするか、
/// 一定時間操作がないと自動的に再表示される。
@riverpod
class LibraryFabVisibility extends _$LibraryFabVisibility {
  Timer? _timer;
  static const _showDuration = Duration(seconds: 1);

  @override
  bool build() {
    ref.onDispose(() => _timer?.cancel());
    return true;
  }

  /// FABを非表示にする。
  /// 一定時間後に自動的に表示状態に戻すタイマーを開始する。
  void hide() {
    if (state == false) {
      _resetTimer();
      return;
    }
    state = false;
    _resetTimer();
  }

  /// FABを表示する。
  void show() {
    _timer?.cancel();
    if (state == true) return;
    state = true;
  }

  void _resetTimer() {
    _timer?.cancel();
    _timer = Timer(_showDuration, () {
      show();
    });
  }
}
