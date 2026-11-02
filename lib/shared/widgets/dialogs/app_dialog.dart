import 'package:flutter/material.dart';

import '../widgets.dart';

/// カスタムコンテンツ対応の汎用ダイアログ。
///
/// 目的:
/// - 「アプリ側から要求される確認/入力/説明」などを統一した枠で出す
/// - 中身（child）を差し替え可能にする
class AppDialog extends StatelessWidget {
  const AppDialog({
    super.key,
    this.title,
    required this.child,
    this.actions,
    this.contentPadding = const EdgeInsets.fromLTRB(24, 16, 24, 8),
  });

  final String? title;
  final Widget child;
  final List<Widget>? actions;
  final EdgeInsets contentPadding;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: title == null ? null : AppText(title!),
      contentPadding: contentPadding,
      content: child,
      actions: actions,
    );
  }
}

Future<T?> showAppDialog<T>(
  BuildContext context, {
  String? title,
  required Widget child,
  List<Widget>? actions,
  bool barrierDismissible = false,
  bool useRootNavigator = false,
}) {
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    useRootNavigator: useRootNavigator,
    builder: (context) =>
        AppDialog(title: title, actions: actions, child: child),
  );
}
