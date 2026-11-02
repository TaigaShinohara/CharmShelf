import 'crash_report_privacy.dart';

/// クラッシュレポートのデータモデル
///
/// エラー発生時の詳細情報を保持します。
class CrashReport {
  CrashReport({
    required this.id,
    required this.timestamp,
    required this.errorType,
    required this.errorMessage,
    this.stackTrace,
    this.deviceInfo,
    this.appInfo,
    this.memoryInfo,
    this.currentRoute,
    this.additionalData,
  });

  /// 一意識別子
  final String id;

  /// 発生日時
  final DateTime timestamp;

  /// エラーの種類（例外クラス名）
  final String errorType;

  /// エラーメッセージ
  final String errorMessage;

  /// スタックトレース
  final String? stackTrace;

  /// デバイス情報
  final DeviceInfo? deviceInfo;

  /// アプリ情報
  final AppInfo? appInfo;

  /// メモリ情報
  final MemoryInfo? memoryInfo;

  /// 発生時の画面パス
  final String? currentRoute;

  /// 追加のコンテキストデータ
  final Map<String, dynamic>? additionalData;

  /// JSONからインスタンスを生成
  factory CrashReport.fromJson(Map<String, dynamic> json) {
    return CrashReport._fromSafeJson(CrashReportPrivacy.sanitizeJson(json));
  }

  factory CrashReport._fromSafeJson(Map<String, dynamic> json) {
    return CrashReport(
      id: json['id'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      errorType: json['errorType'] as String,
      errorMessage: json['errorMessage'] as String,
      stackTrace: json['stackTrace'] as String?,
      deviceInfo: json['deviceInfo'] != null
          ? DeviceInfo.fromJson(json['deviceInfo'] as Map<String, dynamic>)
          : null,
      appInfo: json['appInfo'] != null
          ? AppInfo.fromJson(json['appInfo'] as Map<String, dynamic>)
          : null,
      memoryInfo: json['memoryInfo'] != null
          ? MemoryInfo.fromJson(json['memoryInfo'] as Map<String, dynamic>)
          : null,
      currentRoute: json['currentRoute'] as String?,
      additionalData: json['additionalData'] as Map<String, dynamic>?,
    );
  }

  /// JSONに変換
  Map<String, dynamic> toJson() {
    return CrashReportPrivacy.sanitizeJson({
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'errorType': errorType,
      'errorMessage': errorMessage,
      'stackTrace': stackTrace,
      'deviceInfo': deviceInfo?.toJson(),
      'appInfo': appInfo?.toJson(),
      'memoryInfo': memoryInfo?.toJson(),
      'currentRoute': currentRoute,
      'additionalData': additionalData,
    });
  }

  CrashReport sanitized() => CrashReport._fromSafeJson(toJson());

  /// 概要テキストを生成
  String get summary {
    final safe = sanitized();
    final buffer = StringBuffer();
    buffer.writeln('[${safe.errorType}] ${safe.errorMessage}');
    buffer.writeln('Time: ${safe.timestamp.toIso8601String()}');
    return buffer.toString();
  }

  /// 詳細テキストを生成
  String toDetailString() {
    return sanitized()._safeDetailString();
  }

  String _safeDetailString() {
    final buffer = StringBuffer();
    buffer.writeln(
      '═══════════════════════════════════════════════════════════',
    );
    buffer.writeln('CRASH REPORT');
    buffer.writeln(
      '═══════════════════════════════════════════════════════════',
    );
    buffer.writeln('ID: $id');
    buffer.writeln('Time: ${timestamp.toIso8601String()}');
    buffer.writeln('');
    buffer.writeln(
      '── Error ──────────────────────────────────────────────────',
    );
    buffer.writeln('Type: $errorType');
    buffer.writeln('Message: $errorMessage');
    if (currentRoute != null) {
      buffer.writeln('Route: $currentRoute');
    }
    if (stackTrace != null) {
      buffer.writeln('');
      buffer.writeln(
        '── Stack Trace ────────────────────────────────────────────',
      );
      buffer.writeln(stackTrace);
    }
    if (deviceInfo != null) {
      buffer.writeln('');
      buffer.writeln(
        '── Device Info ────────────────────────────────────────────',
      );
      buffer.writeln(deviceInfo!.toString());
    }
    if (appInfo != null) {
      buffer.writeln('');
      buffer.writeln(
        '── App Info ───────────────────────────────────────────────',
      );
      buffer.writeln(appInfo!.toString());
    }
    if (memoryInfo != null) {
      buffer.writeln('');
      buffer.writeln(
        '── Memory Info ────────────────────────────────────────────',
      );
      buffer.writeln(memoryInfo!.toString());
    }
    if (additionalData != null && additionalData!.isNotEmpty) {
      buffer.writeln('');
      buffer.writeln(
        '── Additional Data ────────────────────────────────────────',
      );
      additionalData!.forEach((key, value) {
        buffer.writeln('$key: $value');
      });
    }
    buffer.writeln(
      '═══════════════════════════════════════════════════════════',
    );
    return buffer.toString();
  }
}

/// デバイス情報
class DeviceInfo {
  DeviceInfo({
    required this.platform,
    this.osVersion,
    this.model,
    this.manufacturer,
    this.isPhysicalDevice,
  });

  final String platform;
  final String? osVersion;
  final String? model;
  final String? manufacturer;
  final bool? isPhysicalDevice;

  factory DeviceInfo.fromJson(Map<String, dynamic> json) {
    return DeviceInfo(
      platform: json['platform'] as String,
      osVersion: json['osVersion'] as String?,
      model: json['model'] as String?,
      manufacturer: json['manufacturer'] as String?,
      isPhysicalDevice: json['isPhysicalDevice'] as bool?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'platform': platform,
      'osVersion': osVersion,
      'model': model,
      'manufacturer': manufacturer,
      'isPhysicalDevice': isPhysicalDevice,
    };
  }

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.writeln('Platform: $platform');
    if (osVersion != null) buffer.writeln('OS Version: $osVersion');
    if (model != null) buffer.writeln('Model: $model');
    if (manufacturer != null) buffer.writeln('Manufacturer: $manufacturer');
    if (isPhysicalDevice != null) {
      buffer.writeln('Physical Device: $isPhysicalDevice');
    }
    return buffer.toString().trim();
  }
}

/// アプリ情報
class AppInfo {
  AppInfo({
    required this.appName,
    required this.packageName,
    required this.version,
    required this.buildNumber,
  });

  final String appName;
  final String packageName;
  final String version;
  final String buildNumber;

  factory AppInfo.fromJson(Map<String, dynamic> json) {
    return AppInfo(
      appName: json['appName'] as String,
      packageName: json['packageName'] as String,
      version: json['version'] as String,
      buildNumber: json['buildNumber'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'appName': appName,
      'packageName': packageName,
      'version': version,
      'buildNumber': buildNumber,
    };
  }

  @override
  String toString() {
    return '''App: $appName
Package: $packageName
Version: $version
Build: $buildNumber''';
  }
}

/// メモリ情報
class MemoryInfo {
  MemoryInfo({this.usedHeapSize, this.totalHeapSize, this.externalUsage});

  /// 使用中のヒープサイズ（バイト）
  final int? usedHeapSize;

  /// 総ヒープサイズ（バイト）
  final int? totalHeapSize;

  /// 外部メモリ使用量（バイト）
  final int? externalUsage;

  factory MemoryInfo.fromJson(Map<String, dynamic> json) {
    return MemoryInfo(
      usedHeapSize: json['usedHeapSize'] as int?,
      totalHeapSize: json['totalHeapSize'] as int?,
      externalUsage: json['externalUsage'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'usedHeapSize': usedHeapSize,
      'totalHeapSize': totalHeapSize,
      'externalUsage': externalUsage,
    };
  }

  String _formatBytes(int? bytes) {
    if (bytes == null) return 'N/A';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  String toString() {
    return '''Used Heap: ${_formatBytes(usedHeapSize)}
Total Heap: ${_formatBytes(totalHeapSize)}
External: ${_formatBytes(externalUsage)}''';
  }
}
