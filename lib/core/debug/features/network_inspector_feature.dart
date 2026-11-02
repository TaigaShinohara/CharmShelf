import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../gen_l10n/app_localizations.dart';
import '../../feedback/snackbar_service.dart';
import '../../logger/app_logger.dart';
import '../../logger/log_tag.dart';
import '../dip_feature.dart';

/// ネットワークリクエストの記録
class NetworkRequest {
  NetworkRequest({
    required this.id,
    required this.method,
    required this.url,
    required this.timestamp,
    this.requestHeaders,
    this.requestBody,
    this.responseStatusCode,
    this.responseHeaders,
    this.responseBody,
    this.duration,
    this.error,
  });

  final String id;
  final String method;
  final String url;
  final DateTime timestamp;
  final Map<String, String>? requestHeaders;
  final String? requestBody;
  int? responseStatusCode;
  Map<String, String>? responseHeaders;
  String? responseBody;
  Duration? duration;
  String? error;

  bool get isSuccess =>
      responseStatusCode != null &&
      responseStatusCode! >= 200 &&
      responseStatusCode! < 300;

  bool get isError => error != null || (responseStatusCode ?? 0) >= 400;

  bool get isPending => responseStatusCode == null && error == null;
}

/// ネットワークインスペクター
class NetworkInspector {
  NetworkInspector._();

  static final NetworkInspector instance = NetworkInspector._();

  final _requests = Queue<NetworkRequest>();
  static const _maxRequests = 100;

  List<NetworkRequest> get requests => _requests.toList();

  void addRequest(NetworkRequest request) {
    _requests.addLast(request);
    if (_requests.length > _maxRequests) {
      _requests.removeFirst();
    }
  }

  void updateRequest(
    String id, {
    int? statusCode,
    Map<String, String>? responseHeaders,
    String? responseBody,
    Duration? duration,
    String? error,
  }) {
    try {
      final request = _requests.firstWhere((r) => r.id == id);
      request.responseStatusCode = statusCode;
      request.responseHeaders = responseHeaders;
      request.responseBody = responseBody;
      request.duration = duration;
      request.error = error;
    } catch (e, st) {
      // リクエストIDが見つからない場合はログを出力
      AppLogger.w(
        LogTag.app,
        'NetworkInspector: リクエスト (ID: $id) のレスポンス記録対象が見つかりません',
        e,
        st,
      );
    }
  }

  void clear() {
    _requests.clear();
  }
}

/// ネットワークインスペクター機能
class NetworkInspectorFeature extends PanelDipFeature {
  @override
  String get id => 'network_inspector';

  @override
  String get title => 'ネットワーク';

  @override
  String? get subtitle => 'API通信ログを確認';

  @override
  IconData get icon => Icons.wifi;

  @override
  DipFeatureCategory get category => DipFeatureCategory.debug;

  @override
  Widget? buildPanel(BuildContext context) {
    return const _NetworkInspectorPanel();
  }
}

class _NetworkInspectorPanel extends StatefulWidget {
  const _NetworkInspectorPanel();

  @override
  State<_NetworkInspectorPanel> createState() => _NetworkInspectorPanelState();
}

class _NetworkInspectorPanelState extends State<_NetworkInspectorPanel> {
  String _filter = '';
  String? _methodFilter;

  List<NetworkRequest> get _filteredRequests {
    var requests = NetworkInspector.instance.requests.reversed.toList();

    if (_methodFilter != null) {
      requests = requests.where((r) => r.method == _methodFilter).toList();
    }

    if (_filter.isNotEmpty) {
      final query = _filter.toLowerCase();
      requests = requests.where((r) {
        return r.url.toLowerCase().contains(query) ||
            r.method.toLowerCase().contains(query);
      }).toList();
    }

    return requests;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final requests = _filteredRequests;

    return Column(
      children: [
        // ツールバー
        Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            children: [
              // 検索バー
              TextField(
                decoration: InputDecoration(
                  hintText: 'URLで検索...',
                  prefixIcon: const Icon(Icons.search),
                  border: const OutlineInputBorder(),
                  isDense: true,
                  suffixIcon: _filter.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () => setState(() => _filter = ''),
                        )
                      : null,
                ),
                onChanged: (value) => setState(() => _filter = value),
              ),
              const SizedBox(height: 8),
              // フィルターとアクション
              Row(
                children: [
                  // メソッドフィルター
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          FilterChip(
                            label: const Text('全て'),
                            selected: _methodFilter == null,
                            onSelected: (_) =>
                                setState(() => _methodFilter = null),
                          ),
                          const SizedBox(width: 4),
                          for (final method in [
                            'GET',
                            'POST',
                            'PUT',
                            'DELETE',
                          ]) ...[
                            FilterChip(
                              label: Text(method),
                              selected: _methodFilter == method,
                              onSelected: (_) =>
                                  setState(() => _methodFilter = method),
                            ),
                            const SizedBox(width: 4),
                          ],
                        ],
                      ),
                    ),
                  ),
                  // クリアボタン
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () {
                      NetworkInspector.instance.clear();
                      setState(() {});
                    },
                    tooltip: l10n.commonClear,
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: () => setState(() {}),
                    tooltip: l10n.commonUpdate,
                  ),
                ],
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // リクエストリスト
        Expanded(
          child: requests.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.wifi_off,
                        size: 64,
                        color: theme.colorScheme.outline,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'リクエストがありません',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'NetworkInspector.instance.addRequest() で\nリクエストを記録してください',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: requests.length,
                  itemBuilder: (context, index) {
                    final request = requests[index];
                    return _RequestTile(request: request);
                  },
                ),
        ),
      ],
    );
  }
}

class _RequestTile extends StatelessWidget {
  const _RequestTile({required this.request});

  final NetworkRequest request;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Color statusColor;
    if (request.isPending) {
      statusColor = Colors.grey;
    } else if (request.isError) {
      statusColor = theme.colorScheme.error;
    } else {
      statusColor = Colors.green;
    }

    final uri = Uri.tryParse(request.url);
    final path = uri?.path ?? request.url;

    return Container(
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: statusColor, width: 4)),
      ),
      child: ListTile(
        dense: true,
        leading: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _getMethodColor(request.method).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            request.method,
            style: TextStyle(
              color: _getMethodColor(request.method),
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
        title: Text(
          path,
          style: theme.textTheme.bodyMedium?.copyWith(fontFamily: 'monospace'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Row(
          children: [
            if (request.responseStatusCode != null)
              Text(
                '${request.responseStatusCode}',
                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            if (request.duration != null) ...[
              const SizedBox(width: 8),
              Text('${request.duration!.inMilliseconds}ms'),
            ],
            const Spacer(),
            Text(
              _formatTime(request.timestamp),
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
        onTap: () => _showDetail(context),
      ),
    );
  }

  Color _getMethodColor(String method) {
    return switch (method) {
      'GET' => Colors.green,
      'POST' => Colors.blue,
      'PUT' => Colors.orange,
      'DELETE' => Colors.red,
      'PATCH' => Colors.purple,
      _ => Colors.grey,
    };
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}:'
        '${time.second.toString().padLeft(2, '0')}';
  }

  void _showDetail(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => _RequestDetailPage(request: request),
      ),
    );
  }
}

class _RequestDetailPage extends ConsumerWidget {
  const _RequestDetailPage({required this.request});

  final NetworkRequest request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(request.method),
          bottom: const TabBar(
            tabs: [
              Tab(text: '概要'),
              Tab(text: 'リクエスト'),
              Tab(text: 'レスポンス'),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.copy),
              onPressed: () => _copyAsCurl(context, ref),
              tooltip: l10n.networkInspectorCopyAsCurl,
            ),
          ],
        ),
        body: TabBarView(
          children: [
            // 概要タブ
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _DetailSection(
                  title: 'URL',
                  child: SelectableText(
                    request.url,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                _DetailSection(
                  title: 'ステータス',
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: request.isError ? Colors.red : Colors.green,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${request.responseStatusCode ?? "Pending"}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (request.duration != null) ...[
                        const SizedBox(width: 16),
                        Text('${request.duration!.inMilliseconds}ms'),
                      ],
                    ],
                  ),
                ),
                if (request.error != null)
                  _DetailSection(
                    title: 'エラー',
                    child: Text(
                      request.error!,
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ),
              ],
            ),
            // リクエストタブ
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (request.requestHeaders != null &&
                    request.requestHeaders!.isNotEmpty)
                  _DetailSection(
                    title: 'ヘッダー',
                    child: _JsonView(data: request.requestHeaders!),
                  ),
                if (request.requestBody != null &&
                    request.requestBody!.isNotEmpty)
                  _DetailSection(
                    title: 'ボディ',
                    child: SelectableText(
                      request.requestBody!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
              ],
            ),
            // レスポンスタブ
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (request.responseHeaders != null &&
                    request.responseHeaders!.isNotEmpty)
                  _DetailSection(
                    title: 'ヘッダー',
                    child: _JsonView(data: request.responseHeaders!),
                  ),
                if (request.responseBody != null &&
                    request.responseBody!.isNotEmpty)
                  _DetailSection(
                    title: 'ボディ',
                    child: SelectableText(
                      request.responseBody!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _copyAsCurl(BuildContext context, WidgetRef ref) async {
    final buffer = StringBuffer('curl');
    buffer.write(" -X '${request.method}'");
    buffer.write(" '${request.url}'");

    if (request.requestHeaders != null) {
      for (final entry in request.requestHeaders!.entries) {
        buffer.write(" -H '${entry.key}: ${entry.value}'");
      }
    }

    if (request.requestBody != null && request.requestBody!.isNotEmpty) {
      buffer.write(" -d '${request.requestBody}'");
    }

    await Clipboard.setData(ClipboardData(text: buffer.toString()));

    if (context.mounted) {
      ref
          .read(snackBarServiceProvider)
          .success(context: context, message: 'cURLコマンドをコピーしました');
    }
  }
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _JsonView extends StatelessWidget {
  const _JsonView({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final entry in data.entries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${entry.key}: ',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      entry.value.toString(),
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
