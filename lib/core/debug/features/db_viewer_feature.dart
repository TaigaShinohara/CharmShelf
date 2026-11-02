import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:private_shelf/shared/widgets/dialogs/dialog_actions.dart';

import '../../feedback/snackbar_service.dart';
import '../dip_feature.dart';

/// Isarデータベースビューア機能
class DbViewerFeature extends PanelDipFeature {
  @override
  String get id => 'db_viewer';

  @override
  String get title => 'DBビューア';

  @override
  String? get subtitle => 'Isar DBの内容を確認';

  @override
  IconData get icon => Icons.table_chart_outlined;

  @override
  DipFeatureCategory get category => DipFeatureCategory.data;

  @override
  Widget? buildPanel(BuildContext context) {
    return const _DbViewerPanel();
  }
}

class _DbViewerPanel extends ConsumerStatefulWidget {
  const _DbViewerPanel();

  @override
  ConsumerState<_DbViewerPanel> createState() => _DbViewerPanelState();
}

class _DbViewerPanelState extends ConsumerState<_DbViewerPanel> {
  bool _loading = true;
  List<_CollectionInfo> _collections = [];
  String? _error;
  String? _dbPath;

  @override
  void initState() {
    super.initState();
    _loadCollections();
  }

  Future<void> _loadCollections() async {
    try {
      final appDir = await getApplicationSupportDirectory();
      _dbPath = appDir.path;

      // 登録済みコレクションの情報を取得
      // 注意: Isarは直接コレクション一覧を取得するAPIがないため、
      // アプリで使用しているコレクションを明示的に列挙する必要がある
      final collections = <_CollectionInfo>[];

      // IsarServiceから利用可能なコレクション情報を取得
      // 実際のコレクションはアプリによって異なるため、
      // ここでは一般的な情報を表示

      setState(() {
        _collections = collections;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _loading = true;
                  _error = null;
                });
                _loadCollections();
              },
              child: const Text('再試行'),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Isar情報
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.storage, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Isar Database',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const _InfoRow(label: 'ステータス', value: '初期化済み'),
                _InfoRow(label: 'パス', value: _dbPath ?? '不明'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        // コレクション一覧
        Text(
          'コレクション',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        if (_collections.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 48,
                    color: theme.colorScheme.outline,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'コレクション情報を取得するには、\nアプリでIsarコレクションを登録してください',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          for (final collection in _collections)
            Card(
              child: ListTile(
                leading: const Icon(Icons.table_rows),
                title: Text(collection.name),
                subtitle: Text('${collection.count} レコード'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _viewCollection(context, collection),
              ),
            ),
        const SizedBox(height: 24),
        // 操作ボタン
        Text(
          '操作',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.refresh),
                title: const Text('更新'),
                onTap: () {
                  setState(() => _loading = true);
                  _loadCollections();
                },
              ),
              ListTile(
                leading: Icon(
                  Icons.delete_forever,
                  color: theme.colorScheme.error,
                ),
                title: Text(
                  '全データ削除',
                  style: TextStyle(color: theme.colorScheme.error),
                ),
                onTap: () => _clearAll(context),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _viewCollection(BuildContext context, _CollectionInfo collection) {
    // コレクションの詳細ビューを表示
    // 実装はコレクションの型に依存するため、
    // アプリごとにカスタマイズが必要
    ref
        .read(snackBarServiceProvider)
        .info(context: context, message: '${collection.name}の詳細表示は未実装です');
  }

  Future<void> _clearAll(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (dialogContext) => AlertDialog(
        title: const Text('全データ削除'),
        content: const Text('全てのデータを削除しますか？\nこの操作は取り消せません。\n再起動が必要です。'),
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

    if (confirmed == true && context.mounted) {
      ref
          .read(snackBarServiceProvider)
          .info(context: context, message: 'キャッシュクリア機能からIsarを削除してください');
    }
  }
}

class _CollectionInfo {
  _CollectionInfo({required this.name, required this.count});

  final String name;
  final int count;
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
