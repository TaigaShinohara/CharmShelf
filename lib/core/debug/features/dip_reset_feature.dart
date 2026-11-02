import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:private_shelf/shared/widgets/dialogs/dialog_actions.dart';

import '../../feedback/snackbar_service.dart';
import '../dip_action_log.dart';
import '../dip_feature.dart';
import 'env_switch_feature.dart';
import 'locale_switch_feature.dart';
import 'performance_feature.dart';
import 'text_scale_feature.dart';
import 'theme_color_feature.dart';
import 'widget_inspector_feature.dart';

/// DIP設定リセット機能
///
/// DIPで変更した全ての設定をデフォルト値に戻します。
class DipResetFeature extends DipFeature {
  @override
  String get id => 'dip_reset';

  @override
  String get title => 'DIP設定をリセット';

  @override
  String? get subtitle => '全てのDIP設定をデフォルトに戻す';

  @override
  IconData get icon => Icons.restart_alt;

  @override
  DipFeatureCategory get category => DipFeatureCategory.debug;

  @override
  void onTap(BuildContext context) {
    // buildTileで処理
  }

  @override
  Widget buildTile(BuildContext context, {VoidCallback? onClose}) {
    final theme = Theme.of(context);

    return Consumer(
      builder: (context, ref, _) {
        return ListTile(
          leading: Icon(icon, color: theme.colorScheme.error),
          title: Text(title, style: TextStyle(color: theme.colorScheme.error)),
          subtitle: subtitle != null ? Text(subtitle!) : null,
          trailing: Icon(Icons.chevron_right, color: theme.colorScheme.error),
          onTap: () => _confirmReset(context, ref, onClose),
        );
      },
    );
  }

  Future<void> _confirmReset(
    BuildContext context,
    WidgetRef ref,
    VoidCallback? onClose,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (dialogContext) => AlertDialog(
        title: const Text('DIP設定をリセット'),
        content: const Text(
          '以下の設定がデフォルトに戻ります：\n\n'
          '• テーマカラー\n'
          '• テキストサイズ\n'
          '• 言語設定\n'
          '• 環境設定\n'
          '• パフォーマンスオーバーレイ\n'
          '• Widgetインスペクター設定\n'
          '• スローアニメーション\n\n'
          'この操作は取り消せません。',
        ),
        actions: [
          DialogActionRow(
            leading: DialogCloseButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              semanticLabel: 'キャンセル',
            ),
            trailing: TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(dialogContext).colorScheme.error,
              ),
              child: const Text('リセット'),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await _resetAllSettings(ref);

      DipActionLog.success('DIP設定をリセットしました', tag: 'DIP');

      if (context.mounted) {
        ref
            .read(snackBarServiceProvider)
            .success(context: context, message: 'DIP設定をリセットしました');
      }
    }
  }

  /// 全てのDIP設定をリセット
  Future<void> _resetAllSettings(WidgetRef ref) async {
    // SharedPreferencesのDIP関連キーを削除
    final prefs = await SharedPreferences.getInstance();
    final dipKeys = prefs.getKeys().where((key) => key.startsWith('dip_'));
    for (final key in dipKeys) {
      await prefs.remove(key);
    }

    // 各Providerをリセット
    // テーマカラー
    await ref.read(customThemeColorsProvider.notifier).reset();

    // テキストスケール
    await ref.read(textScaleProvider.notifier).setScale(1.0);

    // ロケール
    await ref.read(localeProvider.notifier).setLocale(null);

    // 環境
    await ref
        .read(appEnvironmentProvider.notifier)
        .setEnvironment(AppEnvironment.development);

    // パフォーマンスオーバーレイ
    ref.read(performanceOverlayProvider.notifier).state = false;

    // Widgetインスペクター
    ref.read(widgetInspectorProvider.notifier).state =
        const WidgetInspectorState();

    // スローアニメーション
    timeDilation = 1.0;
  }
}
