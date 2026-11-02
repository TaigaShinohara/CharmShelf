import 'package:flutter/material.dart';
import 'package:private_shelf/shared/widgets/feedback/app_snackbar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../config/app_config.dart';
import '../dip_action_log.dart';
import '../dip_controller.dart';
import '../dip_feature.dart';

/// カスタムテーマ色のProvider
final customThemeColorsProvider =
    StateNotifierProvider<CustomThemeColorsNotifier, CustomThemeColors>(
      (ref) => CustomThemeColorsNotifier(),
    );

/// カスタムテーマ色の状態
class CustomThemeColors {
  const CustomThemeColors({this.primaryColor, this.secondaryColor});

  /// カスタムプライマリ色（nullの場合はデフォルト）
  final Color? primaryColor;

  /// カスタムセカンダリ色（nullの場合はデフォルト）
  final Color? secondaryColor;

  /// デフォルト値を使用中かどうか
  bool get isDefault => primaryColor == null && secondaryColor == null;

  /// 実際に使用するプライマリ色
  Color get effectivePrimary =>
      primaryColor ?? Color(AppConfig.theme.primaryColor);

  /// 実際に使用するセカンダリ色
  Color get effectiveSecondary =>
      secondaryColor ?? Color(AppConfig.theme.secondaryColor);

  CustomThemeColors copyWith({
    Color? primaryColor,
    Color? secondaryColor,
    bool clearPrimary = false,
    bool clearSecondary = false,
  }) {
    return CustomThemeColors(
      primaryColor: clearPrimary ? null : (primaryColor ?? this.primaryColor),
      secondaryColor: clearSecondary
          ? null
          : (secondaryColor ?? this.secondaryColor),
    );
  }
}

class CustomThemeColorsNotifier extends StateNotifier<CustomThemeColors> {
  CustomThemeColorsNotifier() : super(const CustomThemeColors()) {
    _load();
  }

  static const _primaryKey = 'dip_theme_primary';
  static const _secondaryKey = 'dip_theme_secondary';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final primaryValue = prefs.getInt(_primaryKey);
    final secondaryValue = prefs.getInt(_secondaryKey);

    state = CustomThemeColors(
      primaryColor: primaryValue != null ? Color(primaryValue) : null,
      secondaryColor: secondaryValue != null ? Color(secondaryValue) : null,
    );
  }

  Future<void> setPrimaryColor(Color? color) async {
    state = state.copyWith(primaryColor: color, clearPrimary: color == null);
    final prefs = await SharedPreferences.getInstance();
    if (color != null) {
      await prefs.setInt(_primaryKey, color.toARGB32());
    } else {
      await prefs.remove(_primaryKey);
    }
  }

  Future<void> setSecondaryColor(Color? color) async {
    state = state.copyWith(
      secondaryColor: color,
      clearSecondary: color == null,
    );
    final prefs = await SharedPreferences.getInstance();
    if (color != null) {
      await prefs.setInt(_secondaryKey, color.toARGB32());
    } else {
      await prefs.remove(_secondaryKey);
    }
  }

  Future<void> reset() async {
    state = const CustomThemeColors();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_primaryKey);
    await prefs.remove(_secondaryKey);
  }
}

/// テーマカラー変更機能
class ThemeColorFeature extends DipFeature {
  @override
  String get id => 'theme_color';

  @override
  String get title => 'テーマカラー';

  @override
  String? get subtitle => 'プライマリ/セカンダリ色を変更';

  @override
  IconData get icon => Icons.color_lens;

  @override
  DipFeatureCategory get category => DipFeatureCategory.ui;

  @override
  bool get showInSettings => true;

  @override
  void onTap(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      builder: (context) => const _ThemeColorSheet(),
    );
  }

  @override
  Widget buildTile(BuildContext context, {VoidCallback? onClose}) {
    return Consumer(
      builder: (context, ref, _) {
        final colors = ref.watch(customThemeColorsProvider);
        final theme = Theme.of(context);

        return ListTile(
          leading: Icon(icon, color: theme.colorScheme.primary),
          title: Text(title),
          subtitle: Row(
            children: [
              _ColorDot(color: colors.effectivePrimary),
              const SizedBox(width: 4),
              _ColorDot(color: colors.effectiveSecondary),
              const SizedBox(width: 8),
              Text(
                colors.isDefault ? 'デフォルト' : 'カスタム',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () async {
            // DIPを閉じてからモーダルを表示
            onClose?.call();

            await showModalBottomSheet<void>(
              context: context,
              useRootNavigator: true,
              isScrollControlled: true,
              builder: (context) => const _ThemeColorSheet(),
            );

            // モーダルが閉じたらDIPを再表示
            WidgetsBinding.instance.addPostFrameCallback((_) {
              DipController.showWithLastOverlay();
            });
          },
        );
      },
    );
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
        ),
      ),
    );
  }
}

class _ThemeColorSheet extends ConsumerStatefulWidget {
  const _ThemeColorSheet();

  @override
  ConsumerState<_ThemeColorSheet> createState() => _ThemeColorSheetState();
}

class _ThemeColorSheetState extends ConsumerState<_ThemeColorSheet> {
  @override
  Widget build(BuildContext context) {
    final colors = ref.watch(customThemeColorsProvider);
    final theme = Theme.of(context);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ハンドル
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outline.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            // タイトル
            Text(
              'テーマカラー',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'template_config.yamlを編集するとデフォルト値が変更されます',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            // プレビュー
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('プレビュー', style: theme.textTheme.titleSmall),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              final messenger = AppSnackBarMessenger.maybeOf(
                                context,
                              );
                              messenger?.showSnackBar(
                                const SnackBar(content: Text('プレビュー用のボタンです')),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: colors.effectivePrimary,
                              foregroundColor: _contrastColor(
                                colors.effectivePrimary,
                              ),
                            ),
                            child: const Text('Primary'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              final messenger = AppSnackBarMessenger.maybeOf(
                                context,
                              );
                              messenger?.showSnackBar(
                                const SnackBar(content: Text('プレビュー用のボタンです')),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: colors.effectiveSecondary,
                              foregroundColor: _contrastColor(
                                colors.effectiveSecondary,
                              ),
                            ),
                            child: const Text('Secondary'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            // プライマリカラー選択
            _ColorSection(
              title: 'プライマリカラー',
              currentColor: colors.effectivePrimary,
              defaultColor: Color(AppConfig.theme.primaryColor),
              isCustom: colors.primaryColor != null,
              onColorSelected: (color) {
                ref
                    .read(customThemeColorsProvider.notifier)
                    .setPrimaryColor(color);
                DipActionLog.info(
                  'プライマリカラー変更: #${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}',
                  tag: 'Theme',
                );
              },
              onReset: () {
                ref
                    .read(customThemeColorsProvider.notifier)
                    .setPrimaryColor(null);
                DipActionLog.info('プライマリカラーをリセット', tag: 'Theme');
              },
            ),
            const SizedBox(height: 16),
            // セカンダリカラー選択
            _ColorSection(
              title: 'セカンダリカラー',
              currentColor: colors.effectiveSecondary,
              defaultColor: Color(AppConfig.theme.secondaryColor),
              isCustom: colors.secondaryColor != null,
              onColorSelected: (color) {
                ref
                    .read(customThemeColorsProvider.notifier)
                    .setSecondaryColor(color);
                DipActionLog.info(
                  'セカンダリカラー変更: #${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}',
                  tag: 'Theme',
                );
              },
              onReset: () {
                ref
                    .read(customThemeColorsProvider.notifier)
                    .setSecondaryColor(null);
                DipActionLog.info('セカンダリカラーをリセット', tag: 'Theme');
              },
            ),
            const SizedBox(height: 24),
            // リセットボタン
            if (!colors.isDefault)
              OutlinedButton.icon(
                onPressed: () {
                  ref.read(customThemeColorsProvider.notifier).reset();
                  DipActionLog.info('テーマカラーを全てリセット', tag: 'Theme');
                },
                icon: const Icon(Icons.restore),
                label: const Text('全てデフォルトに戻す'),
              ),
          ],
        ),
      ),
    );
  }

  Color _contrastColor(Color color) {
    final luminance = color.computeLuminance();
    return luminance > 0.5 ? Colors.black : Colors.white;
  }
}

class _ColorSection extends StatelessWidget {
  const _ColorSection({
    required this.title,
    required this.currentColor,
    required this.defaultColor,
    required this.isCustom,
    required this.onColorSelected,
    required this.onReset,
  });

  final String title;
  final Color currentColor;
  final Color defaultColor;
  final bool isCustom;
  final ValueChanged<Color> onColorSelected;
  final VoidCallback onReset;

  // プリセットカラー
  static const _presetColors = [
    Color(0xFF6366F1), // Indigo
    Color(0xFF8B5CF6), // Violet
    Color(0xFFEC4899), // Pink
    Color(0xFFEF4444), // Red
    Color(0xFFF97316), // Orange
    Color(0xFFF59E0B), // Amber
    Color(0xFF10B981), // Emerald
    Color(0xFF14B8A6), // Teal
    Color(0xFF06B6D4), // Cyan
    Color(0xFF3B82F6), // Blue
    Color(0xFF6B7280), // Gray
    Color(0xFF1F2937), // Dark
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            if (isCustom)
              TextButton(onPressed: onReset, child: const Text('リセット')),
          ],
        ),
        const SizedBox(height: 8),
        // 現在の色表示
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: currentColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: theme.colorScheme.outline.withValues(alpha: 0.3),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '#${currentColor.toARGB32().toRadixString(16).substring(2).toUpperCase()}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    isCustom ? 'カスタム' : 'デフォルト (template_config.yaml)',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // プリセットカラー
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final color in _presetColors)
              _ColorButton(
                color: color,
                isSelected: currentColor.toARGB32() == color.toARGB32(),
                onTap: () => onColorSelected(color),
              ),
          ],
        ),
      ],
    );
  }
}

class _ColorButton extends StatelessWidget {
  const _ColorButton({
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Colors.transparent,
            width: 3,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.4),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: isSelected
            ? Icon(
                Icons.check,
                color: color.computeLuminance() > 0.5
                    ? Colors.black
                    : Colors.white,
                size: 20,
              )
            : null,
      ),
    );
  }
}
