import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/theme_provider.dart';
import '../dip_action_log.dart';
import '../dip_feature.dart';

/// テーマ切り替え機能
class ThemeSwitchFeature extends DipFeature {
  @override
  String get id => 'theme_switch';

  @override
  String get title => 'テーマ切り替え';

  @override
  String? get subtitle => 'ライト/ダーク/システム';

  @override
  IconData get icon => Icons.brightness_6_outlined;

  @override
  DipFeatureCategory get category => DipFeatureCategory.ui;

  @override
  bool get showInSettings => true;

  @override
  void onTap(BuildContext context) {
    // 何もしない（タイルで直接切り替え）
  }

  @override
  Widget buildTile(BuildContext context, {VoidCallback? onClose}) {
    return Consumer(
      builder: (context, ref, _) {
        final themeMode = ref.watch(themeModeProvider);
        final theme = Theme.of(context);

        return ListTile(
          leading: Icon(icon, color: theme.colorScheme.primary),
          title: Text(title),
          subtitle: Text(_getThemeLabel(themeMode)),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ThemeButton(
                icon: Icons.light_mode,
                isSelected: themeMode == ThemeMode.light,
                onPressed: () => _setTheme(ref, ThemeMode.light),
              ),
              _ThemeButton(
                icon: Icons.dark_mode,
                isSelected: themeMode == ThemeMode.dark,
                onPressed: () => _setTheme(ref, ThemeMode.dark),
              ),
              _ThemeButton(
                icon: Icons.settings_suggest,
                isSelected: themeMode == ThemeMode.system,
                onPressed: () => _setTheme(ref, ThemeMode.system),
              ),
            ],
          ),
        );
      },
    );
  }

  String _getThemeLabel(ThemeMode mode) {
    return switch (mode) {
      ThemeMode.light => 'ライト',
      ThemeMode.dark => 'ダーク',
      ThemeMode.system => 'システム設定',
    };
  }

  void _setTheme(WidgetRef ref, ThemeMode mode) {
    ref.read(themeModeAsyncProvider.notifier).setThemeMode(mode);
    DipActionLog.info('テーマ変更: ${_getThemeLabel(mode)}', tag: 'UI');
  }
}

class _ThemeButton extends StatelessWidget {
  const _ThemeButton({
    required this.icon,
    required this.isSelected,
    required this.onPressed,
  });

  final IconData icon;
  final bool isSelected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return IconButton(
      icon: Icon(icon),
      color: isSelected ? theme.colorScheme.primary : theme.colorScheme.outline,
      style: isSelected
          ? IconButton.styleFrom(
              backgroundColor: theme.colorScheme.primaryContainer,
            )
          : null,
      onPressed: onPressed,
    );
  }
}
