import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:private_shelf/core/logger/app_logger.dart';
import 'package:private_shelf/core/logger/log_tag.dart';
import 'package:private_shelf/gen_l10n/app_localizations.dart';

/// PDF annotations are untrusted input, including their URI schemes.
bool isAllowedPdfExternalLink(Uri uri) {
  switch (uri.scheme.toLowerCase()) {
    case 'http':
    case 'https':
      return uri.host.isNotEmpty && uri.userInfo.isEmpty;
    case 'mailto':
    case 'tel':
      return uri.path.isNotEmpty;
    default:
      return false;
  }
}

/// Open an allowed document link only after the user confirms its destination.
Future<bool> openPdfExternalLink(
  BuildContext context,
  Uri uri, {
  Future<bool> Function(Uri)? launch,
}) async {
  if (!context.mounted || !isAllowedPdfExternalLink(uri)) return false;
  final l10n = AppLocalizations.of(context)!;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(l10n.viewerOpenExternal),
      content: SelectableText(uri.toString()),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(l10n.commonCancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(l10n.commonOk),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return false;
  try {
    final opened =
        await (launch?.call(uri) ??
            launchUrl(uri, mode: LaunchMode.externalApplication));
    if (opened) return true;
  } catch (_) {
    // Avoid copying document URLs (possibly containing personal data) into logs.
    AppLogger.w(LogTag.app, 'PDF外部リンクを開けませんでした');
  }
  if (context.mounted) {
    ScaffoldMessenger.maybeOf(
      context,
    )?.showSnackBar(SnackBar(content: Text(l10n.commonErrorOccurred)));
  }
  return false;
}
