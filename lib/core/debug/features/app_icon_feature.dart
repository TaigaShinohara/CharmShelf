import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../feedback/snackbar_service.dart';
import '../dip_action_log.dart';
import '../dip_feature.dart';

/// アプリアイコン変更機能
///
/// iOSのAlternate App Iconsを使用してアプリアイコンを動的に変更します。
/// 注意: この機能はiOSのみで動作し、事前にInfo.plistでアイコンを設定する必要があります。
class AppIconFeature extends PanelDipFeature {
  @override
  String get id => 'app_icon';

  @override
  String get title => 'アプリアイコン';

  @override
  String? get subtitle => '動的にアイコンを変更 (iOS)';

  @override
  IconData get icon => Icons.app_settings_alt;

  @override
  DipFeatureCategory get category => DipFeatureCategory.ui;

  @override
  Widget? buildPanel(BuildContext context) {
    return const _AppIconPanel();
  }
}

class _AppIconPanel extends ConsumerStatefulWidget {
  const _AppIconPanel();

  @override
  ConsumerState<_AppIconPanel> createState() => _AppIconPanelState();
}

class _AppIconPanelState extends ConsumerState<_AppIconPanel> {
  String? _currentIcon;
  bool _loading = true;

  // 利用可能なアイコン（Info.plistで定義が必要）
  // アプリごとにカスタマイズしてください
  final _availableIcons = <_IconOption>[
    _IconOption(
      id: null, // デフォルトアイコン
      name: 'デフォルト',
      color: Colors.blue,
    ),
    _IconOption(id: 'AppIcon-Dark', name: 'ダーク', color: Colors.grey.shade800),
    _IconOption(id: 'AppIcon-Light', name: 'ライト', color: Colors.grey.shade200),
    _IconOption(id: 'AppIcon-Red', name: 'レッド', color: Colors.red),
    _IconOption(id: 'AppIcon-Green', name: 'グリーン', color: Colors.green),
  ];

  @override
  void initState() {
    super.initState();
    _loadCurrentIcon();
  }

  Future<void> _loadCurrentIcon() async {
    try {
      // iOS: 現在のアイコンを取得
      // 実際の実装ではMethodChannelを使用
      setState(() {
        _currentIcon = null; // デフォルト
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 説明カード
        Card(
          color: theme.colorScheme.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'iOS専用機能',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'この機能はiOSのAlternate App Iconsを使用します。\n'
                  '使用するにはInfo.plistでアイコンを設定する必要があります。',
                  style: TextStyle(color: theme.colorScheme.onPrimaryContainer),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        // アイコン選択
        Text(
          'アイコンを選択',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 0.8,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: _availableIcons.length,
          itemBuilder: (context, index) {
            final option = _availableIcons[index];
            final isSelected = _currentIcon == option.id;
            return _IconCard(
              option: option,
              isSelected: isSelected,
              onTap: () => _changeIcon(context, option),
            );
          },
        ),
        const SizedBox(height: 24),
        // 設定方法
        ExpansionTile(
          leading: const Icon(Icons.help_outline),
          title: const Text('設定方法'),
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '1. Xcodeでアイコンセットを追加',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Assets.xcassetsに新しいApp Iconセットを作成します。',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '2. Info.plistを編集',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: SelectableText(
                      '''<key>CFBundleIcons</key>
<dict>
  <key>CFBundleAlternateIcons</key>
  <dict>
    <key>AppIcon-Dark</key>
    <dict>
      <key>CFBundleIconFiles</key>
      <array>
        <string>AppIcon-Dark</string>
      </array>
    </dict>
  </dict>
</dict>''',
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
      ],
    );
  }

  Future<void> _changeIcon(BuildContext context, _IconOption option) async {
    try {
      // iOSのAlternate App Iconsを変更
      // 実際の実装ではMethodChannelを使用
      const channel = MethodChannel('app_icon');
      await channel.invokeMethod('setAlternateIcon', {'iconName': option.id});

      setState(() => _currentIcon = option.id);
      DipActionLog.success('アイコン変更: ${option.name}', tag: 'UI');

      if (context.mounted) {
        ref
            .read(snackBarServiceProvider)
            .success(context: context, message: 'アイコンを「${option.name}」に変更しました');
      }
    } on PlatformException catch (e) {
      DipActionLog.error('アイコン変更失敗: ${e.message}', tag: 'UI');
      if (context.mounted) {
        ref
            .read(snackBarServiceProvider)
            .error(context: context, message: 'アイコンの変更に失敗しました: ${e.message}');
      }
    } catch (e) {
      // プラットフォーム非対応の場合
      if (context.mounted) {
        ref
            .read(snackBarServiceProvider)
            .info(context: context, message: 'この機能はiOSでのみ利用可能です');
      }
    }
  }
}

class _IconOption {
  _IconOption({required this.id, required this.name, required this.color});

  final String? id;
  final String name;
  final Color color;
}

class _IconCard extends StatelessWidget {
  const _IconCard({
    required this.option,
    required this.isSelected,
    required this.onTap,
  });

  final _IconOption option;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.outline.withValues(alpha: 0.3),
            width: isSelected ? 3 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // アイコンプレビュー
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: option.color,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: option.color.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                Icons.apps,
                color: option.color.computeLuminance() > 0.5
                    ? Colors.black
                    : Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              option.name,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: isSelected ? FontWeight.bold : null,
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: theme.colorScheme.primary,
                size: 16,
              ),
          ],
        ),
      ),
    );
  }
}
