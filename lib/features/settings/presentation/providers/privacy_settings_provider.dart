import 'dart:io';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:private_shelf/core/logger/app_logger.dart';
import 'package:private_shelf/core/logger/log_tag.dart';
import '../../domain/models/privacy_settings.dart';
import '../../data/repositories/privacy_repository.dart';
import '../../data/services/privacy_native_service.dart';
import '../../../security/presentation/providers/security_repository_provider.dart';

part 'privacy_settings_provider.g.dart';

@Riverpod(keepAlive: true)
PrivacyRepository privacyRepository(Ref ref) {
  // SharedPreferencesのインスタンス取得が必要
  // main.dartでoverrideするか、Providerで提供する必要がある
  throw UnimplementedError('Should be overridden in main.dart');
}

@Riverpod(keepAlive: true)
Future<bool> hasPasscode(Ref ref) async {
  final result = await ref.watch(securityRepositoryProvider).hasPasscode();
  return result.when(
    success: (exists) => exists,
    failure: (error) => throw error,
  );
}

@Riverpod(keepAlive: true)
class PrivacySettingsNotifier extends _$PrivacySettingsNotifier {
  late final PrivacyRepository _repository;
  final PrivacyNativeService _nativeService = const PrivacyNativeService();

  @override
  Future<PrivacySettings> build() async {
    _repository = ref.watch(privacyRepositoryProvider);
    final result = await _repository.loadSettings();
    final settings = await result.when(
      success: (settings) async => settings,
      failure: (error) async {
        AppLogger.e(LogTag.auth, 'プライバシー設定が破損しているため安全な既定値を使用', error);
        final passcodeResult = await ref
            .read(securityRepositoryProvider)
            .hasPasscode();
        if (passcodeResult.isFailure) throw passcodeResult.errorOrNull!;
        return PrivacySettings(
          isAppLockEnabled: passcodeResult.dataOrNull ?? false,
        );
      },
    );
    try {
      final applied = await _nativeService.applyMultitaskSecure(
        settings.hideContentInMultitasking,
      );
      if ((Platform.isAndroid || Platform.isIOS) &&
          settings.hideContentInMultitasking &&
          !applied) {
        throw StateError('Failed to enable multitasking privacy protection');
      }
    } catch (e) {
      if ((Platform.isAndroid || Platform.isIOS) &&
          settings.hideContentInMultitasking) {
        AppLogger.e(LogTag.ui, '起動時のプライバシー保護適用に失敗', e);
        rethrow;
      }
      AppLogger.d(LogTag.ui, '初期化時のプライバシー設定適用スキップまたは失敗: $e');
    }
    return settings;
  }

  Future<bool> updateSettings(PrivacySettings newSettings) async {
    final previousSettings = state.value;
    state = AsyncValue.data(newSettings);
    final result = await _repository.saveSettings(newSettings);
    return result.when(
      success: (_) => true,
      failure: (_) {
        if (previousSettings != null) {
          state = AsyncValue.data(previousSettings);
        }
        return false;
      },
    );
  }

  Future<bool> toggleBiometric(bool value) async {
    final current = state.value;
    if (current == null) return false;
    return updateSettings(current.copyWith(isBiometricEnabled: value));
  }

  Future<bool> enableAppLock() async {
    final current = state.value;
    if (current == null) return false;
    final hasPasscode = await ref
        .read(securityRepositoryProvider)
        .hasPasscode();
    if (hasPasscode.isFailure || hasPasscode.dataOrNull != true) {
      AppLogger.e(LogTag.auth, 'パスコードが確認できないためアプリロックを有効化できません');
      return false;
    }
    ref.invalidate(hasPasscodeProvider);
    return updateSettings(current.copyWith(isAppLockEnabled: true));
  }

  Future<bool> disableAppLock() async {
    final current = state.value;
    if (current == null) return false;

    // 1. まず設定を永続化する。失敗時はパスコードを残して保護を維持する。
    final updated = await updateSettings(
      current.copyWith(isAppLockEnabled: false, isBiometricEnabled: false),
    );

    if (!updated) {
      AppLogger.e(LogTag.auth, '設定の保存に失敗しました');
      return false;
    }

    // 2. 設定保存後にパスコードを削除する。削除失敗時は設定を安全側へ戻す。
    final securityRepo = ref.read(securityRepositoryProvider);
    final deleteResult = await securityRepo.deletePasscode();
    if (deleteResult.isFailure) {
      final rolledBack = await updateSettings(current);
      AppLogger.e(
        LogTag.auth,
        rolledBack
            ? 'パスコード削除に失敗したためアプリロック設定を復元しました'
            : 'パスコード削除と設定復元に失敗しました。パスコード保護は維持されます',
        deleteResult.errorOrNull,
      );
      return false;
    }

    ref.invalidate(hasPasscodeProvider);
    return true;
  }

  Future<bool> toggleAppLock(bool value) async {
    if (value) {
      return enableAppLock();
    } else {
      return disableAppLock();
    }
  }

  Future<void> setAutoLockTimeout(AutoLockTimeout timeout) async {
    final current = state.value;
    if (current == null) return;
    await updateSettings(current.copyWith(autoLockTimeout: timeout));
  }

  Future<bool> toggleHideContentInMultitasking(bool value) async {
    final current = state.value;
    if (current == null) return false;
    if (current.hideContentInMultitasking == value) return true;
    final applied = await _nativeService.applyMultitaskSecure(value);
    if (!applied) return false;
    return updateSettings(current.copyWith(hideContentInMultitasking: value));
  }

  Future<void> toggleSecretThumbnailMode(bool value) async {
    final current = state.value;
    if (current == null) return;
    await updateSettings(current.copyWith(useSecretThumbnailMode: value));
  }
}
