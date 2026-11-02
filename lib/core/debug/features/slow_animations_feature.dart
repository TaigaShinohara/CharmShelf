import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../dip_action_log.dart';
import '../dip_feature.dart';

/// スローアニメーション機能
class SlowAnimationsFeature extends ToggleDipFeature {
  @override
  String get id => 'slow_animations';

  @override
  String get title => 'スローアニメーション';

  @override
  String? get subtitle => 'アニメーション速度を低下';

  @override
  IconData get icon => Icons.slow_motion_video;

  @override
  DipFeatureCategory get category => DipFeatureCategory.ui;

  @override
  bool getValue(BuildContext context) {
    return timeDilation != 1.0;
  }

  @override
  void setValue(BuildContext context, bool value) {
    timeDilation = value ? 5.0 : 1.0;
    DipActionLog.info('スローアニメーション: ${value ? "ON (5x)" : "OFF"}', tag: 'UI');
  }

  @override
  Widget buildTile(BuildContext context, {VoidCallback? onClose}) {
    final theme = Theme.of(context);
    return StatefulBuilder(
      builder: (context, setState) {
        final isEnabled = getValue(context);
        return ListTile(
          leading: Icon(icon, color: theme.colorScheme.primary),
          title: Text(title),
          subtitle: Text(isEnabled ? 'ON (5倍スロー)' : 'OFF'),
          trailing: Switch(
            value: isEnabled,
            onChanged: (value) {
              setValue(context, value);
              setState(() {});
            },
          ),
          onTap: () {
            setValue(context, !isEnabled);
            setState(() {});
          },
        );
      },
    );
  }
}
