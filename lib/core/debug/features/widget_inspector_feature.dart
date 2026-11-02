import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:private_shelf/shared/widgets/dialogs/dialog_actions.dart';

import '../../feedback/snackbar_service.dart';
import '../dip_action_log.dart';
import '../dip_feature.dart';

/// Widgetインスペクターの状態Provider
final widgetInspectorProvider = StateProvider<WidgetInspectorState>(
  (ref) => const WidgetInspectorState(),
);

class WidgetInspectorState {
  const WidgetInspectorState({
    this.showRepaintRainbow = false,
    this.showDebugBanner = true,
    this.showSemanticsDebugger = false,
  });

  final bool showRepaintRainbow;
  final bool showDebugBanner;
  final bool showSemanticsDebugger;

  WidgetInspectorState copyWith({
    bool? showRepaintRainbow,
    bool? showDebugBanner,
    bool? showSemanticsDebugger,
  }) {
    return WidgetInspectorState(
      showRepaintRainbow: showRepaintRainbow ?? this.showRepaintRainbow,
      showDebugBanner: showDebugBanner ?? this.showDebugBanner,
      showSemanticsDebugger:
          showSemanticsDebugger ?? this.showSemanticsDebugger,
    );
  }
}

/// Widgetインスペクター機能
class WidgetInspectorFeature extends PanelDipFeature {
  @override
  String get id => 'widget_inspector';

  @override
  String get title => 'Widgetインスペクター';

  @override
  String? get subtitle => 'レイアウトデバッグ';

  @override
  IconData get icon => Icons.grid_on;

  @override
  DipFeatureCategory get category => DipFeatureCategory.debug;

  @override
  Widget? buildPanel(BuildContext context) {
    return const _WidgetInspectorPanel();
  }
}

class _WidgetInspectorPanel extends ConsumerWidget {
  const _WidgetInspectorPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(widgetInspectorProvider);
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 説明
        Card(
          color: theme.colorScheme.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'UIのデバッグに役立つオプションを切り替えられます',
                    style: TextStyle(
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        // オプション
        Text(
          'デバッグオプション',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.palette),
                title: const Text('Repaint Rainbow'),
                subtitle: const Text('再描画領域を色で表示'),
                value: state.showRepaintRainbow,
                onChanged: (value) {
                  debugRepaintRainbowEnabled = value;
                  ref.read(widgetInspectorProvider.notifier).state = state
                      .copyWith(showRepaintRainbow: value);
                  DipActionLog.info(
                    'Repaint Rainbow: ${value ? "ON" : "OFF"}',
                    tag: 'Debug',
                  );
                },
              ),
              const Divider(height: 1),
              SwitchListTile(
                secondary: const Icon(Icons.new_releases),
                title: const Text('デバッグバナー'),
                subtitle: const Text('右上のDEBUGバナー'),
                value: state.showDebugBanner,
                onChanged: (value) {
                  ref.read(widgetInspectorProvider.notifier).state = state
                      .copyWith(showDebugBanner: value);
                  DipActionLog.info(
                    'デバッグバナー: ${value ? "ON" : "OFF"}',
                    tag: 'Debug',
                  );
                },
              ),
              const Divider(height: 1),
              SwitchListTile(
                secondary: const Icon(Icons.accessibility),
                title: const Text('Semanticsデバッガー'),
                subtitle: Text(
                  state.showSemanticsDebugger
                      ? '有効（アプリ再起動でOFF）'
                      : 'アクセシビリティ情報を表示',
                ),
                value: state.showSemanticsDebugger,
                onChanged: (value) async {
                  if (value) {
                    // 有効化時は警告を表示
                    final confirmed = await _showSemanticsWarning(context);
                    if (!confirmed) return;
                  }
                  ref.read(widgetInspectorProvider.notifier).state = state
                      .copyWith(showSemanticsDebugger: value);
                  DipActionLog.info(
                    'Semanticsデバッガー: ${value ? "ON" : "OFF"}',
                    tag: 'Debug',
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        // 追加情報
        Text(
          'その他のツール',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.bug_report),
                title: const Text('Flutter DevTools'),
                subtitle: const Text('ブラウザでDevToolsを開く'),
                trailing: const Icon(Icons.open_in_new),
                onTap: () {
                  ref
                      .read(snackBarServiceProvider)
                      .info(
                        context: context,
                        message:
                            'コンソールでflutter pub global run devtoolsを実行してください',
                      );
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.analytics),
                title: const Text('Widget Tree'),
                subtitle: const Text('Widgetツリーを確認'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  _showWidgetTree(context);
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<bool> _showSemanticsWarning(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (dialogContext) => AlertDialog(
        actionsAlignment: MainAxisAlignment.spaceBetween,
        title: const Row(
          children: [
            Icon(Icons.warning_amber, color: Colors.orange),
            SizedBox(width: 8),
            Expanded(child: Text('Semanticsデバッガー')),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('注意: この機能を有効にすると、画面全体がアクセシビリティ情報で覆われ、通常の操作が困難になります。'),
            SizedBox(height: 16),
            Text('無効化する方法:', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('• アプリを再起動する（自動でOFFになります）'),
            Text('• または、このスイッチを再度タップしてOFFにする'),
          ],
        ),
        actions: [
          DialogActionRow(
            leading: DialogCloseButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              semanticLabel: 'キャンセル',
            ),
            trailing: ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
              child: const Text('有効にする'),
            ),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _showWidgetTree(BuildContext context) {
    showDialog<void>(
      context: context,
      useRootNavigator: true,
      builder: (dialogContext) => AlertDialog(
        actionsAlignment: MainAxisAlignment.spaceBetween,
        title: const Row(
          children: [
            Icon(Icons.account_tree),
            SizedBox(width: 8),
            Text('Widget Tree'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Flutter DevToolsを使用してWidgetツリーを確認してください。'),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(
                    dialogContext,
                  ).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(
                  '''# DevToolsの起動方法

# ターミナルで実行
flutter pub global activate devtools
flutter pub global run devtools

# または、VS Code/Android Studio の
# Flutter Extension から起動''',
                  style: Theme.of(
                    dialogContext,
                  ).textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }
}
