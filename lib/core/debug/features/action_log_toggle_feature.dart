import 'package:flutter/material.dart';

import '../dip_action_log.dart';
import '../dip_feature.dart';

/// 動作ログSnackBar表示のON/OFF機能
class ActionLogToggleFeature extends ToggleDipFeature {
  @override
  String get id => 'action_log_toggle';

  @override
  String get title => '動作ログ表示';

  @override
  String? get subtitle => 'アプリ内操作をSnackBarで通知';

  @override
  IconData get icon => Icons.notifications_active_outlined;

  @override
  DipFeatureCategory get category => DipFeatureCategory.debug;

  @override
  bool getValue(BuildContext context) {
    return DipActionLog.isEnabled;
  }

  @override
  void setValue(BuildContext context, bool value) {
    DipActionLog.setEnabled(value);
    if (value) {
      DipActionLog.info('動作ログ表示を有効化しました', tag: 'DIP');
    }
  }
}
