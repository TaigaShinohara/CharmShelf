import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../feedback/snackbar_service.dart';
import '../dip_action_log.dart';
import '../dip_feature.dart';

/// モックデータ生成機能
class MockDataFeature extends PanelDipFeature {
  @override
  String get id => 'mock_data';

  @override
  String get title => 'モックデータ生成';

  @override
  String? get subtitle => 'テスト用ダミーデータを作成';

  @override
  IconData get icon => Icons.data_array;

  @override
  DipFeatureCategory get category => DipFeatureCategory.data;

  @override
  Widget? buildPanel(BuildContext context) {
    return const _MockDataPanel();
  }
}

class _MockDataPanel extends ConsumerStatefulWidget {
  const _MockDataPanel();

  @override
  ConsumerState<_MockDataPanel> createState() => _MockDataPanelState();
}

class _MockDataPanelState extends ConsumerState<_MockDataPanel> {
  bool _generating = false;
  int _count = 10;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 説明カード
        Card(
          color: theme.colorScheme.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'テスト用のダミーデータを生成します。\n'
                    'アプリのデータモデルに合わせてカスタマイズしてください。',
                    style: TextStyle(
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        // 生成数設定
        Text(
          '生成設定',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('生成数: $_count'),
                Slider(
                  value: _count.toDouble(),
                  min: 1,
                  max: 100,
                  divisions: 99,
                  label: _count.toString(),
                  onChanged: (value) => setState(() => _count = value.round()),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        // 生成オプション
        Text(
          'データ種類',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        _MockDataOption(
          icon: Icons.person,
          title: 'ユーザーデータ',
          subtitle: '名前、メール、プロフィールなど',
          generating: _generating,
          onGenerate: () => _generate(context, 'user'),
        ),
        const SizedBox(height: 8),
        _MockDataOption(
          icon: Icons.article,
          title: '投稿データ',
          subtitle: 'タイトル、本文、日時など',
          generating: _generating,
          onGenerate: () => _generate(context, 'post'),
        ),
        const SizedBox(height: 8),
        _MockDataOption(
          icon: Icons.comment,
          title: 'コメントデータ',
          subtitle: 'コメント内容、投稿者など',
          generating: _generating,
          onGenerate: () => _generate(context, 'comment'),
        ),
        const SizedBox(height: 8),
        _MockDataOption(
          icon: Icons.notifications,
          title: '通知データ',
          subtitle: '通知タイプ、メッセージなど',
          generating: _generating,
          onGenerate: () => _generate(context, 'notification'),
        ),
        const SizedBox(height: 24),
        // ヘルパー
        Text(
          'データ生成ヘルパー',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'MockDataHelper クラスを使用',
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SelectableText(
                    '''// 使用例
final name = MockDataHelper.randomName();
final email = MockDataHelper.randomEmail();
final text = MockDataHelper.randomText(100);
final date = MockDataHelper.randomDate();''',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _generate(BuildContext context, String type) async {
    setState(() => _generating = true);

    try {
      // モックデータ生成のシミュレーション
      await Future.delayed(const Duration(milliseconds: 500));

      // 実際の実装では、ここでデータベースにデータを挿入
      // 例: await IsarService.instance.isar?.writeTxn(() async { ... });

      DipActionLog.success('$type データを $_count 件生成しました', tag: 'MockData');

      if (context.mounted) {
        ref
            .read(snackBarServiceProvider)
            .success(context: context, message: '$type データを $_count 件生成しました');
      }
    } catch (e) {
      DipActionLog.error('データ生成失敗: $e', tag: 'MockData');
      if (context.mounted) {
        ref
            .read(snackBarServiceProvider)
            .error(context: context, message: 'エラー: $e');
      }
    } finally {
      setState(() => _generating = false);
    }
  }
}

class _MockDataOption extends StatelessWidget {
  const _MockDataOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.generating,
    required this.onGenerate,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool generating;
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: generating
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : IconButton(
                icon: const Icon(Icons.play_arrow),
                onPressed: onGenerate,
              ),
        onTap: generating ? null : onGenerate,
      ),
    );
  }
}

/// モックデータ生成ヘルパークラス
class MockDataHelper {
  static final _random = Random();

  static const _firstNames = [
    '太郎',
    '花子',
    '一郎',
    '美咲',
    '健太',
    '陽子',
    '大輔',
    '愛',
    '翔太',
    '真由美',
  ];
  static const _lastNames = [
    '田中',
    '鈴木',
    '佐藤',
    '高橋',
    '伊藤',
    '山本',
    '中村',
    '小林',
    '加藤',
    '吉田',
  ];
  static const _domains = [
    'example.com',
    'test.com',
    'sample.jp',
    'demo.co.jp',
  ];

  /// ランダムな名前を生成
  static String randomName() {
    final first = _firstNames[_random.nextInt(_firstNames.length)];
    final last = _lastNames[_random.nextInt(_lastNames.length)];
    return '$last $first';
  }

  /// ランダムなメールアドレスを生成
  static String randomEmail() {
    final domain = _domains[_random.nextInt(_domains.length)];
    final name = 'user${_random.nextInt(10000)}';
    return '$name@$domain';
  }

  /// ランダムなテキストを生成
  static String randomText(int maxLength) {
    const chars = 'あいうえおかきくけこさしすせそたちつてとなにぬねのはひふへほまみむめもやゆよらりるれろわをん';
    final length = _random.nextInt(maxLength) + 10;
    return String.fromCharCodes(
      List.generate(
        length,
        (_) => chars.codeUnitAt(_random.nextInt(chars.length)),
      ),
    );
  }

  /// ランダムな日時を生成（過去30日以内）
  static DateTime randomDate() {
    final now = DateTime.now();
    final days = _random.nextInt(30);
    final hours = _random.nextInt(24);
    final minutes = _random.nextInt(60);
    return now.subtract(Duration(days: days, hours: hours, minutes: minutes));
  }

  /// ランダムなIDを生成
  static String randomId() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    return String.fromCharCodes(
      List.generate(16, (_) => chars.codeUnitAt(_random.nextInt(chars.length))),
    );
  }

  /// ランダムな整数を生成
  static int randomInt(int max) => _random.nextInt(max);

  /// ランダムな真偽値を生成
  static bool randomBool() => _random.nextBool();
}
