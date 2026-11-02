import 'package:flutter/foundation.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

import '../logger/app_logger.dart';
import '../logger/log_tag.dart';

/// Isar の初期化・参照をまとめるサービス（iOS/Android/desktop用）
///
/// - 量産テンプレの前提として、アプリ内の永続データは Isar に集約する
/// - 注意: 実際のスキーマは `isar_provider.dart` を参照
/// - このファイルは旧テンプレート互換のため残存（使用箇所がなくなれば削除可能）
class IsarService {
  IsarService._();

  static Isar? _instance;

  static Future<Isar> instance() async {
    if (_instance != null) {
      AppLogger.v(LogTag.db, 'Isarインスタンスを再利用');
      return _instance!;
    }

    AppLogger.i(LogTag.db, 'Isarデータベースを初期化中...');
    final stopwatch = AppLogger.startTimer(LogTag.db, 'Isar初期化');

    try {
      final dir = await getApplicationSupportDirectory();
      AppLogger.d(LogTag.db, 'データベース保存先: ${dir.path}');

      _instance = await Isar.open(
        [],
        directory: dir.path,
        inspector: kDebugMode,
      );

      AppLogger.endTimer(LogTag.db, 'Isar初期化', stopwatch);
      AppLogger.i(LogTag.db, 'Isarデータベース初期化完了');
      return _instance!;
    } catch (e, st) {
      AppLogger.e(LogTag.db, 'Isarデータベース初期化に失敗', e, st);
      rethrow;
    }
  }

  /// データベースを閉じる
  static Future<void> close() async {
    if (_instance != null) {
      AppLogger.i(LogTag.db, 'Isarデータベースを閉じています...');
      await _instance!.close();
      _instance = null;
      AppLogger.i(LogTag.db, 'Isarデータベースを閉じました');
    }
  }
}
