import 'package:flutter/material.dart';
import 'package:private_shelf/gen_l10n/app_localizations.dart';

enum ViewerFailureKind {
  missing,
  permissionDenied,
  unsupported,
  decodeFailed,
  playbackFailed,
  unknown,
}

class ViewerStatePanel extends StatelessWidget {
  const ViewerStatePanel({
    super.key,
    required this.kind,
    this.message,
    this.onRetry,
    this.onOpenExternal,
    this.onShare,
    this.onBack,
  });

  final ViewerFailureKind kind;
  final String? message;
  final VoidCallback? onRetry;
  final VoidCallback? onOpenExternal;
  final VoidCallback? onShare;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final title = switch (kind) {
      ViewerFailureKind.missing => l10n.viewerFileNotFound,
      ViewerFailureKind.permissionDenied => l10n.viewerPermissionDenied,
      ViewerFailureKind.unsupported => l10n.viewerUnsupportedFileType,
      ViewerFailureKind.decodeFailed => l10n.viewerDecodeFailed,
      ViewerFailureKind.playbackFailed => l10n.viewerPlaybackFailed,
      ViewerFailureKind.unknown => l10n.viewerLoadFailed,
    };
    final icon = switch (kind) {
      ViewerFailureKind.missing => Icons.file_present_outlined,
      ViewerFailureKind.permissionDenied => Icons.lock_outline,
      ViewerFailureKind.unsupported => Icons.insert_drive_file_outlined,
      ViewerFailureKind.decodeFailed => Icons.broken_image_outlined,
      ViewerFailureKind.playbackFailed => Icons.play_disabled_outlined,
      ViewerFailureKind.unknown => Icons.error_outline,
    };

    return Semantics(
      liveRegion: true,
      container: true,
      label: message == null ? title : '$title. $message',
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 56, color: colorScheme.onSurfaceVariant),
                const SizedBox(height: 16),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (message != null && message!.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    message!,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (onRetry != null)
                      FilledButton.icon(
                        onPressed: onRetry,
                        icon: const Icon(Icons.refresh),
                        label: Text(l10n.viewerRetry),
                      ),
                    if (onOpenExternal != null)
                      OutlinedButton.icon(
                        onPressed: onOpenExternal,
                        icon: const Icon(Icons.open_in_new),
                        label: Text(l10n.viewerOpenExternal),
                      ),
                    if (onShare != null)
                      OutlinedButton.icon(
                        onPressed: onShare,
                        icon: const Icon(Icons.share_outlined),
                        label: Text(l10n.commonShare),
                      ),
                    if (onBack != null)
                      TextButton.icon(
                        onPressed: onBack,
                        icon: const Icon(Icons.arrow_back),
                        label: Text(l10n.viewerBackToLibrary),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
