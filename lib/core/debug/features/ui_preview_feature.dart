import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/dialogs/app_dialog.dart';
import '../../../shared/widgets/dialogs/confirm_dialog.dart';
import '../../../shared/widgets/dialogs/input_dialog.dart';
import '../../../shared/widgets/dialogs/paged_dialog.dart';
import '../../../shared/widgets/navigation/bottom_navigation_style.dart';
import '../../../shared/widgets/notifications/in_app_notification.dart';
import '../../../shared/widgets/overlays/fullscreen_cutscene.dart';
import '../../../shared/widgets/sheets/action_bottom_sheet.dart';
import '../../../shared/widgets/sheets/app_bottom_sheet.dart';
import '../../../shared/widgets/sheets/paged_bottom_sheet.dart';
import '../../feedback/snackbar_config.dart';
import '../../feedback/snackbar_service.dart';
import '../dip_feature.dart';

/// UI確認用（UI Preview）機能
///
/// 設定画面のDIPセクションから起動して、
/// テンプレが提供する共通UI（ダイアログ/モーダル/通知/カットシーン等）を確認できます。
class UiPreviewFeature extends SimpleDipFeature {
  @override
  String get id => 'ui_preview';

  @override
  String get title => 'UI確認';

  @override
  String? get subtitle => '共通UIをまとめてプレビュー';

  @override
  IconData get icon => Icons.preview_outlined;

  @override
  DipFeatureCategory get category => DipFeatureCategory.ui;

  @override
  bool get showInSettings => true;

  @override
  void onTap(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const _UiPreviewPage()));
  }
}

class _UiPreviewPage extends ConsumerWidget {
  const _UiPreviewPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final style = ref.watch(bottomNavigationStyleNotifierProvider);
    final snackBarService = ref.read(snackBarServiceProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('UI確認（Preview）')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _Header(
            title: 'ボトムバー',
            subtitle: '2種類（Simple / LiquidGlass）を切り替え',
            icon: Icons.space_dashboard_outlined,
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SegmentedButton<BottomNavigationStyle>(
                    segments: const [
                      ButtonSegment(
                        value: BottomNavigationStyle.simple,
                        label: Text('Simple'),
                      ),
                      ButtonSegment(
                        value: BottomNavigationStyle.liquidGlass,
                        label: Text('LiquidGlass'),
                      ),
                    ],
                    selected: {style},
                    onSelectionChanged: (s) => ref
                        .read(bottomNavigationStyleNotifierProvider.notifier)
                        .setStyle(s.first),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'この画面を閉じてタブバーを見ると、見た目が切り替わります。',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          const _Header(
            title: 'ダイアログ（アプリから要求される体験）',
            subtitle: 'タブ内 / グローバル（タブ操作不可）の2種類を確認',
            icon: Icons.chat_bubble_outline,
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton(
                    onPressed: () => showConfirmDialog(
                      context,
                      title: 'タブ内ダイアログ',
                      message: 'これはタブ内（ローカル）で表示されます。',
                      useRootNavigator: false,
                    ),
                    child: const Text('確認ダイアログ（タブ内）'),
                  ),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: () => showConfirmDialog(
                      context,
                      title: 'グローバルダイアログ',
                      message: 'これはグローバル（rootNavigator）で表示されます。',
                      useRootNavigator: true,
                    ),
                    child: const Text('確認ダイアログ（グローバル）'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () async {
                      final v = await showInputDialog(
                        context,
                        title: '入力ダイアログ',
                        message: '何か入力してください',
                        useRootNavigator: false,
                      );
                      if (!context.mounted) return;
                      snackBarService.show(
                        context: context,
                        message: '入力: ${v ?? "(キャンセル)"}',
                        type: SnackBarType.info,
                      );
                    },
                    child: const Text('入力ダイアログ'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () => showAppDialog<void>(
                      context,
                      title: 'AppDialog（汎用）',
                      useRootNavigator: false,
                      child: const Text('中身は自由に差し替えできます。'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('閉じる'),
                        ),
                      ],
                    ),
                    child: const Text('汎用ダイアログ（AppDialog）'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () => showPagedDialog(
                      context,
                      title: 'ページ送りダイアログ',
                      pages: const [
                        Center(child: Text('ページ1')),
                        Center(child: Text('ページ2')),
                        Center(child: Text('ページ3')),
                      ],
                      useRootNavigator: false,
                    ),
                    child: const Text('ページ送りダイアログ'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          const _Header(
            title: 'ボトムシート（ユーザーが探索する体験）',
            subtitle: '選択/詳細/ページ送り',
            icon: Icons.vertical_align_bottom_outlined,
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton(
                    onPressed: () async {
                      final v = await showActionBottomSheet<String>(
                        context,
                        title: '選択してください',
                        items: const [
                          ActionSheetItem(
                            label: 'A',
                            value: 'A',
                            icon: Icons.looks_one_outlined,
                          ),
                          ActionSheetItem(
                            label: 'B',
                            value: 'B',
                            icon: Icons.looks_two_outlined,
                          ),
                        ],
                      );
                      if (!context.mounted) return;
                      snackBarService.info(
                        context: context,
                        message: '選択: ${v ?? "(キャンセル)"}',
                      );
                    },
                    child: const Text('アクション選択（ActionBottomSheet）'),
                  ),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: () => showAppBottomSheet<void>(
                      context,
                      title: 'AppBottomSheet（汎用）',
                      child: const Text('中身は自由に差し替えできます。'),
                    ),
                    child: const Text('汎用ボトムシート'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () => showPagedBottomSheet(
                      context,
                      title: 'ページ送りボトムシート',
                      pages: const [
                        Center(child: Text('ページ1')),
                        Center(child: Text('ページ2')),
                        Center(child: Text('ページ3')),
                      ],
                    ),
                    child: const Text('ページ送りボトムシート'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          const _Header(
            title: '通知（Snackbar / アプリ内通知バー）',
            subtitle: '軽いフィードバック / 上部バナー',
            icon: Icons.notifications_outlined,
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton(
                    onPressed: () => snackBarService.success(
                      context: context,
                      message: 'SnackBar（成功）',
                    ),
                    child: const Text('SnackBar（成功）'),
                  ),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: () => snackBarService.error(
                      context: context,
                      message: 'SnackBar（エラー）',
                    ),
                    child: const Text('SnackBar（エラー）'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () => InAppNotification.showNotification(
                      context,
                      title: 'アプリ内通知バー',
                      body: 'これは上部バナーとして表示されます。',
                      onTap: () {
                        snackBarService.show(
                          context: context,
                          message: '通知バーをタップしました',
                          type: SnackBarType.info,
                        );
                      },
                    ),
                    child: const Text('アプリ内通知バー'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          const _Header(
            title: 'フルスクリーンカットシーン',
            subtitle: '全画面を覆うローディング/演出',
            icon: Icons.movie_creation_outlined,
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton(
                    onPressed: () async {
                      // デフォルトで2秒自動終了（残り秒数表示）する想定
                      FullscreenCutscene.showLoading(
                        context,
                        message: 'ロード中…（自動で閉じます）',
                      );
                    },
                    child: const Text('ローディング（2秒）'),
                  ),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: () => FullscreenCutscene.show(
                      context,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Text('カスタムカットシーン'),
                      ),
                    ),
                    child: const Text('カスタムカットシーン'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () => FullscreenCutscene.hide(),
                    child: const Text('カットシーンを閉じる'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 48),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
