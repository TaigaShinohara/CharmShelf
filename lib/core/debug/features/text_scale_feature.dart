import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../dip_action_log.dart';
import '../dip_controller.dart';
import '../dip_feature.dart';

/// テキストスケールのProvider
final textScaleProvider = StateNotifierProvider<TextScaleNotifier, double>(
  (ref) => TextScaleNotifier(),
);

class TextScaleNotifier extends StateNotifier<double> {
  TextScaleNotifier() : super(1.0) {
    _load();
  }

  static const _key = 'dip_text_scale';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getDouble(_key) ?? 1.0;
  }

  Future<void> setScale(double scale) async {
    state = scale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_key, scale);
  }
}

/// テキストサイズ変更機能
class TextScaleFeature extends DipFeature {
  @override
  String get id => 'text_scale';

  @override
  String get title => 'テキストサイズ';

  @override
  String? get subtitle => '文字サイズを調整';

  @override
  IconData get icon => Icons.text_fields;

  @override
  DipFeatureCategory get category => DipFeatureCategory.ui;

  @override
  bool get showInSettings => true;

  @override
  void onTap(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      builder: (context) => const _TextScaleSheet(),
    );
  }

  @override
  Widget buildTile(BuildContext context, {VoidCallback? onClose}) {
    return Consumer(
      builder: (context, ref, _) {
        final scale = ref.watch(textScaleProvider);
        final theme = Theme.of(context);

        return ListTile(
          leading: Icon(icon, color: theme.colorScheme.primary),
          title: Text(title),
          subtitle: Text('${(scale * 100).round()}%'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () async {
            // DIPを閉じてからモーダルを表示
            onClose?.call();

            await showModalBottomSheet<void>(
              context: context,
              useRootNavigator: true,
              builder: (context) => const _TextScaleSheet(),
            );

            // モーダルが閉じたらDIPを再表示
            WidgetsBinding.instance.addPostFrameCallback((_) {
              DipController.showWithLastOverlay();
            });
          },
        );
      },
    );
  }
}

class _TextScaleSheet extends ConsumerStatefulWidget {
  const _TextScaleSheet();

  @override
  ConsumerState<_TextScaleSheet> createState() => _TextScaleSheetState();
}

class _TextScaleSheetState extends ConsumerState<_TextScaleSheet> {
  late double _scale;

  @override
  void initState() {
    super.initState();
    _scale = ref.read(textScaleProvider);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ハンドル
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outline.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            // タイトル
            Text(
              'テキストサイズ',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            // プレビュー
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(_scale)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('プレビュー', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Text('これは通常のテキストです。', style: theme.textTheme.bodyMedium),
                      Text(
                        'This is a sample text.',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            // スライダー
            Row(
              children: [
                const Icon(Icons.text_decrease),
                Expanded(
                  child: Slider(
                    value: _scale,
                    min: 0.8,
                    max: 2.0,
                    divisions: 24,
                    label: '${(_scale * 100).round()}%',
                    onChanged: (value) => setState(() => _scale = value),
                  ),
                ),
                const Icon(Icons.text_increase),
              ],
            ),
            Text(
              '${(_scale * 100).round()}%',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            // プリセットボタン
            Wrap(
              spacing: 8,
              children: [
                _PresetChip(
                  label: '小 (80%)',
                  scale: 0.8,
                  current: _scale,
                  onTap: () => setState(() => _scale = 0.8),
                ),
                _PresetChip(
                  label: '標準 (100%)',
                  scale: 1.0,
                  current: _scale,
                  onTap: () => setState(() => _scale = 1.0),
                ),
                _PresetChip(
                  label: '大 (120%)',
                  scale: 1.2,
                  current: _scale,
                  onTap: () => setState(() => _scale = 1.2),
                ),
                _PresetChip(
                  label: '特大 (150%)',
                  scale: 1.5,
                  current: _scale,
                  onTap: () => setState(() => _scale = 1.5),
                ),
                _PresetChip(
                  label: '最大 (200%)',
                  scale: 2.0,
                  current: _scale,
                  onTap: () => setState(() => _scale = 2.0),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // 適用ボタン
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('キャンセル'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      ref.read(textScaleProvider.notifier).setScale(_scale);
                      DipActionLog.info(
                        'テキストサイズ変更: ${(_scale * 100).round()}%',
                        tag: 'UI',
                      );
                      Navigator.pop(context);
                    },
                    child: const Text('適用'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PresetChip extends StatelessWidget {
  const _PresetChip({
    required this.label,
    required this.scale,
    required this.current,
    required this.onTap,
  });

  final String label;
  final double scale;
  final double current;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isSelected = (current - scale).abs() < 0.01;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onTap(),
    );
  }
}
