import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../config/app_config.dart';

/// Only fixed diagnostic categories and validated version numbers may cross a
/// crash-report storage or presentation boundary. Arbitrary strings cannot be
/// reliably inspected for personal information, including in debug builds.
abstract final class CrashReportPrivacy {
  static const version = 1;
  static const omittedMessage = 'Diagnostic details omitted for privacy.';

  static const _errorTypes = {
    'Error',
    'Exception',
    'StateError',
    'ArgumentError',
    'RangeError',
    'TypeError',
    'NoSuchMethodError',
    'FormatException',
    'FileSystemException',
    'PathAccessException',
    'PathExistsException',
    'PathNotFoundException',
    'PlatformException',
    'MissingPluginException',
    'TimeoutException',
    'SocketException',
    'UnsupportedError',
    'AssertionError',
    'LateInitializationError',
    'OutOfMemoryError',
    'StackOverflowError',
  };
  static const _sources = {
    'flutter',
    'platform',
    'zone',
    'manual',
    'async',
    'widget',
  };
  static final _safeId = RegExp(r'^crash_[a-f0-9]{24}$');
  static final _version = RegExp(r'^\d{1,6}(?:\.\d{1,6}){0,3}$');
  static final _build = RegExp(r'^\d{1,12}$');

  static String errorType(Object error) =>
      safeErrorType(error.runtimeType.toString());

  static String safeErrorType(Object? value) =>
      value is String && _errorTypes.contains(value) ? value : 'Error';

  static Map<String, dynamic> sanitizeJson(Map<String, dynamic> json) {
    final rawId = json['id'];
    final rawTimestamp = json['timestamp'];
    if (rawId is! String ||
        rawTimestamp is! String ||
        rawTimestamp.length > 40) {
      throw const FormatException('Invalid crash report identity');
    }
    final timestamp = DateTime.tryParse(rawTimestamp);
    if (timestamp == null) {
      throw const FormatException('Invalid crash report timestamp');
    }

    // Legacy identifiers can contain arbitrary caller data. A stable opaque ID
    // preserves deduplication without retaining those original strings.
    final id = _safeId.hasMatch(rawId)
        ? rawId
        : 'crash_${sha256.convert(utf8.encode(rawId)).toString().substring(0, 24)}';
    final additional = json['additionalData'];
    final source = additional is Map ? additional['errorSource'] : null;

    return {
      'privacyVersion': version,
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'errorType': safeErrorType(json['errorType']),
      'errorMessage': omittedMessage,
      'stackTrace': null,
      'deviceInfo': null,
      'appInfo': _safeAppInfo(json['appInfo']),
      'memoryInfo': null,
      'currentRoute': null,
      'additionalData': source is String && _sources.contains(source)
          ? {'errorSource': source}
          : null,
    };
  }

  static Map<String, dynamic>? _safeAppInfo(Object? value) {
    if (value is! Map) return null;
    final rawVersion = value['version'];
    final rawBuild = value['buildNumber'];
    final version = rawVersion is String && _version.hasMatch(rawVersion)
        ? rawVersion
        : null;
    final build = rawBuild is String && _build.hasMatch(rawBuild)
        ? rawBuild
        : null;
    if (version == null && build == null) return null;
    return {
      'appName': AppConfig.appName,
      'packageName': AppConfig.packageName,
      'version': version ?? 'unknown',
      'buildNumber': build ?? 'unknown',
    };
  }
}
