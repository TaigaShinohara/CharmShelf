import 'package:flutter/material.dart';

import '../../gen_l10n/app_localizations.dart';
import 'dip_feature.dart';

/// DIPメニューのUI
class DipMenu extends StatelessWidget {
  const DipMenu({required this.features, required this.onClose, super.key});

  final Map<DipFeatureCategory, List<DipFeature>> features;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ハンドル
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.outline.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        // ヘッダー
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Icon(Icons.developer_mode, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                l10n?.dipPanelTitle ?? 'DIP - Developer Panel',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              IconButton(icon: const Icon(Icons.close), onPressed: onClose),
            ],
          ),
        ),
        const Divider(),
        // 機能リスト
        Flexible(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.only(bottom: 16),
            children: [
              for (final category in DipFeatureCategory.values)
                if (features.containsKey(category) &&
                    features[category]!.isNotEmpty)
                  _CategorySection(
                    category: category,
                    features: features[category]!,
                    onClose: onClose,
                  ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CategorySection extends StatelessWidget {
  const _CategorySection({
    required this.category,
    required this.features,
    required this.onClose,
  });

  final DipFeatureCategory category;
  final List<DipFeature> features;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Icon(category.icon, size: 18, color: theme.colorScheme.secondary),
              const SizedBox(width: 8),
              Text(
                category.label(context),
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.secondary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        ...features.map(
          (feature) => feature.buildTile(context, onClose: onClose),
        ),
      ],
    );
  }
}
