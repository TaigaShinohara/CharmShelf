import 'package:flutter/material.dart';
import 'package:private_shelf/shared/widgets/feedback/app_snackbar.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../dip_controller.dart';
import '../dip_feature.dart';

/// ルート情報表示機能
class RouteInfoFeature extends DipFeature {
  @override
  String get id => 'route_info';

  @override
  String get title => 'ルート情報';

  @override
  String? get subtitle => '現在のルート・パラメータを表示';

  @override
  IconData get icon => Icons.route_outlined;

  @override
  DipFeatureCategory get category => DipFeatureCategory.info;

  @override
  Widget buildTile(BuildContext context, {VoidCallback? onClose}) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Icon(icon, color: theme.colorScheme.primary),
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle!) : null,
      trailing: const Icon(Icons.chevron_right),
      onTap: () async {
        // GoRouterのcontext内でルート情報を取得（DIPを閉じる前に）
        final routeInfo = _captureRouteInfo(context);

        // rootNavigatorを事前に取得（DIPを閉じる前に）
        final navigator = Navigator.of(context, rootNavigator: true);

        // DIPを閉じる
        onClose?.call();

        // パネルに遷移して戻りを待つ
        await navigator.push(
          MaterialPageRoute<void>(
            builder: (navContext) => Scaffold(
              appBar: AppBar(title: Text(title)),
              body: _RouteInfoPanel(routeInfo: routeInfo),
            ),
          ),
        );

        // 戻ってきたらDIPを再表示（次フレームで実行）
        // showWithLastOverlay()を使用して、保存されたOverlayを再利用
        WidgetsBinding.instance.addPostFrameCallback((_) {
          DipController.showWithLastOverlay();
        });
      },
    );
  }

  @override
  void onTap(BuildContext context) {
    // buildTileで処理されるため、ここでは何もしない
  }

  _CapturedRouteInfo _captureRouteInfo(BuildContext context) {
    try {
      final router = GoRouter.of(context);
      final config = router.routerDelegate.currentConfiguration;

      String? routeName;
      if (config.matches.isNotEmpty) {
        final route = config.matches.last.route;
        if (route is GoRoute) {
          routeName = route.name;
        }
      }

      return _CapturedRouteInfo(
        currentPath: config.uri.path,
        fullUri: config.uri.toString(),
        pathParameters: Map.from(config.pathParameters),
        queryParameters: Map.from(config.uri.queryParameters),
        matchedLocation: config.matches.isNotEmpty
            ? config.matches.last.matchedLocation
            : config.uri.path,
        extra: config.extra?.toString(),
        routeName: routeName,
      );
    } catch (e) {
      // GoRouterが利用できない場合はフォールバック
      return _CapturedRouteInfo(
        currentPath: '(取得できません)',
        fullUri: '(取得できません)',
        pathParameters: {},
        queryParameters: {},
        matchedLocation: '(取得できません)',
        extra: null,
        routeName: null,
        error: e.toString(),
      );
    }
  }
}

/// キャプチャされたルート情報
class _CapturedRouteInfo {
  _CapturedRouteInfo({
    required this.currentPath,
    required this.fullUri,
    required this.pathParameters,
    required this.queryParameters,
    required this.matchedLocation,
    this.extra,
    this.routeName,
    this.error,
  });

  final String currentPath;
  final String fullUri;
  final Map<String, String> pathParameters;
  final Map<String, String> queryParameters;
  final String matchedLocation;
  final String? extra;
  final String? routeName;
  final String? error;
}

class _RouteInfoPanel extends StatelessWidget {
  const _RouteInfoPanel({required this.routeInfo});

  final _CapturedRouteInfo routeInfo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final info = <_RouteInfoItem>[
      _RouteInfoItem('現在のパス', routeInfo.currentPath),
      _RouteInfoItem('フルURI', routeInfo.fullUri),
      _RouteInfoItem('名前', routeInfo.routeName ?? '(なし)'),
      _RouteInfoItem('マッチしたパターン', routeInfo.matchedLocation),
      if (routeInfo.pathParameters.isNotEmpty)
        _RouteInfoItem(
          'パスパラメータ',
          routeInfo.pathParameters.entries
              .map((e) => '${e.key}: ${e.value}')
              .join('\n'),
        ),
      if (routeInfo.queryParameters.isNotEmpty)
        _RouteInfoItem(
          'クエリパラメータ',
          routeInfo.queryParameters.entries
              .map((e) => '${e.key}: ${e.value}')
              .join('\n'),
        ),
      if (routeInfo.extra != null) _RouteInfoItem('Extra', routeInfo.extra!),
      if (routeInfo.error != null) _RouteInfoItem('エラー', routeInfo.error!),
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // エラー表示
        if (routeInfo.error != null) ...[
          Card(
            color: theme.colorScheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber,
                    color: theme.colorScheme.onErrorContainer,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'ルート情報の取得中にエラーが発生しました',
                      style: TextStyle(
                        color: theme.colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        // コピーボタン
        ElevatedButton.icon(
          onPressed: () => _copyAll(context, info),
          icon: const Icon(Icons.copy),
          label: const Text('ルート情報をコピー'),
        ),
        const SizedBox(height: 24),
        // ルート情報
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final item in info) ...[
                  Text(
                    item.label,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  SelectableText(
                    item.value,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        // 説明
        Text(
          '注意',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'このパネルを開いた時点でのルート情報を表示しています。'
              'リアルタイムな情報ではありません。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _copyAll(
    BuildContext context,
    List<_RouteInfoItem> items,
  ) async {
    final text = items.map((i) => '${i.label}:\n${i.value}').join('\n\n');
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) {
      AppSnackBarMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('コピーしました')));
    }
  }
}

class _RouteInfoItem {
  _RouteInfoItem(this.label, this.value);
  final String label;
  final String value;
}
