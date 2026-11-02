import 'package:isar/isar.dart';

import '../logger/app_logger.dart';
import '../logger/log_tag.dart';

/// Isar のスタブ（Web用）
///
/// Webでは Isar が利用できないため、呼び出されたらエラーにします。
class IsarService {
  IsarService._();

  static Future<Isar> instance() async {
    AppLogger.w(LogTag.db, 'WebではIsarは利用できません');
    throw UnsupportedError('WebではIsarは利用できません');
  }

  static Future<void> close() async {
    // no-op
  }
}
