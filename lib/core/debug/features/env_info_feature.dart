import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../feedback/snackbar_service.dart';
import '../dip_feature.dart';

/// 環境情報表示機能
class EnvInfoFeature extends PanelDipFeature {
  @override
  String get id => 'env_info';

  @override
  String get title => '環境情報';

  @override
  String? get subtitle => 'アプリ・端末情報を表示';

  @override
  IconData get icon => Icons.info_outline;

  @override
  DipFeatureCategory get category => DipFeatureCategory.info;

  @override
  Widget? buildPanel(BuildContext context) {
    return const _EnvInfoPanel();
  }
}

class _EnvInfoPanel extends ConsumerStatefulWidget {
  const _EnvInfoPanel();

  @override
  ConsumerState<_EnvInfoPanel> createState() => _EnvInfoPanelState();
}

class _EnvInfoPanelState extends ConsumerState<_EnvInfoPanel> {
  PackageInfo? _packageInfo;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadInfo();
  }

  Future<void> _loadInfo() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _packageInfo = info;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final theme = Theme.of(context);
    final items = _buildInfoItems();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // コピーボタン
        ElevatedButton.icon(
          onPressed: () => _copyAll(context, items),
          icon: const Icon(Icons.copy),
          label: const Text('全ての情報をコピー'),
        ),
        const SizedBox(height: 24),
        // セクション: アプリ情報
        _buildSection(context, 'アプリ情報', [
          _InfoTile(label: 'アプリ名', value: _packageInfo?.appName ?? '不明'),
          _InfoTile(label: 'パッケージ名', value: _packageInfo?.packageName ?? '不明'),
          _InfoTile(label: 'バージョン', value: _packageInfo?.version ?? '不明'),
          _InfoTile(label: 'ビルド番号', value: _packageInfo?.buildNumber ?? '不明'),
        ]),
        const SizedBox(height: 16),
        // セクション: 端末情報
        _buildSection(context, '端末情報', [
          _InfoTile(label: 'プラットフォーム', value: Platform.operatingSystem),
          _InfoTile(label: 'OSバージョン', value: Platform.operatingSystemVersion),
          _InfoTile(label: 'ロケール', value: Platform.localeName),
        ]),
        const SizedBox(height: 16),
        // セクション: ビルド情報
        _buildSection(context, 'ビルド情報', [
          const _InfoTile(label: 'デバッグモード', value: kDebugMode ? 'はい' : 'いいえ'),
          const _InfoTile(
            label: 'プロファイルモード',
            value: kProfileMode ? 'はい' : 'いいえ',
          ),
          const _InfoTile(label: 'リリースモード', value: kReleaseMode ? 'はい' : 'いいえ'),
        ]),
        const SizedBox(height: 16),
        // セクション: 画面情報
        _buildSection(context, '画面情報', [
          _InfoTile(
            label: '画面サイズ',
            value:
                '${MediaQuery.of(context).size.width.toStringAsFixed(0)} x ${MediaQuery.of(context).size.height.toStringAsFixed(0)}',
          ),
          _InfoTile(
            label: 'デバイスピクセル比',
            value: MediaQuery.of(context).devicePixelRatio.toStringAsFixed(2),
          ),
          _InfoTile(
            label: 'テキストスケール',
            value: MediaQuery.of(
              context,
            ).textScaler.scale(1.0).toStringAsFixed(2),
          ),
          _InfoTile(
            label: 'パディング（上）',
            value: MediaQuery.of(context).padding.top.toStringAsFixed(0),
          ),
          _InfoTile(
            label: 'パディング（下）',
            value: MediaQuery.of(context).padding.bottom.toStringAsFixed(0),
          ),
        ]),
        const SizedBox(height: 16),
        // セクション: テーマ情報
        _buildSection(context, 'テーマ情報', [
          _InfoTile(
            label: 'ブライトネス',
            value: theme.brightness == Brightness.dark ? 'ダーク' : 'ライト',
          ),
          _InfoTile(
            label: 'プライマリカラー',
            value:
                '#${theme.colorScheme.primary.toARGB32().toRadixString(16).substring(2).toUpperCase()}',
          ),
        ]),
      ],
    );
  }

  List<_InfoItem> _buildInfoItems() {
    return [
      _InfoItem('アプリ名', _packageInfo?.appName ?? '不明'),
      _InfoItem('パッケージ名', _packageInfo?.packageName ?? '不明'),
      _InfoItem('バージョン', _packageInfo?.version ?? '不明'),
      _InfoItem('ビルド番号', _packageInfo?.buildNumber ?? '不明'),
      _InfoItem('プラットフォーム', Platform.operatingSystem),
      _InfoItem('OSバージョン', Platform.operatingSystemVersion),
      _InfoItem('ロケール', Platform.localeName),
      _InfoItem('デバッグモード', kDebugMode ? 'はい' : 'いいえ'),
      _InfoItem('プロファイルモード', kProfileMode ? 'はい' : 'いいえ'),
      _InfoItem('リリースモード', kReleaseMode ? 'はい' : 'いいえ'),
    ];
  }

  Widget _buildSection(
    BuildContext context,
    String title,
    List<Widget> children,
  ) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(children: children),
          ),
        ),
      ],
    );
  }

  Future<void> _copyAll(BuildContext context, List<_InfoItem> items) async {
    final text = items.map((i) => '${i.label}: ${i.value}').join('\n');
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) {
      ref
          .read(snackBarServiceProvider)
          .success(context: context, message: 'コピーしました');
    }
  }
}

class _InfoItem {
  _InfoItem(this.label, this.value);
  final String label;
  final String value;
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}
