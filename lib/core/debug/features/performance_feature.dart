import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../dip_action_log.dart';
import '../dip_feature.dart';

/// パフォーマンスオーバーレイの状態Provider
final performanceOverlayProvider = StateProvider<bool>((ref) => false);

/// パフォーマンスオーバーレイ機能
class PerformanceFeature extends ToggleDipFeature {
  @override
  String get id => 'performance';

  @override
  String get title => 'パフォーマンス';

  @override
  String? get subtitle => 'FPS・メモリ使用量を表示';

  @override
  IconData get icon => Icons.speed;

  @override
  DipFeatureCategory get category => DipFeatureCategory.debug;

  @override
  bool getValue(BuildContext context) {
    // Providerの値を取得するには、Consumerで囲む必要がある
    // ここでは簡易的にfalseを返し、buildTileでConsumerを使用
    return false;
  }

  @override
  void setValue(BuildContext context, bool value) {
    // buildTileで実装
  }

  @override
  Widget buildTile(BuildContext context, {VoidCallback? onClose}) {
    final theme = Theme.of(context);

    return Consumer(
      builder: (context, ref, _) {
        final isEnabled = ref.watch(performanceOverlayProvider);

        return ListTile(
          leading: Icon(icon, color: theme.colorScheme.primary),
          title: Text(title),
          subtitle: Text(isEnabled ? 'ON' : 'OFF'),
          trailing: Switch(
            value: isEnabled,
            onChanged: (value) {
              ref.read(performanceOverlayProvider.notifier).state = value;
              DipActionLog.info(
                'パフォーマンスオーバーレイ: ${value ? "ON" : "OFF"}',
                tag: 'Debug',
              );
            },
          ),
          onTap: () {
            final newValue = !isEnabled;
            ref.read(performanceOverlayProvider.notifier).state = newValue;
            DipActionLog.info(
              'パフォーマンスオーバーレイ: ${newValue ? "ON" : "OFF"}',
              tag: 'Debug',
            );
          },
        );
      },
    );
  }
}
