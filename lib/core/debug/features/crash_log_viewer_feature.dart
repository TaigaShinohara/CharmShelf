import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:private_shelf/shared/widgets/dialogs/dialog_actions.dart';

import '../../error/crash_report_model.dart';
import '../../error/crash_report_service.dart';
import '../../feedback/snackbar_service.dart';
import '../dip_feature.dart';
import '../../../gen_l10n/app_localizations.dart';

/// クラッシュログ閲覧機能
class CrashLogViewerFeature extends PanelDipFeature {
  CrashLogViewerFeature({CrashReportService? service})
    : _service = service ?? CrashReportService.instance;

  final CrashReportService _service;

  @override
  String get id => 'crash_log_viewer';

  @override
  String get title => 'クラッシュログ';

  @override
  String? get subtitle => 'エラーレポートを閲覧・エクスポート';

  @override
  IconData get icon => Icons.bug_report;

  @override
  DipFeatureCategory get category => DipFeatureCategory.info;

  @override
  Widget? buildPanel(BuildContext context) {
    return _CrashLogViewerPanel(service: _service);
  }
}

class _CrashLogViewerPanel extends ConsumerStatefulWidget {
  const _CrashLogViewerPanel({required this.service});

  final CrashReportService service;

  @override
  ConsumerState<_CrashLogViewerPanel> createState() =>
      _CrashLogViewerPanelState();
}

class _CrashLogViewerPanelState extends ConsumerState<_CrashLogViewerPanel> {
  List<CrashReport> _reports = [];
  bool _isLoading = true;
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _loadFailed = false;
    });
    try {
      final reports = await widget.service.getAllReports();
      if (mounted) setState(() => _reports = reports);
    } catch (_) {
      if (mounted) {
        setState(() {
          _reports = [];
          _loadFailed = true;
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Column(
      children: [
        // ツールバー
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${_reports.length} 件のクラッシュレポート',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _isLoading ? null : _loadReports,
                tooltip: l10n.crashLogRefresh,
              ),
              Builder(
                builder: (btnContext) => IconButton(
                  icon: const Icon(Icons.share),
                  onPressed: _isLoading || _reports.isEmpty
                      ? null
                      : () => _exportAll(btnContext),
                  tooltip: l10n.crashLogExportAll,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: _isLoading || (_reports.isEmpty && !_loadFailed)
                    ? null
                    : _confirmClearAll,
                tooltip: l10n.crashLogDeleteAll,
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // レポートリスト
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _loadFailed
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(l10n.errorDatabase),
                      TextButton(
                        onPressed: _loadReports,
                        child: Text(l10n.commonRetry),
                      ),
                    ],
                  ),
                )
              : _reports.isEmpty
              ? _buildEmptyState(theme)
              : ListView.builder(
                  itemCount: _reports.length,
                  itemBuilder: (context, index) {
                    final report = _reports[index];
                    return _CrashReportTile(
                      report: report,
                      onTap: () => _showDetail(report),
                      onDelete: () => _confirmDelete(report),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 64,
            color: theme.colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            'クラッシュレポートはありません',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'エラーが発生すると自動的に記録されます',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }

  void _showDetail(CrashReport report) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (context) => _CrashReportDetailPage(report: report),
      ),
    );
  }

  Future<void> _confirmDelete(CrashReport report) async {
    final confirmed = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (dialogContext) => AlertDialog(
        title: const Text('レポートを削除'),
        content: const Text('このクラッシュレポートを削除しますか？'),
        actions: [
          DialogActionRow(
            leading: DialogCloseButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              semanticLabel: 'キャンセル',
            ),
            trailing: TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(dialogContext).colorScheme.error,
              ),
              child: const Text('削除'),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await widget.service.deleteReport(report.id);
        await _loadReports();
      } catch (_) {
        _showStorageFailure();
      }
    }
  }

  Future<void> _confirmClearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (dialogContext) => AlertDialog(
        title: const Text('全て削除'),
        content: const Text('全てのクラッシュレポートを削除しますか？\nこの操作は取り消せません。'),
        actions: [
          DialogActionRow(
            leading: DialogCloseButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              semanticLabel: 'キャンセル',
            ),
            trailing: TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(dialogContext).colorScheme.error,
              ),
              child: const Text('全て削除'),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await widget.service.clearAllReports();
        await _loadReports();
        if (!mounted || _loadFailed) return;
        ref
            .read(snackBarServiceProvider)
            .success(context: context, message: '全てのレポートを削除しました');
      } catch (_) {
        _showStorageFailure();
      }
    }
  }

  Future<void> _exportAll(BuildContext context) async {
    final box = context.findRenderObject() as RenderBox?;
    final sharePositionOrigin = box != null
        ? box.localToGlobal(Offset.zero) & box.size
        : null;
    try {
      final exportText = await widget.service.exportAllReports();
      await SharePlus.instance.share(
        ShareParams(
          text: exportText,
          title: 'クラッシュレポート',
          sharePositionOrigin: sharePositionOrigin,
        ),
      );
    } catch (_) {
      _showStorageFailure();
    }
  }

  void _showStorageFailure() {
    if (!mounted) return;
    setState(() => _loadFailed = true);
    ref
        .read(snackBarServiceProvider)
        .error(
          context: context,
          message: AppLocalizations.of(context)!.errorDatabase,
        );
  }
}

class _CrashReportTile extends StatelessWidget {
  const _CrashReportTile({
    required this.report,
    required this.onTap,
    required this.onDelete,
  });

  final CrashReport report;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timeStr = _formatTimestamp(report.timestamp);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // エラーアイコン
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.error_outline,
                  color: theme.colorScheme.onErrorContainer,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              // 内容
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      report.errorType,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      report.errorMessage,
                      style: theme.textTheme.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 12,
                          color: theme.colorScheme.outline,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          timeStr,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                        if (report.currentRoute != null) ...[
                          const SizedBox(width: 12),
                          Icon(
                            Icons.location_on,
                            size: 12,
                            color: theme.colorScheme.outline,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              report.currentRoute!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.outline,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              // 削除ボタン
              IconButton(
                icon: Icon(
                  Icons.delete_outline,
                  color: theme.colorScheme.error,
                ),
                onPressed: onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);

    if (diff.inMinutes < 1) {
      return 'たった今';
    } else if (diff.inHours < 1) {
      return '${diff.inMinutes}分前';
    } else if (diff.inDays < 1) {
      return '${diff.inHours}時間前';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}日前';
    } else {
      return '${timestamp.month}/${timestamp.day} ${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}';
    }
  }
}

class _CrashReportDetailPage extends ConsumerWidget {
  const _CrashReportDetailPage({required this.report});

  final CrashReport report;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('クラッシュレポート詳細'),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            onPressed: () => _copyToClipboard(context, ref),
            tooltip: l10n.crashLogCopy,
          ),
          Builder(
            builder: (btnContext) => IconButton(
              icon: const Icon(Icons.share),
              onPressed: () => _share(btnContext),
              tooltip: l10n.crashLogShare,
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // エラーサマリー
            _buildSection(theme, 'エラー', Icons.error_outline, [
              _buildDetailRow('種類', report.errorType),
              _buildDetailRow('メッセージ', report.errorMessage),
              _buildDetailRow('発生時刻', report.timestamp.toIso8601String()),
              if (report.currentRoute != null)
                _buildDetailRow('画面', report.currentRoute!),
            ]),
            const SizedBox(height: 16),
            // スタックトレース
            if (report.stackTrace != null) ...[
              _buildExpandableSection(
                theme,
                'スタックトレース',
                Icons.list,
                report.stackTrace!,
              ),
              const SizedBox(height: 16),
            ],
            // デバイス情報
            if (report.deviceInfo != null) ...[
              _buildSection(theme, 'デバイス情報', Icons.phone_android, [
                _buildDetailRow('プラットフォーム', report.deviceInfo!.platform),
                if (report.deviceInfo!.osVersion != null)
                  _buildDetailRow('OSバージョン', report.deviceInfo!.osVersion!),
                if (report.deviceInfo!.model != null)
                  _buildDetailRow('モデル', report.deviceInfo!.model!),
              ]),
              const SizedBox(height: 16),
            ],
            // アプリ情報
            if (report.appInfo != null) ...[
              _buildSection(theme, 'アプリ情報', Icons.apps, [
                _buildDetailRow('アプリ名', report.appInfo!.appName),
                _buildDetailRow('バージョン', report.appInfo!.version),
                _buildDetailRow('ビルド番号', report.appInfo!.buildNumber),
              ]),
              const SizedBox(height: 16),
            ],
            // 追加データ
            if (report.additionalData != null &&
                report.additionalData!.isNotEmpty) ...[
              _buildSection(
                theme,
                '追加情報',
                Icons.info_outline,
                report.additionalData!.entries
                    .map((e) => _buildDetailRow(e.key, e.value.toString()))
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSection(
    ThemeData theme,
    String title,
    IconData icon,
    List<Widget> children,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildExpandableSection(
    ThemeData theme,
    String title,
    IconData icon,
    String content,
  ) {
    return Card(
      child: ExpansionTile(
        leading: Icon(icon, color: theme.colorScheme.primary),
        title: Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: SelectableText(
              content,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(child: SelectableText(value)),
        ],
      ),
    );
  }

  Future<void> _copyToClipboard(BuildContext context, WidgetRef ref) async {
    await Clipboard.setData(ClipboardData(text: report.toDetailString()));
    if (context.mounted) {
      ref
          .read(snackBarServiceProvider)
          .success(context: context, message: 'クリップボードにコピーしました');
    }
  }

  Future<void> _share(BuildContext context) async {
    final box = context.findRenderObject() as RenderBox?;
    final sharePositionOrigin = box != null
        ? box.localToGlobal(Offset.zero) & box.size
        : null;
    await SharePlus.instance.share(
      ShareParams(
        text: report.toDetailString(),
        title: 'クラッシュレポート',
        sharePositionOrigin: sharePositionOrigin,
      ),
    );
  }
}
