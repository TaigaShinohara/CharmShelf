import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'bottom_navigation_style.g.dart';

/// ボトムナビゲーションの見た目スタイル。
///
/// - simple: 現在のMaterial 3標準（NavigationBar）
/// - liquidGlass: iOS 26風（フローティング + 半透明 + ぼかし）
enum BottomNavigationStyle { simple, liquidGlass }

/// ボトムナビゲーションスタイルの選択状態。
///
/// 現状は「アプリ全体で1つ」の想定（タブごとに変えるとUXが崩れやすいため）。
@Riverpod(keepAlive: true)
class BottomNavigationStyleNotifier extends _$BottomNavigationStyleNotifier {
  @override
  BottomNavigationStyle build() => BottomNavigationStyle.simple;

  /// スタイルを切り替える
  void setStyle(BottomNavigationStyle style) {
    state = style;
  }
}
