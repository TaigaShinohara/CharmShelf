import 'package:flutter/foundation.dart';

/// アプリの実行環境
enum Environment {
  /// 開発環境
  development,

  /// ステージング環境
  staging,

  /// 本番環境
  production,
}

/// 環境設定を管理するクラス
///
/// 使用方法:
/// 1. `--dart-define=ENV=development` でビルド
/// 2. `AppEnvironment.current` で現在の環境を取得
///
/// ビルドコマンド例:
/// ```bash
/// # 開発
/// flutter run --dart-define=ENV=development
///
/// # ステージング
/// flutter run --dart-define=ENV=staging
///
/// # 本番
/// flutter run --dart-define=ENV=production
/// flutter build apk --dart-define=ENV=production
/// ```
class AppEnvironment {
  AppEnvironment._();

  /// 現在の環境（--dart-define で指定）
  static const String _envString = String.fromEnvironment(
    'ENV',
    defaultValue: 'development',
  );

  /// 現在の環境を取得
  static Environment get current {
    switch (_envString.toLowerCase()) {
      case 'production':
      case 'prod':
        return Environment.production;
      case 'staging':
      case 'stg':
        return Environment.staging;
      case 'development':
      case 'dev':
      default:
        return Environment.development;
    }
  }

  /// 開発環境かどうか
  static bool get isDevelopment => current == Environment.development;

  /// ステージング環境かどうか
  static bool get isStaging => current == Environment.staging;

  /// 本番環境かどうか
  static bool get isProduction => current == Environment.production;

  /// デバッグモードかどうか（Flutterの kDebugMode）
  static bool get isDebugMode => kDebugMode;

  /// リリースモードかどうか（Flutterの kReleaseMode）
  static bool get isReleaseMode => kReleaseMode;

  /// 環境名（表示用）
  static String get name {
    switch (current) {
      case Environment.development:
        return '開発';
      case Environment.staging:
        return 'ステージング';
      case Environment.production:
        return '本番';
    }
  }

  /// 環境に応じた色（デバッグ表示用）
  static int get colorValue {
    switch (current) {
      case Environment.development:
        return 0xFF4CAF50; // Green
      case Environment.staging:
        return 0xFFFF9800; // Orange
      case Environment.production:
        return 0xFFF44336; // Red
    }
  }
}

/// 環境別の設定値
///
/// 環境ごとに異なる設定値を管理します。
/// 必要に応じて項目を追加してください。
///
/// 使用例:
/// ```dart
/// final apiUrl = EnvironmentConfig.apiBaseUrl;
/// final logLevel = EnvironmentConfig.logLevel;
/// ```
class EnvironmentConfig {
  EnvironmentConfig._();

  /// APIのベースURL
  ///
  /// --dart-define=API_BASE_URL で上書き可能
  static String get apiBaseUrl {
    const override = String.fromEnvironment('API_BASE_URL');
    if (override.isNotEmpty) return override;

    switch (AppEnvironment.current) {
      case Environment.development:
        return 'http://localhost:8080/api';
      case Environment.staging:
        return 'https://staging-api.example.com/api';
      case Environment.production:
        return 'https://api.example.com/api';
    }
  }

  /// ログレベル
  static String get logLevel {
    switch (AppEnvironment.current) {
      case Environment.development:
        return 'verbose';
      case Environment.staging:
        return 'debug';
      case Environment.production:
        return 'error';
    }
  }

  /// 詳細ログを有効にするか
  static bool get enableDetailedLogs {
    return AppEnvironment.current != Environment.production;
  }

  /// クラッシュレポートを有効にするか
  static bool get enableCrashReporting {
    return AppEnvironment.current == Environment.production ||
        AppEnvironment.current == Environment.staging;
  }

  /// 分析を有効にするか
  static bool get enableAnalytics {
    return AppEnvironment.current == Environment.production;
  }

  /// DIPを有効にするか（開発者パネル）
  static bool get enableDip {
    return AppEnvironment.current != Environment.production;
  }

  /// SSL証明書の検証をスキップするか（開発用）
  static bool get skipSslVerification {
    return AppEnvironment.current == Environment.development;
  }

  /// キャッシュの有効期間（秒）
  static int get cacheExpirationSeconds {
    switch (AppEnvironment.current) {
      case Environment.development:
        return 60; // 1分
      case Environment.staging:
        return 300; // 5分
      case Environment.production:
        return 3600; // 1時間
    }
  }

  /// タイムアウト時間（秒）
  static int get requestTimeoutSeconds {
    switch (AppEnvironment.current) {
      case Environment.development:
        return 60;
      case Environment.staging:
        return 30;
      case Environment.production:
        return 15;
    }
  }

  /// 全設定を出力（デバッグ用）
  static Map<String, dynamic> toMap() {
    return {
      'environment': AppEnvironment.current.name,
      'apiBaseUrl': apiBaseUrl,
      'logLevel': logLevel,
      'enableDetailedLogs': enableDetailedLogs,
      'enableCrashReporting': enableCrashReporting,
      'enableAnalytics': enableAnalytics,
      'enableDip': enableDip,
      'cacheExpirationSeconds': cacheExpirationSeconds,
      'requestTimeoutSeconds': requestTimeoutSeconds,
    };
  }
}
