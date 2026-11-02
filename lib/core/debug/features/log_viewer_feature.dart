import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:private_shelf/shared/widgets/dialogs/dialog_actions.dart';

import '../../../gen_l10n/app_localizations.dart';
import '../../feedback/snackbar_service.dart';
import '../dip_action_log.dart';
import '../dip_feature.dart';

/// ログビューア機能
class LogViewerFeature extends PanelDipFeature {
  @override
  String get id => 'log_viewer';

  @override
  String get title => 'Log Viewer';

  @override
  String? get subtitle => null;

  @override
  IconData get icon => Icons.article_outlined;

  @override
  DipFeatureCategory get category => DipFeatureCategory.info;

  @override
  Widget? buildPanel(BuildContext context) {
    return const _LogViewerPanel();
  }
}

class _LogViewerPanel extends ConsumerStatefulWidget {
  const _LogViewerPanel();

  @override
  ConsumerState<_LogViewerPanel> createState() => _LogViewerPanelState();
}

class _LogViewerPanelState extends ConsumerState<_LogViewerPanel> {
  DipLogLevel? _filterLevel;
  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<DipLogEntry> get _filteredLogs {
    var logs = DipActionLog.logs.reversed.toList();

    if (_filterLevel != null) {
      logs = logs.where((l) => l.level == _filterLevel).toList();
    }

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      logs = logs
          .where(
            (l) =>
                l.message.toLowerCase().contains(query) ||
                (l.tag?.toLowerCase().contains(query) ?? false),
          )
          .toList();
    }

    return logs;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final logs = _filteredLogs;

    return Column(
      children: [
        // ツールバー
        Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            children: [
              // 検索バー
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: l10n.commonSearch,
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (value) => setState(() => _searchQuery = value),
              ),
              const SizedBox(height: 8),
              // フィルターとアクション
              Row(
                children: [
                  // フィルター
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          FilterChip(
                            label: Text(l10n.dipLogViewerAll),
                            selected: _filterLevel == null,
                            onSelected: (_) =>
                                setState(() => _filterLevel = null),
                          ),
                          const SizedBox(width: 4),
                          for (final level in DipLogLevel.values) ...[
                            FilterChip(
                              avatar: Icon(level.icon, size: 16),
                              label: Text(level.name),
                              selected: _filterLevel == level,
                              onSelected: (_) =>
                                  setState(() => _filterLevel = level),
                            ),
                            const SizedBox(width: 4),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // アクションボタン
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _copyLogs(context, logs),
                      icon: const Icon(Icons.copy, size: 18),
                      label: Text(l10n.commonCopy),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Builder(
                      builder: (btnContext) => OutlinedButton.icon(
                        onPressed: () => _shareLogs(btnContext, logs),
                        icon: const Icon(Icons.share, size: 18),
                        label: Text(l10n.commonShare),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        DipActionLog.clearLogs();
                        setState(() {});
                      },
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: Text(l10n.commonClear),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // ログリスト
        Expanded(
          child: logs.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.article_outlined,
                        size: 64,
                        color: theme.colorScheme.outline,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        l10n.dipLogViewerNoLogs,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: logs.length,
                  itemBuilder: (context, index) {
                    final log = logs[index];
                    return _LogTile(entry: log);
                  },
                ),
        ),
      ],
    );
  }

  Future<void> _copyLogs(BuildContext context, List<DipLogEntry> logs) async {
    final l10n = AppLocalizations.of(context)!;
    final text = logs.map((l) => l.toString()).join('\n');
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) {
      ref
          .read(snackBarServiceProvider)
          .success(context: context, message: l10n.clipboardCopied);
    }
  }

  Future<void> _shareLogs(BuildContext context, List<DipLogEntry> logs) async {
    final l10n = AppLocalizations.of(context)!;
    final text = logs.map((l) => l.toString()).join('\n');
    final box = context.findRenderObject() as RenderBox?;
    final sharePositionOrigin = box != null
        ? box.localToGlobal(Offset.zero) & box.size
        : null;
    await SharePlus.instance.share(
      ShareParams(
        text: text,
        title: l10n.dipLogViewerSubject,
        sharePositionOrigin: sharePositionOrigin,
      ),
    );
  }
}

class _LogTile extends ConsumerWidget {
  const _LogTile({required this.entry});

  final DipLogEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final timeStr =
        '${entry.timestamp.hour.toString().padLeft(2, '0')}:${entry.timestamp.minute.toString().padLeft(2, '0')}:${entry.timestamp.second.toString().padLeft(2, '0')}';

    return Container(
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: entry.level.color, width: 4)),
      ),
      child: ListTile(
        dense: true,
        leading: Icon(entry.level.icon, color: entry.level.color, size: 20),
        title: Text(
          entry.message,
          style: theme.textTheme.bodyMedium,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          entry.tag != null ? '$timeStr • ${entry.tag}' : timeStr,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
        onTap: () => _showDetail(context, ref),
      ),
    );
  }

  void _showDetail(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    showDialog<void>(
      context: context,
      useRootNavigator: true,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            Icon(entry.level.icon, color: entry.level.color),
            const SizedBox(width: 8),
            Text(entry.level.name.toUpperCase()),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (entry.tag != null) ...[
                Text(
                  l10n.dipLogViewerTag(entry.tag!),
                  style: Theme.of(dialogContext).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
              ],
              Text(
                l10n.dipLogViewerTime(entry.timestamp.toIso8601String()),
                style: Theme.of(dialogContext).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              SelectableText(entry.message),
            ],
          ),
        ),
        actions: [
          DialogActionRow(
            leading: DialogCloseButton(
              onPressed: () => Navigator.pop(dialogContext),
              semanticLabel: l10n.commonClose,
            ),
            trailing: TextButton(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: entry.toString()));
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                  ref
                      .read(snackBarServiceProvider)
                      .success(
                        context: dialogContext,
                        message: l10n.clipboardCopied,
                      );
                }
              },
              child: Text(l10n.commonCopy),
            ),
          ),
        ],
      ),
    );
  }
}
