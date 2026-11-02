import 'package:shared_preferences/shared_preferences.dart';

import '../logger/app_logger.dart';
import '../logger/log_tag.dart';

/// Isarスキーマのバージョン管理とマイグレーションを支援するヘルパー
///
/// Isarはスキーマの変更を自動的に処理しますが、
/// データ移行が必要な場合はこのヘルパーを使用します。
///
/// 使用例:
/// ```dart
/// // アプリ起動時
/// final migrationHelper = IsarMigrationHelper();
/// await migrationHelper.runMigrations();
/// ```
class IsarMigrationHelper {
  static const String _schemaVersionKey = 'isar_schema_version';

  /// 現在のスキーマバージョン
  /// スキーマを変更した場合は、このバージョンを上げてください。
  static const int currentSchemaVersion = 1;

  /// マイグレーションを実行
  ///
  /// 保存されているバージョンと現在のバージョンを比較し、
  /// 必要に応じてマイグレーションを実行します。
  Future<void> runMigrations() async {
    final prefs = await SharedPreferences.getInstance();
    final storedVersion = prefs.getInt(_schemaVersionKey) ?? 0;

    if (storedVersion == currentSchemaVersion) {
      AppLogger.d(LogTag.db, 'マイグレーション不要 (version: $currentSchemaVersion)');
      return;
    }

    AppLogger.i(
      LogTag.db,
      'マイグレーション開始: v$storedVersion → v$currentSchemaVersion',
    );

    // バージョンごとのマイグレーションを順番に実行
    for (
      var version = storedVersion + 1;
      version <= currentSchemaVersion;
      version++
    ) {
      await _migrateToVersion(version);
    }

    // バージョンを更新
    await prefs.setInt(_schemaVersionKey, currentSchemaVersion);
    AppLogger.i(LogTag.db, 'マイグレーション完了');
  }

  /// 特定のバージョンへのマイグレーションを実行
  Future<void> _migrateToVersion(int version) async {
    AppLogger.d(LogTag.db, 'マイグレーション実行中: v$version');

    switch (version) {
      case 1:
        await _migrateToV1();
        break;
      // 将来のバージョン用
      // case 2:
      //   await _migrateToV2();
      //   break;
      default:
        AppLogger.w(LogTag.db, '未知のマイグレーションバージョン: $version');
    }
  }

  /// v1 へのマイグレーション（初期スキーマ）
  Future<void> _migrateToV1() async {
    // 初期バージョンは特別な処理不要
    AppLogger.d(LogTag.db, 'v1マイグレーション: 初期スキーマ（処理なし）');
  }

  /// スキーマバージョンをリセット（開発用）
  ///
  /// 注意: 本番環境では使用しないでください。
  Future<void> resetSchemaVersion() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_schemaVersionKey);
    AppLogger.w(LogTag.db, 'スキーマバージョンをリセットしました');
  }

  /// 現在保存されているスキーマバージョンを取得
  Future<int> getStoredSchemaVersion() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_schemaVersionKey) ?? 0;
  }
}

/// マイグレーション例: フィールド追加時のデータ移行
///
/// Isarは新しいフィールドの追加を自動的に処理しますが、
/// 既存データにデフォルト値を設定したい場合などに使用します。
///
/// ```dart
/// Future<void> _migrateToV2() async {
///   final isar = await IsarService.instance();
///
///   // 既存の全レコードを更新
///   await isar.writeTxn(() async {
///     final allRecords = await isar.myCollection.where().findAll();
///     for (final record in allRecords) {
///       if (record.newField == null) {
///         record.newField = 'default_value';
///         await isar.myCollection.put(record);
///       }
///     }
///   });
/// }
/// ```

/// マイグレーション例: コレクション名変更時
///
/// コレクション名を変更する場合は、データのコピーが必要です。
///
/// ```dart
/// Future<void> _migrateToV3() async {
///   final isar = await IsarService.instance();
///
///   // 1. 古いコレクションからデータを読み取り
///   final oldData = await isar.oldCollection.where().findAll();
///
///   // 2. 新しいコレクションにデータをコピー
///   await isar.writeTxn(() async {
///     for (final item in oldData) {
///       final newItem = NewModel()
///         ..field1 = item.field1
///         ..field2 = item.field2;
///       await isar.newCollection.put(newItem);
///     }
///
///     // 3. 古いデータを削除
///     await isar.oldCollection.clear();
///   });
/// }
/// ```

/// Isarスキーマ変更のチェックリスト
///
/// スキーマを変更する際は、以下の手順に従ってください:
///
/// 1. データモデル（@collection）を変更
/// 2. `IsarService.instance()` のコレクションリストを更新
/// 3. `IsarMigrationHelper.currentSchemaVersion` を上げる
/// 4. `_migrateToVersion` に新しいケースを追加
/// 5. マイグレーション処理を実装
/// 6. テストを実行
///
/// 破壊的変更（フィールド削除、型変更など）の場合:
/// - データのバックアップを検討
/// - ユーザーに通知（必要に応じて）
/// - ロールバック手順を用意
