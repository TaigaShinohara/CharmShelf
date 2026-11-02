import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:private_shelf/features/library/presentation/providers/library_view_settings_provider.dart';
import 'package:private_shelf/gen_l10n/app_localizations.dart';
import 'package:private_shelf/shared/widgets/dialogs/selection_dialog.dart';

Future<void> showViewerPageDirectionDialog(
  BuildContext context,
  WidgetRef ref,
  ViewerPageDirection currentDirection,
) async {
  final l10n = AppLocalizations.of(context)!;
  final selected = await showAppSelectionDialog<ViewerPageDirection>(
    context,
    title: l10n.settingsViewerPageDirection,
    options: [
      SelectionOption<ViewerPageDirection>(
        value: ViewerPageDirection.leftToRight,
        title: l10n.settingsViewerPageDirectionLeftToRight,
        icon: Icons.arrow_forward,
      ),
      SelectionOption<ViewerPageDirection>(
        value: ViewerPageDirection.rightToLeft,
        title: l10n.settingsViewerPageDirectionRightToLeft,
        icon: Icons.arrow_back,
      ),
    ],
    selectedValue: currentDirection,
  );

  if (selected != null) {
    await ref
        .read(viewerPageDirectionAsyncProvider.notifier)
        .setValue(selected);
  }
}
