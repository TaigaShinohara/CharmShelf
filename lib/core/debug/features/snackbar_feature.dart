import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:private_shelf/shared/widgets/dialogs/dialog_actions.dart';

import '../../feedback/snackbar_config.dart';
import '../../feedback/snackbar_providers.dart';
import '../../feedback/snackbar_service.dart';
import '../dip_feature.dart';

/// SnackBarカスタマイズ機能
///
/// DIPメニューからSnackBarのスタイルを変更・プレビューできます。
class SnackBarFeature extends PanelDipFeature {
  @override
  String get id => 'snackbar_customization';

  @override
  String get title => 'SnackBarカスタマイズ';

  @override
  String? get subtitle => 'スタイル変更・プレビュー';

  @override
  IconData get icon => Icons.notifications_outlined;

  @override
  DipFeatureCategory get category => DipFeatureCategory.ui;

  @override
  Widget? buildPanel(BuildContext context) {
    return const _SnackBarCustomizationPanel();
  }
}

class _SnackBarCustomizationPanel extends ConsumerStatefulWidget {
  const _SnackBarCustomizationPanel();

  @override
  ConsumerState<_SnackBarCustomizationPanel> createState() =>
      _SnackBarCustomizationPanelState();
}

class _SnackBarCustomizationPanelState
    extends ConsumerState<_SnackBarCustomizationPanel> {
  SnackBarType _selectedType = SnackBarType.defaultType;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final config = ref.watch(snackBarConfigNotifierProvider);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // === プレビューセクション ===
        const _SectionHeader(title: 'プレビュー', icon: Icons.preview),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // タイプ選択
                SegmentedButton<SnackBarType>(
                  segments: SnackBarType.values.map((type) {
                    return ButtonSegment<SnackBarType>(
                      value: type,
                      label: Text(
                        type.name,
                        style: const TextStyle(fontSize: 12),
                      ),
                    );
                  }).toList(),
                  selected: {_selectedType},
                  onSelectionChanged: (selection) {
                    setState(() => _selectedType = selection.first);
                  },
                ),
                const SizedBox(height: 16),
                // プレビューボタン
                ElevatedButton.icon(
                  onPressed: () => _showPreview(context),
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('SnackBarを表示'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // === 位置・動作設定 ===
        const _SectionHeader(title: '位置・動作', icon: Icons.swap_vert),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              // 表示位置
              ListTile(
                title: const Text('表示位置'),
                trailing: SegmentedButton<SnackBarPosition>(
                  segments: const [
                    ButtonSegment(
                      value: SnackBarPosition.top,
                      label: Text('上部'),
                    ),
                    ButtonSegment(
                      value: SnackBarPosition.bottom,
                      label: Text('下部'),
                    ),
                  ],
                  selected: {config.position},
                  onSelectionChanged: (selection) {
                    ref
                        .read(snackBarConfigNotifierProvider.notifier)
                        .setPosition(selection.first);
                  },
                ),
              ),
              const Divider(height: 1),
              // 表示動作
              ListTile(
                title: const Text('表示動作'),
                trailing: SegmentedButton<SnackBarBehavior>(
                  segments: const [
                    ButtonSegment(
                      value: SnackBarBehavior.floating,
                      label: Text('浮遊'),
                    ),
                    ButtonSegment(
                      value: SnackBarBehavior.fixed,
                      label: Text('固定'),
                    ),
                  ],
                  selected: {config.behavior},
                  onSelectionChanged: (selection) {
                    ref
                        .read(snackBarConfigNotifierProvider.notifier)
                        .setBehavior(selection.first);
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // === アニメーション設定 ===
        const _SectionHeader(title: 'アニメーション', icon: Icons.animation),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              ListTile(
                title: const Text('アニメーションタイプ'),
                trailing: DropdownButton<SnackBarAnimation>(
                  value: config.animation,
                  onChanged: (value) {
                    if (value != null) {
                      ref
                          .read(snackBarConfigNotifierProvider.notifier)
                          .setAnimation(value);
                    }
                  },
                  items: SnackBarAnimation.values.map((anim) {
                    return DropdownMenuItem(
                      value: anim,
                      child: Text(_getAnimationLabel(anim)),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // === 表示時間設定 ===
        const _SectionHeader(title: '表示時間', icon: Icons.timer),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${config.duration.inMilliseconds}ms',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Slider(
                  value: config.duration.inMilliseconds.toDouble(),
                  min: 500,
                  max: 10000,
                  divisions: 19,
                  label: '${config.duration.inMilliseconds}ms',
                  onChanged: (value) {
                    ref
                        .read(snackBarConfigNotifierProvider.notifier)
                        .setDuration(Duration(milliseconds: value.toInt()));
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // === 形状設定 ===
        const _SectionHeader(title: '形状', icon: Icons.rounded_corner),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              // 角丸
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '角丸: ${config.borderRadius.toInt()}px',
                      style: theme.textTheme.bodyMedium,
                    ),
                    Slider(
                      value: config.borderRadius,
                      min: 0,
                      max: 24,
                      divisions: 24,
                      onChanged: (value) {
                        ref
                            .read(snackBarConfigNotifierProvider.notifier)
                            .setBorderRadius(value);
                      },
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // 影の高さ
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'エレベーション: ${config.elevation.toInt()}',
                      style: theme.textTheme.bodyMedium,
                    ),
                    Slider(
                      value: config.elevation,
                      min: 0,
                      max: 24,
                      divisions: 24,
                      onChanged: (value) {
                        ref
                            .read(snackBarConfigNotifierProvider.notifier)
                            .setElevation(value);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // === アイコン設定 ===
        const _SectionHeader(
          title: 'アイコン',
          icon: Icons.emoji_emotions_outlined,
        ),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              SwitchListTile(
                title: const Text('アイコンを表示'),
                value: config.showIcon,
                onChanged: (value) {
                  ref
                      .read(snackBarConfigNotifierProvider.notifier)
                      .setShowIcon(value);
                },
              ),
              if (config.showIcon) ...[
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'アイコンサイズ: ${config.iconSize.toInt()}px',
                        style: theme.textTheme.bodyMedium,
                      ),
                      Slider(
                        value: config.iconSize,
                        min: 12,
                        max: 32,
                        divisions: 20,
                        onChanged: (value) {
                          ref
                              .read(snackBarConfigNotifierProvider.notifier)
                              .setIconSize(value);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 24),

        // === 色設定 ===
        const _SectionHeader(title: 'タイプ別色設定', icon: Icons.palette),
        const SizedBox(height: 8),
        ...SnackBarType.values.map((type) {
          return _ColorConfigCard(
            type: type,
            colors: config.getColorsForType(type),
            onBackgroundChanged: (color) {
              ref
                  .read(snackBarConfigNotifierProvider.notifier)
                  .setBackgroundColor(type, color);
            },
            onTextChanged: (color) {
              ref
                  .read(snackBarConfigNotifierProvider.notifier)
                  .setTextColor(type, color);
            },
            onIconChanged: (color) {
              ref
                  .read(snackBarConfigNotifierProvider.notifier)
                  .setIconColor(type, color);
            },
          );
        }),
        const SizedBox(height: 24),

        // === リセットボタン ===
        OutlinedButton.icon(
          onPressed: () {
            ref.read(snackBarConfigNotifierProvider.notifier).reset();
          },
          icon: const Icon(Icons.refresh),
          label: const Text('デフォルトに戻す'),
          style: OutlinedButton.styleFrom(
            foregroundColor: theme.colorScheme.error,
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  void _showPreview(BuildContext context) {
    final service = ref.read(snackBarServiceProvider);
    service.show(
      context: context,
      message: 'これはプレビュー用のSnackBarです',
      type: _selectedType,
    );
  }

  String _getAnimationLabel(SnackBarAnimation animation) {
    return switch (animation) {
      SnackBarAnimation.slide => 'スライド',
      SnackBarAnimation.fade => 'フェード',
      SnackBarAnimation.scale => 'スケール',
      SnackBarAnimation.none => 'なし',
    };
  }
}

/// セクションヘッダー
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
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
    );
  }
}

/// 色設定カード
class _ColorConfigCard extends StatelessWidget {
  const _ColorConfigCard({
    required this.type,
    required this.colors,
    required this.onBackgroundChanged,
    required this.onTextChanged,
    required this.onIconChanged,
  });

  final SnackBarType type;
  final SnackBarTypeColors colors;
  final ValueChanged<Color> onBackgroundChanged;
  final ValueChanged<Color> onTextChanged;
  final ValueChanged<Color> onIconChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        leading: type.icon != null
            ? Icon(type.icon, color: colors.background)
            : Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: colors.background,
                  shape: BoxShape.circle,
                ),
              ),
        title: Text(_getTypeLabel(type)),
        children: [
          _ColorPickerTile(
            label: '背景色',
            color: colors.background,
            onColorChanged: onBackgroundChanged,
          ),
          _ColorPickerTile(
            label: 'テキスト色',
            color: colors.text,
            onColorChanged: onTextChanged,
          ),
          _ColorPickerTile(
            label: 'アイコン色',
            color: colors.icon,
            onColorChanged: onIconChanged,
          ),
        ],
      ),
    );
  }

  String _getTypeLabel(SnackBarType type) {
    return switch (type) {
      SnackBarType.success => '成功',
      SnackBarType.error => 'エラー',
      SnackBarType.warning => '警告',
      SnackBarType.info => '情報',
      SnackBarType.defaultType => 'デフォルト',
    };
  }
}

/// 色選択タイル
class _ColorPickerTile extends StatelessWidget {
  const _ColorPickerTile({
    required this.label,
    required this.color,
    required this.onColorChanged,
  });

  final String label;
  final Color color;
  final ValueChanged<Color> onColorChanged;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(label),
      trailing: GestureDetector(
        onTap: () => _showColorPicker(context),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
        ),
      ),
    );
  }

  Future<void> _showColorPicker(BuildContext context) async {
    final result = await showDialog<Color>(
      context: context,
      useRootNavigator: true,
      builder: (dialogContext) => _SimpleColorPickerDialog(initialColor: color),
    );
    if (result != null) {
      onColorChanged(result);
    }
  }
}

/// シンプルなカラーピッカーダイアログ
class _SimpleColorPickerDialog extends StatefulWidget {
  const _SimpleColorPickerDialog({required this.initialColor});

  final Color initialColor;

  @override
  State<_SimpleColorPickerDialog> createState() =>
      _SimpleColorPickerDialogState();
}

class _SimpleColorPickerDialogState extends State<_SimpleColorPickerDialog> {
  late Color _selectedColor;

  // プリセット色
  static const List<Color> _presetColors = [
    Colors.red,
    Colors.pink,
    Colors.purple,
    Colors.deepPurple,
    Colors.indigo,
    Colors.blue,
    Colors.lightBlue,
    Colors.cyan,
    Colors.teal,
    Colors.green,
    Colors.lightGreen,
    Colors.lime,
    Colors.yellow,
    Colors.amber,
    Colors.orange,
    Colors.deepOrange,
    Colors.brown,
    Colors.grey,
    Colors.blueGrey,
    Colors.black,
    Colors.white,
    Color(0xFF323232),
  ];

  @override
  void initState() {
    super.initState();
    _selectedColor = widget.initialColor;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      actionsAlignment: MainAxisAlignment.spaceBetween,
      title: const Text('色を選択'),
      content: SizedBox(
        width: 280,
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _presetColors.map((color) {
            final isSelected = _selectedColor == color;
            return GestureDetector(
              onTap: () => setState(() => _selectedColor = color),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected ? Colors.blue : Colors.grey.shade300,
                    width: isSelected ? 3 : 1,
                  ),
                ),
                child: isSelected
                    ? Icon(
                        Icons.check,
                        color: color.computeLuminance() > 0.5
                            ? Colors.black
                            : Colors.white,
                      )
                    : null,
              ),
            );
          }).toList(),
        ),
      ),
      actions: [
        DialogActionRow(
          leading: DialogCloseButton(
            onPressed: () => Navigator.pop(context),
            semanticLabel: 'キャンセル',
          ),
          trailing: ElevatedButton(
            onPressed: () => Navigator.pop(context, _selectedColor),
            child: const Text('選択'),
          ),
        ),
      ],
    );
  }
}
