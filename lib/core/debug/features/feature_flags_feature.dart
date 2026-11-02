import 'package:flutter/material.dart';

import '../../config/app_config.dart';
import '../dip_feature.dart';

/// FeatureFlagsトグル機能
class FeatureFlagsFeature extends PanelDipFeature {
  @override
  String get id => 'feature_flags';

  @override
  String get title => 'Feature Flags';

  @override
  String? get subtitle => '機能ON/OFF確認';

  @override
  IconData get icon => Icons.flag_outlined;

  @override
  DipFeatureCategory get category => DipFeatureCategory.debug;

  @override
  Widget? buildPanel(BuildContext context) {
    return const _FeatureFlagsPanel();
  }
}

class _FeatureFlagsPanel extends StatelessWidget {
  const _FeatureFlagsPanel();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const features = AppConfig.features;

    final flags = <_FlagInfo>[
      _FlagInfo('tabBarEnabled', 'タブバー', features.tabBarEnabled),
      _FlagInfo('localAuthEnabled', 'ローカル認証', features.localAuthEnabled),
      _FlagInfo('onboardingEnabled', 'オンボーディング', features.onboardingEnabled),
      _FlagInfo('appReviewEnabled', 'アプリレビュー', features.appReviewEnabled),
      _FlagInfo('tutorialEnabled', 'チュートリアル', features.tutorialEnabled),
      _FlagInfo('forceUpdateEnabled', '強制アップデート', features.forceUpdateEnabled),
      _FlagInfo('deepLinkEnabled', 'ディープリンク', features.deepLinkEnabled),
      _FlagInfo('darkModeEnabled', 'ダークモード', features.darkModeEnabled),
      _FlagInfo('i18nEnabled', '多言語対応', features.i18nEnabled),
      _FlagInfo('hapticsEnabled', 'ハプティクス', features.hapticsEnabled),
      _FlagInfo('soundEnabled', 'サウンド', features.soundEnabled),
      _FlagInfo('dipEnabled', 'DIP', features.dipEnabled),
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 説明カード
        Card(
          color: theme.colorScheme.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Feature Flags',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'これらのフラグはビルド時に固定されています。\n'
                  '変更するには template_config.yaml を編集して再ビルドしてください。',
                  style: TextStyle(color: theme.colorScheme.onPrimaryContainer),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        // フラグ一覧
        Text(
          '現在の設定',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              for (int i = 0; i < flags.length; i++) ...[
                if (i > 0) const Divider(height: 1),
                _FlagTile(flag: flags[i]),
              ],
            ],
          ),
        ),
        const SizedBox(height: 24),
        // その他の設定
        Text(
          'その他の設定',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const _ConfigRow(label: 'アプリ名', value: AppConfig.appName),
                const _ConfigRow(label: 'パッケージ名', value: AppConfig.packageName),
                const _ConfigRow(label: '最小年齢', value: '${AppConfig.minAge}歳'),
                _ConfigRow(
                  label: 'ディープリンクスキーム',
                  value: features.deepLinkScheme,
                ),
                const _ConfigRow(
                  label: 'テキストスケール上限',
                  value: '${AppConfig.textScaleMax}',
                ),
                const _ConfigRow(label: '画面方向', value: AppConfig.orientation),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _FlagInfo {
  _FlagInfo(this.key, this.label, this.enabled);

  final String key;
  final String label;
  final bool enabled;
}

class _FlagTile extends StatelessWidget {
  const _FlagTile({required this.flag});

  final _FlagInfo flag;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      title: Text(flag.label),
      subtitle: Text(
        flag.key,
        style: theme.textTheme.bodySmall?.copyWith(
          fontFamily: 'monospace',
          color: theme.colorScheme.outline,
        ),
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: flag.enabled
              ? Colors.green.withValues(alpha: 0.1)
              : Colors.grey.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          flag.enabled ? 'ON' : 'OFF',
          style: TextStyle(
            color: flag.enabled ? Colors.green : Colors.grey,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class _ConfigRow extends StatelessWidget {
  const _ConfigRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
                fontFamily: 'monospace',
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}
