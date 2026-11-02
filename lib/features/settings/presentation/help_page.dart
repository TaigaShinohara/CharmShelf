import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../gen_l10n/app_localizations.dart';
import '../../../shared/widgets/icon/charm_icon.dart';

/// ヘルプの見出しごとに短いカードへ分けて表示する。
class HelpPage extends StatelessWidget {
  const HelpPage({super.key});

  static const _icons = <Widget>[
    Icon(Icons.add_circle_outline),
    Icon(Icons.folder_copy_outlined),
    CharmIcon(),
    Icon(Icons.search_outlined),
    Icon(Icons.cloud_off_outlined),
    Icon(Icons.help_outline),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final parts = l10n.helpContent.split(RegExp(r'(?=^## )', multiLine: true));
    final intro = parts.first.trim();
    final sections = parts.skip(1).map((part) {
      final newline = part.indexOf('\n');
      return (
        title: part.substring(3, newline).trim(),
        body: part.substring(newline + 1).trim(),
      );
    }).toList();
    final markdownStyle = MarkdownStyleSheet.fromTheme(theme).copyWith(
      p: theme.textTheme.bodyMedium?.copyWith(
        color: colors.onSurface,
        height: 1.55,
      ),
      pPadding: const EdgeInsets.only(bottom: 10),
      listBullet: theme.textTheme.bodyMedium?.copyWith(color: colors.primary),
      listIndent: 18,
      h3: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
      h3Padding: const EdgeInsets.only(top: 12, bottom: 6),
      blockquoteDecoration: BoxDecoration(
        color: colors.primaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: colors.primary, width: 4)),
      ),
      blockquotePadding: const EdgeInsets.all(12),
    );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.helpTitle)),
      body: SafeArea(
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          itemCount: sections.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
                child: Text(intro, style: theme.textTheme.bodyMedium),
              );
            }
            final section = sections[index - 1];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Card(
                color: colors.surfaceContainerLow,
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: colors.primaryContainer,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: IconTheme.merge(
                              data: IconThemeData(
                                color: colors.onPrimaryContainer,
                              ),
                              child: _icons[index - 1],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              section.title,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      MarkdownBody(
                        data: section.body,
                        selectable: true,
                        styleSheet: markdownStyle,
                        onTapLink: (_, href, _) {
                          final uri = Uri.tryParse(href ?? '');
                          if (uri != null && uri.scheme == 'mailto') {
                            launchUrl(uri);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
