import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:private_shelf/features/settings/presentation/providers/locale_provider.dart';
import 'package:private_shelf/gen_l10n/app_localizations.dart';
import 'package:private_shelf/shared/widgets/dialogs/selection_dialog.dart';

Future<void> showLanguageSelectionDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  final l10n = AppLocalizations.of(context)!;
  final currentLocale = ref.read(appLocaleProvider);
  final currentCode = currentLocale == null
      ? 'system'
      : currentLocale.languageCode;

  final options = [
    SelectionOption<String>(
      value: 'system',
      title: l10n.settingsLanguageSystem,
      icon: Icons.settings_suggest_outlined,
    ),
    SelectionOption<String>(
      value: 'ja',
      title: l10n.settingsLanguageJa,
      icon: Icons.translate_outlined,
    ),
    SelectionOption<String>(
      value: 'en',
      title: l10n.settingsLanguageEn,
      icon: Icons.language_outlined,
    ),
  ];

  final selected = await showAppSelectionDialog<String>(
    context,
    title: l10n.settingsLanguage,
    options: options,
    selectedValue: currentCode,
  );

  if (selected != null) {
    final newLocale = selected == 'system' ? null : Locale(selected);
    await ref.read(appLocaleAsyncProvider.notifier).setLocale(newLocale);
  }
}
