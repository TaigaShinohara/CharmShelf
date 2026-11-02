import 'package:flutter/material.dart';

import '../../gen_l10n/app_localizations.dart';
import 'dip_controller.dart';

/// DIP機能のカテゴリ
enum DipFeatureCategory {
  info(Icons.info_outline, '情報表示'),
  data(Icons.storage_outlined, 'データ操作'),
  ui(Icons.palette_outlined, 'UI/UX調整'),
  debug(Icons.bug_report_outlined, '開発・デバッグ'),
  test(Icons.science_outlined, 'テスト');

  const DipFeatureCategory(this.icon, this.fallbackLabel);
  final IconData icon;

  /// ローカライゼーションが利用できない場合のフォールバックラベル
  final String fallbackLabel;

  /// カテゴリのラベルを取得
  ///
  /// ローカライゼーションが利用可能な場合はローカライズされたラベルを返し、
  /// 利用できない場合はフォールバックラベルを返します。
  String label(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (l10n == null) return fallbackLabel;

    return switch (this) {
      DipFeatureCategory.info => l10n.dipCategoryInfo,
      DipFeatureCategory.data => l10n.dipCategoryData,
      DipFeatureCategory.ui => l10n.dipCategoryUi,
      DipFeatureCategory.debug => l10n.dipCategoryDebug,
      DipFeatureCategory.test => l10n.dipCategoryTest,
    };
  }
}

/// DIP機能の基底クラス
///
/// 各デバッグ機能はこのクラスを継承して実装します。
/// [showInDip] と [showInSettings] を変更することで、
/// 同じ機能をDIPメニューと設定画面の両方で使い回せます。
abstract class DipFeature {
  /// 一意の識別子
  String get id;

  /// 表示名
  String get title;

  /// サブタイトル（オプション）
  String? get subtitle => null;

  /// アイコン
  IconData get icon;

  /// カテゴリ
  DipFeatureCategory get category;

  /// DIPメニューに表示するか
  bool get showInDip => true;

  /// 設定画面に表示するか
  bool get showInSettings => false;

  /// タイルウィジェットを構築（設定画面互換）
  Widget buildTile(BuildContext context, {VoidCallback? onClose});

  /// 詳細パネルを構築（オプション）
  Widget? buildPanel(BuildContext context) => null;

  /// タップ時の処理
  void onTap(BuildContext context);
}

/// シンプルなタップアクション用のDIP機能
///
/// 詳細パネルを持たない単純なアクション機能に使用します。
abstract class SimpleDipFeature extends DipFeature {
  @override
  Widget buildTile(BuildContext context, {VoidCallback? onClose}) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Icon(icon, color: theme.colorScheme.primary),
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle!) : null,
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        onTap(context);
        onClose?.call();
      },
    );
  }
}

/// トグル（ON/OFF）切り替え用のDIP機能
abstract class ToggleDipFeature extends DipFeature {
  /// 現在の状態を取得
  bool getValue(BuildContext context);

  /// 状態を設定
  void setValue(BuildContext context, bool value);

  @override
  void onTap(BuildContext context) {
    setValue(context, !getValue(context));
  }

  @override
  Widget buildTile(BuildContext context, {VoidCallback? onClose}) {
    final theme = Theme.of(context);
    return StatefulBuilder(
      builder: (context, setState) {
        return SwitchListTile(
          secondary: Icon(icon, color: theme.colorScheme.primary),
          title: Text(title),
          subtitle: subtitle != null ? Text(subtitle!) : null,
          value: getValue(context),
          onChanged: (value) {
            setValue(context, value);
            setState(() {});
          },
        );
      },
    );
  }
}

/// 選択肢から選ぶタイプのDIP機能
abstract class SelectionDipFeature<T> extends DipFeature {
  /// 選択肢リスト
  List<T> get options;

  /// 選択肢のラベルを取得
  String getLabel(T option);

  /// 現在の選択値を取得
  T getValue(BuildContext context);

  /// 選択値を設定
  void setValue(BuildContext context, T value);

  @override
  void onTap(BuildContext context) {
    _showSelectionDialog(context);
  }

  Future<void> _showSelectionDialog(BuildContext context) async {
    // DIPはOverlayとして表示されているため、rootNavigatorを使用
    final result = await showDialog<T>(
      context: context,
      useRootNavigator: true,
      builder: (dialogContext) => SimpleDialog(
        title: Text(title),
        children: options.map((option) {
          final isSelected = option == getValue(context);
          return SimpleDialogOption(
            onPressed: () => Navigator.pop(dialogContext, option),
            child: Row(
              children: [
                if (isSelected)
                  Icon(
                    Icons.check,
                    color: Theme.of(dialogContext).colorScheme.primary,
                  )
                else
                  const SizedBox(width: 24),
                const SizedBox(width: 8),
                Text(getLabel(option)),
              ],
            ),
          );
        }).toList(),
      ),
    );

    if (result != null && context.mounted) {
      setValue(context, result);
    }
  }

  @override
  Widget buildTile(BuildContext context, {VoidCallback? onClose}) {
    final theme = Theme.of(context);
    return StatefulBuilder(
      builder: (context, setState) {
        return ListTile(
          leading: Icon(icon, color: theme.colorScheme.primary),
          title: Text(title),
          subtitle: Text(getLabel(getValue(context))),
          trailing: const Icon(Icons.chevron_right),
          onTap: () async {
            await _showSelectionDialog(context);
            setState(() {});
          },
        );
      },
    );
  }
}

/// 詳細パネルを持つDIP機能
abstract class PanelDipFeature extends DipFeature {
  @override
  Widget buildTile(BuildContext context, {VoidCallback? onClose}) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Icon(icon, color: theme.colorScheme.primary),
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle!) : null,
      trailing: const Icon(Icons.chevron_right),
      onTap: () async {
        // rootNavigatorを事前に取得（DIPを閉じる前に）
        final navigator = Navigator.of(context, rootNavigator: true);

        // DIPを閉じてから遷移
        onClose?.call();

        // パネルに遷移して戻りを待つ
        await navigator.push(
          MaterialPageRoute<void>(
            builder: (navContext) => Scaffold(
              appBar: AppBar(title: Text(title)),
              body: buildPanel(navContext),
            ),
          ),
        );

        // 戻ってきたらDIPを再表示（次フレームで実行）
        // showWithLastOverlay()を使用して、保存されたOverlayを再利用
        WidgetsBinding.instance.addPostFrameCallback((_) {
          DipController.showWithLastOverlay();
        });
      },
    );
  }

  @override
  void onTap(BuildContext context) {
    // buildTileで処理されるため、ここでは何もしない
  }
}
