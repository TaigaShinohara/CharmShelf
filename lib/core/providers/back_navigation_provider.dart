import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'back_navigation_provider.g.dart';

/// タブルート内の画面が戻る操作を処理した回数を管理します。
///
/// ネストされたNavigatorのルート画面は、フォルダ階層や選択モードなどを
/// 画面内状態として保持します。MainTabPageはこのリビジョンを比較することで、
/// 画面内状態が戻された場合はアプリを終了せず、何も処理されなかった場合だけ
/// アプリをバックグラウンドへ移動できます。
@Riverpod(keepAlive: true)
class BackNavigationRevision extends _$BackNavigationRevision {
  @override
  int build() => 0;

  void markHandled() {
    state++;
  }
}
