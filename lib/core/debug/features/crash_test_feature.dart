import 'package:flutter/material.dart';
import 'package:private_shelf/shared/widgets/dialogs/dialog_actions.dart';

import '../dip_action_log.dart';
import '../dip_feature.dart';

/// クラッシュテスト機能
class CrashTestFeature extends PanelDipFeature {
  @override
  String get id => 'crash_test';

  @override
  String get title => 'クラッシュテスト';

  @override
  String? get subtitle => '意図的なクラッシュを発生';

  @override
  IconData get icon => Icons.warning_amber;

  @override
  DipFeatureCategory get category => DipFeatureCategory.test;

  @override
  Widget? buildPanel(BuildContext context) {
    return const _CrashTestPanel();
  }
}

class _CrashTestPanel extends StatelessWidget {
  const _CrashTestPanel();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 警告カード
        Card(
          color: theme.colorScheme.errorContainer,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Icon(
                  Icons.warning_amber,
                  color: theme.colorScheme.onErrorContainer,
                  size: 48,
                ),
                const SizedBox(height: 8),
                Text(
                  '注意: これらのボタンはアプリをクラッシュさせます',
                  style: TextStyle(
                    color: theme.colorScheme.onErrorContainer,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  'クラッシュレポートのテストや、エラーハンドリングの確認に使用してください',
                  style: TextStyle(
                    color: theme.colorScheme.onErrorContainer,
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        // クラッシュオプション
        Text(
          'クラッシュタイプ',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        _CrashOption(
          icon: Icons.error,
          title: 'Dart例外（キャッチ可能）',
          subtitle: 'throw Exception()を実行',
          color: Colors.orange,
          onTap: () => _triggerDartException(context),
        ),
        const SizedBox(height: 8),
        _CrashOption(
          icon: Icons.error_outline,
          title: 'Dart例外（キャッチ不可）',
          subtitle: 'runZonedGuarded外でthrow',
          color: Colors.deepOrange,
          onTap: () => _triggerUncaughtException(context),
        ),
        const SizedBox(height: 8),
        _CrashOption(
          icon: Icons.bug_report,
          title: 'アサーションエラー',
          subtitle: 'assert(false)を実行',
          color: Colors.red,
          onTap: () => _triggerAssertionError(context),
        ),
        const SizedBox(height: 8),
        _CrashOption(
          icon: Icons.memory,
          title: 'Stack Overflow',
          subtitle: '無限再帰を実行',
          color: Colors.purple,
          onTap: () => _triggerStackOverflow(context),
        ),
        const SizedBox(height: 8),
        _CrashOption(
          icon: Icons.dangerous,
          title: 'Null参照',
          subtitle: 'nullに対してメソッド呼び出し',
          color: Colors.red.shade900,
          onTap: () => _triggerNullReference(context),
        ),
        const SizedBox(height: 24),
        // 説明
        Text(
          'テストの目的',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _TestPurpose(
                  icon: Icons.analytics,
                  title: 'クラッシュレポート確認',
                  description: 'Firebase Crashlytics等のクラッシュレポートが正しく動作しているか確認',
                ),
                SizedBox(height: 12),
                _TestPurpose(
                  icon: Icons.shield,
                  title: 'エラーハンドリング確認',
                  description: 'GlobalErrorHandlerが正しくエラーを捕捉できているか確認',
                ),
                SizedBox(height: 12),
                _TestPurpose(
                  icon: Icons.restore,
                  title: 'リカバリー動作確認',
                  description: 'クラッシュ後のアプリ再起動とデータ復元が正常か確認',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _triggerDartException(BuildContext context) async {
    final confirmed = await _confirmCrash(context, 'Dart例外');
    if (!confirmed) return;

    DipActionLog.warning('クラッシュテスト: Dart例外', tag: 'Crash');
    throw Exception('DIP Test: Intentional Dart Exception');
  }

  Future<void> _triggerUncaughtException(BuildContext context) async {
    final confirmed = await _confirmCrash(context, 'キャッチ不可例外');
    if (!confirmed) return;

    DipActionLog.warning('クラッシュテスト: キャッチ不可例外', tag: 'Crash');

    // Futureを使って非同期で例外を発生させる
    Future.delayed(Duration.zero, () {
      throw StateError('DIP Test: Uncaught Exception');
    });
  }

  Future<void> _triggerAssertionError(BuildContext context) async {
    final confirmed = await _confirmCrash(context, 'アサーションエラー');
    if (!confirmed) return;

    DipActionLog.warning('クラッシュテスト: アサーションエラー', tag: 'Crash');
    assert(false, 'DIP Test: Intentional Assertion Error');
  }

  Future<void> _triggerStackOverflow(BuildContext context) async {
    final confirmed = await _confirmCrash(context, 'Stack Overflow');
    if (!confirmed) return;

    DipActionLog.warning('クラッシュテスト: Stack Overflow', tag: 'Crash');
    _infiniteRecursion();
  }

  void _infiniteRecursion() {
    _infiniteRecursion();
  }

  Future<void> _triggerNullReference(BuildContext context) async {
    final confirmed = await _confirmCrash(context, 'Null参照');
    if (!confirmed) return;

    DipActionLog.warning('クラッシュテスト: Null参照', tag: 'Crash');
    // ignore: avoid_dynamic_calls
    (null as dynamic).someMethod();
  }

  Future<bool> _confirmCrash(BuildContext context, String type) async {
    final result = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (dialogContext) => AlertDialog(
        title: const Text('クラッシュを実行しますか？'),
        content: Text('$type を発生させます。\nアプリがクラッシュする可能性があります。'),
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
              child: const Text('実行'),
            ),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}

class _CrashOption extends StatelessWidget {
  const _CrashOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: ElevatedButton(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
          ),
          child: const Text('実行'),
        ),
      ),
    );
  }
}

class _TestPurpose extends StatelessWidget {
  const _TestPurpose({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                description,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
