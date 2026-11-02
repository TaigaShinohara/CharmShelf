import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../dip_action_log.dart';
import '../dip_controller.dart';
import '../dip_feature.dart';
import '../../logger/app_logger.dart';
import '../../logger/log_tag.dart';

/// 環境タイプ
enum AppEnvironment {
  development('Development', 'dev', Colors.green),
  staging('Staging', 'stg', Colors.orange),
  production('Production', 'prod', Colors.red);

  const AppEnvironment(this.label, this.shortLabel, this.color);

  final String label;
  final String shortLabel;
  final Color color;
}

/// 現在の環境Provider
final appEnvironmentProvider =
    StateNotifierProvider<AppEnvironmentNotifier, AppEnvironment>(
      (ref) => AppEnvironmentNotifier(),
    );

class AppEnvironmentNotifier extends StateNotifier<AppEnvironment> {
  AppEnvironmentNotifier() : super(AppEnvironment.development) {
    _load();
  }

  static const _key = 'dip_environment';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_key);
    if (value != null) {
      try {
        state = AppEnvironment.values.firstWhere((e) => e.name == value);
      } catch (e, st) {
        // 保存された環境文字列が無効な場合はデフォルト設定を使用
        AppLogger.w(
          LogTag.app,
          '保存された環境値 ($value) のパースに失敗しました。デフォルト設定を使用します。',
          e,
          st,
        );
      }
    }
  }

  Future<void> setEnvironment(AppEnvironment env) async {
    state = env;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, env.name);
  }
}

/// 環境切り替え機能
class EnvSwitchFeature extends DipFeature {
  @override
  String get id => 'env_switch';

  @override
  String get title => '環境切り替え';

  @override
  String? get subtitle => 'Dev/Staging/Prod';

  @override
  IconData get icon => Icons.swap_horiz;

  @override
  DipFeatureCategory get category => DipFeatureCategory.debug;

  @override
  void onTap(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      builder: (context) => const _EnvSwitchSheet(),
    );
  }

  @override
  Widget buildTile(BuildContext context, {VoidCallback? onClose}) {
    final theme = Theme.of(context);

    return Consumer(
      builder: (context, ref, _) {
        final env = ref.watch(appEnvironmentProvider);

        return ListTile(
          leading: Icon(icon, color: theme.colorScheme.primary),
          title: Text(title),
          subtitle: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: env.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  env.label,
                  style: TextStyle(
                    color: env.color,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () async {
            // DIPを閉じてからモーダルを表示
            onClose?.call();

            await showModalBottomSheet<void>(
              context: context,
              useRootNavigator: true,
              builder: (context) => const _EnvSwitchSheet(),
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

class _EnvSwitchSheet extends ConsumerWidget {
  const _EnvSwitchSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentEnv = ref.watch(appEnvironmentProvider);
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
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
              '環境切り替え',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '注意: 環境を切り替えると、APIエンドポイントなどが変更されます',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            // 環境選択
            for (final env in AppEnvironment.values)
              _EnvOption(
                env: env,
                isSelected: env == currentEnv,
                onTap: () {
                  ref.read(appEnvironmentProvider.notifier).setEnvironment(env);
                  DipActionLog.info('環境変更: ${env.label}', tag: 'Env');
                  Navigator.pop(context);
                },
              ),
            const SizedBox(height: 16),
            // 警告
            Card(
              color: theme.colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber,
                      color: theme.colorScheme.onErrorContainer,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '本番環境(Production)では慎重に操作してください',
                        style: TextStyle(
                          color: theme.colorScheme.onErrorContainer,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EnvOption extends StatelessWidget {
  const _EnvOption({
    required this.env,
    required this.isSelected,
    required this.onTap,
  });

  final AppEnvironment env;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? env.color
                  : theme.colorScheme.outline.withValues(alpha: 0.3),
              width: isSelected ? 2 : 1,
            ),
            color: isSelected ? env.color.withValues(alpha: 0.05) : null,
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: env.color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    env.shortLabel.toUpperCase(),
                    style: TextStyle(
                      color: env.color,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      env.label,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: isSelected ? FontWeight.bold : null,
                      ),
                    ),
                    Text(
                      _getDescription(env),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected) Icon(Icons.check_circle, color: env.color),
            ],
          ),
        ),
      ),
    );
  }

  String _getDescription(AppEnvironment env) {
    return switch (env) {
      AppEnvironment.development => '開発・テスト用の環境',
      AppEnvironment.staging => 'リリース前の検証環境',
      AppEnvironment.production => '本番環境（実ユーザー向け）',
    };
  }
}
