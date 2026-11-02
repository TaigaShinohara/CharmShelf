import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../gen_l10n/app_localizations.dart';
import '../../shared/widgets/widgets.dart';
import '../error/app_error.dart';
import '../error/result.dart';
import '../logger/app_logger.dart';
import '../logger/log_tag.dart';

class VersionCheckService {
  static const _assetPath = 'assets/version_policy.json';

  Future<Result<VersionPolicy, AppError>> loadPolicy() async {
    try {
      final text = await rootBundle.loadString(_assetPath);
      final dynamic raw = jsonDecode(text);
      if (raw is! Map<String, dynamic>) {
        return Result.failure(
          AppError.validation('version_policy.jsonの形式が不正です'),
        );
      }
      return Result.success(VersionPolicy.fromJson(raw));
    } catch (e, st) {
      AppLogger.e(LogTag.app, 'loadPolicy failed', e, st);
      return Result.failure(
        AppError.unknown('バージョンポリシーの読み込みに失敗しました', original: e, stackTrace: st),
      );
    }
  }

  Future<Result<bool, AppError>> shouldForceUpdate() async {
    try {
      final policyResult = await loadPolicy();
      if (policyResult.isFailure) {
        return Result.failure(policyResult.errorOrNull!);
      }

      final policy = policyResult.dataOrNull!;
      final info = await PackageInfo.fromPlatform();
      final current = info.version;
      return Result.success(_compareSemver(current, policy.minVersion) < 0);
    } catch (e, st) {
      AppLogger.e(LogTag.app, 'shouldForceUpdate failed', e, st);
      return Result.failure(
        AppError.unknown('バージョン判定に失敗しました', original: e, stackTrace: st),
      );
    }
  }

  Future<void> showForceUpdateDialogIfNeeded(BuildContext context) async {
    try {
      final policyResult = await loadPolicy();
      if (policyResult.isFailure) return;
      final policy = policyResult.dataOrNull!;

      final info = await PackageInfo.fromPlatform();
      final current = info.version;
      final mustUpdate = _compareSemver(current, policy.minVersion) < 0;
      if (!mustUpdate) return;

      final url = policy.storeUrlForPlatform();
      if (url == null || url.isEmpty) {
        // URLが無い場合はダイアログだけ出して閉じられないと困るため、何もしない
        return;
      }

      if (!context.mounted) return;
      await _showDialog(context, minVersion: policy.minVersion, storeUrl: url);
    } catch (e, st) {
      AppLogger.e(LogTag.app, 'showForceUpdateDialogIfNeeded failed', e, st);
    }
  }

  Future<void> _showDialog(
    BuildContext context, {
    required String minVersion,
    required String storeUrl,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    // 強制アップデート: ダイアログは閉じられない（barrierDismissible=false、戻るボタンなし）
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return PopScope(
          canPop: false,
          child: AlertDialog(
            title: AppText(l10n.versionUpdateRequired),
            content: AppText(l10n.versionUpdateMessage(minVersion)),
            actions: [
              FilledButton(
                onPressed: () async {
                  final uri = Uri.tryParse(storeUrl);
                  if (uri == null) return;
                  final ok = await canLaunchUrl(uri);
                  if (!ok) return;
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                },
                child: AppText(l10n.versionStoreButton),
              ),
            ],
          ),
        );
      },
    );
  }

  /// returns negative if a < b, 0 if equal, positive if a > b
  int _compareSemver(String a, String b) {
    final aa = _parseSemver(a);
    final bb = _parseSemver(b);
    for (var i = 0; i < 3; i++) {
      final diff = aa[i] - bb[i];
      if (diff != 0) return diff;
    }
    return 0;
  }

  List<int> _parseSemver(String v) {
    final parts = v.split('.');
    int part(int idx) {
      if (idx >= parts.length) return 0;
      final raw = parts[idx];
      final cleaned = raw.replaceAll(RegExp(r'[^0-9]'), '');
      return int.tryParse(cleaned) ?? 0;
    }

    return [part(0), part(1), part(2)];
  }
}

class VersionPolicy {
  VersionPolicy({
    required this.minVersion,
    required this.iosStoreUrl,
    required this.androidStoreUrl,
  });

  final String minVersion;
  final String iosStoreUrl;
  final String androidStoreUrl;

  factory VersionPolicy.fromJson(Map<String, dynamic> json) {
    return VersionPolicy(
      minVersion: (json['minVersion'] is String)
          ? (json['minVersion'] as String)
          : '0.0.0',
      iosStoreUrl: (json['iosStoreUrl'] is String)
          ? (json['iosStoreUrl'] as String)
          : '',
      androidStoreUrl: (json['androidStoreUrl'] is String)
          ? (json['androidStoreUrl'] as String)
          : '',
    );
  }

  String? storeUrlForPlatform() {
    // Webではストアへ誘導しない（必要なら別途 webStoreUrl を追加する）
    if (kIsWeb) return null;

    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return iosStoreUrl;
      case TargetPlatform.android:
        return androidStoreUrl;
      default:
        return null;
    }
  }
}
