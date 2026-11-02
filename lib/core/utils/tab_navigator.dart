import 'package:flutter/material.dart';

/// タブ内ナビゲーションを統一するためのヘルパー。
///
/// 目的:
/// - **タブバーを常に見せる**（= タブ内のNavigatorでpush/popする）
/// - 意図せずrootNavigatorでpushしてタブバーが消える事故を防ぐ
class TabNavigator {
  TabNavigator._();

  /// タブ内で画面遷移します（タブバーは見えたまま）。
  ///
  /// 注意: `context` は **タブ内の画面ツリー**（MainTabPage配下）から渡してください。
  static Future<T?> push<T>(BuildContext context, Widget page) {
    return Navigator.of(
      context,
      rootNavigator: false,
    ).push<T>(MaterialPageRoute<T>(builder: (context) => page));
  }

  /// タブ内の前画面に戻ります。
  static void pop<T>(BuildContext context, [T? result]) {
    Navigator.of(context, rootNavigator: false).pop<T>(result);
  }

  /// タブ内スタックのルートまで戻ります。
  static void popUntilFirst(BuildContext context) {
    Navigator.of(context, rootNavigator: false).popUntil((r) => r.isFirst);
  }
}
