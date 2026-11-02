import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/logger/app_logger.dart';
import '../../../core/logger/log_tag.dart';
import '../../../core/utils/clipboard_utils.dart';
import '../../../gen_l10n/app_localizations.dart';
import '../../../shared/widgets/widgets.dart';

/// 規約やヘルプなどの情報を表示するための汎用ページ
class InfoPage extends StatelessWidget {
  const InfoPage({
    super.key,
    required this.title,
    required this.content,
    this.canLaunchUrlFn,
    this.launchUrlFn,
  });

  final String title;
  final String content;
  final Future<bool> Function(Uri url)? canLaunchUrlFn;
  final Future<bool> Function(Uri url, {LaunchMode mode})? launchUrlFn;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final markdownStyleSheet = MarkdownStyleSheet.fromTheme(theme).copyWith(
      p: theme.textTheme.bodyMedium?.copyWith(
        color: colorScheme.onSurface,
        height: 1.6,
      ),
      pPadding: const EdgeInsets.only(bottom: 12.0),
      h1: theme.textTheme.headlineMedium?.copyWith(
        fontWeight: FontWeight.bold,
        color: colorScheme.onSurface,
      ),
      h1Padding: const EdgeInsets.only(top: 24.0, bottom: 12.0),
      h2: theme.textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.bold,
        color: colorScheme.onSurface,
      ),
      h2Padding: const EdgeInsets.only(top: 24.0, bottom: 8.0),
      h3: theme.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.bold,
        color: colorScheme.onSurface,
      ),
      h3Padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
      listBullet: theme.textTheme.bodyMedium?.copyWith(
        color: colorScheme.primary,
        fontWeight: FontWeight.bold,
      ),
      listBulletPadding: const EdgeInsets.only(right: 8.0),
      listIndent: 20.0,
      code: TextStyle(
        fontFamily: 'monospace',
        fontSize: 13.0,
        color: colorScheme.onSurfaceVariant,
        backgroundColor: colorScheme.surfaceContainerHighest,
      ),
      codeblockDecoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      codeblockPadding: const EdgeInsets.all(12.0),
      blockquoteDecoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(4.0),
        border: Border(
          left: BorderSide(color: colorScheme.primary, width: 4.0),
        ),
      ),
      blockquotePadding: const EdgeInsets.symmetric(
        horizontal: 12.0,
        vertical: 8.0,
      ),
      a: TextStyle(
        color: colorScheme.primary,
        decoration: TextDecoration.underline,
      ),
    );

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          PremiumSliverAppBar(titleText: title, inlineTitle: true),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 32.0),
            sliver: SliverToBoxAdapter(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Material(
                    color: colorScheme.surfaceContainerLow,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: colorScheme.outlineVariant.withValues(
                          alpha: 0.4,
                        ),
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.article_outlined,
                                color: colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Divider(color: colorScheme.outlineVariant),
                          const SizedBox(height: 4),
                          MarkdownBody(
                            data: content,
                            selectable: true,
                            styleSheet: markdownStyleSheet,
                            onTapLink: (text, href, linkTitle) =>
                                _handleLinkTap(context, href),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleLinkTap(BuildContext context, String? href) async {
    if (href == null || href.isEmpty) return;

    final uri = Uri.tryParse(href);
    if (uri == null) return;

    try {
      final canLaunch = canLaunchUrlFn ?? canLaunchUrl;
      final launch = launchUrlFn ?? launchUrl;

      if (await canLaunch(uri)) {
        await launch(uri, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (e, st) {
      AppLogger.e(LogTag.app, 'リンクの起動に失敗しました: $href', e, st);
    }

    if (context.mounted) {
      final l10n = AppLocalizations.of(context);
      final message = l10n?.clipboardCopied ?? 'コピーしました';
      await ClipboardUtils.copyWithFeedback(context, href, message: message);
    }
  }
}
