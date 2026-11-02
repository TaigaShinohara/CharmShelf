import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:private_shelf/core/theme/theme_provider.dart';
import 'package:private_shelf/gen_l10n/app_localizations.dart';
import 'package:private_shelf/shared/widgets/dialogs/selection_dialog.dart';

Future<void> showThemeSelectionDialog(
  BuildContext context,
  WidgetRef ref,
  ThemeMode currentMode,
) async {
  final l10n = AppLocalizations.of(context)!;

  final options = [
    SelectionOption<ThemeMode>(
      value: ThemeMode.system,
      title: l10n.dipThemeSwitchSystem,
      icon: Icons.brightness_auto_outlined,
    ),
    SelectionOption<ThemeMode>(
      value: ThemeMode.light,
      title: l10n.dipThemeSwitchLight,
      icon: Icons.light_mode_outlined,
    ),
    SelectionOption<ThemeMode>(
      value: ThemeMode.dark,
      title: l10n.dipThemeSwitchDark,
      icon: Icons.dark_mode_outlined,
    ),
  ];

  final selected = await showAppSelectionDialog<ThemeMode>(
    context,
    title: l10n.settingsTheme,
    options: options,
    selectedValue: currentMode,
  );

  if (selected != null) {
    await ref.read(themeModeAsyncProvider.notifier).setThemeMode(selected);
  }
}
