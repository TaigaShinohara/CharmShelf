import 'package:flutter/material.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../../../gen_l10n/app_localizations.dart';
import 'catalog_registration_icon.dart';

/// ホームとライブラリで共有する、フォルダ／ファイル取り込みボタン。
class LibraryImportButton extends StatelessWidget {
  const LibraryImportButton.folder({super.key, required this.onPressed})
    : isFolder = true;

  const LibraryImportButton.file({super.key, required this.onPressed})
    : isFolder = false;

  final VoidCallback? onPressed;
  final bool isFolder;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
      child: Builder(
        builder: (context) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            isFolder
                ? CatalogRegistrationIcon.folder(
                    color: IconTheme.of(context).color,
                  )
                : CatalogRegistrationIcon.file(
                    color: IconTheme.of(context).color,
                  ),
            AppSpacing.gapHorizontalSm,
            Flexible(
              child: Text(
                isFolder ? l10n.libraryImportFolder : l10n.libraryImportFile,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
