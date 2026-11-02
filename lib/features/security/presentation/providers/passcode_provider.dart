import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:private_shelf/core/error/app_error.dart';
import 'package:private_shelf/core/error/result.dart';
import 'package:private_shelf/core/services/secure_storage_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'security_repository_provider.dart';

part 'passcode_provider.g.dart';

enum PasscodeMode {
  setup, // 新規設定
  confirm, // 確認入力
  unlock, // 解除
  verifyOld, // 変更前の確認
}

enum PasscodeError {
  mismatch,
  incorrect,
  verifyFailed,
  storageFailed,
  oldIncorrect,
  biometricsFailed,
}

@immutable
class PasscodeState {
  const PasscodeState({
    required this.mode,
    this.passcode = '',
    this.confirmPasscode = '',
    this.errorType,
    this.isProcessing = false,
    this.isSuccess = false,
    this.isTransitioning = false,
    this.failedAttempts = 0,
    this.lockoutUntil,
    this.lockoutRemainingSeconds,
    this.hasAutoBiometricAttempted = false,
    this.isSecurityStateReady = false,
    this.hasVerifiedExistingPasscode = false,
  });

  static const Object _noValue = Object();

  final PasscodeMode mode;
  final String passcode;
  final String confirmPasscode;
  final PasscodeError? errorType;
  final bool isProcessing;
  final bool isSuccess;
  final bool isTransitioning;
  final int failedAttempts;
  final DateTime? lockoutUntil;
  final int? lockoutRemainingSeconds;
  final bool hasAutoBiometricAttempted;
  final bool isSecurityStateReady;
  final bool hasVerifiedExistingPasscode;

  PasscodeState copyWith({
    PasscodeMode? mode,
    String? passcode,
    String? confirmPasscode,
    Object? errorType = _noValue,
    bool? isProcessing,
    bool? isSuccess,
    bool? isTransitioning,
    int? failedAttempts,
    Object? lockoutUntil = _noValue,
    Object? lockoutRemainingSeconds = _noValue,
    bool? hasAutoBiometricAttempted,
    bool? isSecurityStateReady,
    bool? hasVerifiedExistingPasscode,
  }) {
    return PasscodeState(
      mode: mode ?? this.mode,
      passcode: passcode ?? this.passcode,
      confirmPasscode: confirmPasscode ?? this.confirmPasscode,
      errorType: errorType == _noValue
          ? this.errorType
          : errorType as PasscodeError?,
      isProcessing: isProcessing ?? this.isProcessing,
      isSuccess: isSuccess ?? this.isSuccess,
      isTransitioning: isTransitioning ?? this.isTransitioning,
      failedAttempts: failedAttempts ?? this.failedAttempts,
      lockoutUntil: lockoutUntil == _noValue
          ? this.lockoutUntil
          : lockoutUntil as DateTime?,
      lockoutRemainingSeconds: lockoutRemainingSeconds == _noValue
          ? this.lockoutRemainingSeconds
          : lockoutRemainingSeconds as int?,
      hasAutoBiometricAttempted:
          hasAutoBiometricAttempted ?? this.hasAutoBiometricAttempted,
      isSecurityStateReady: isSecurityStateReady ?? this.isSecurityStateReady,
      hasVerifiedExistingPasscode:
          hasVerifiedExistingPasscode ?? this.hasVerifiedExistingPasscode,
    );
  }
}

@riverpod
class PasscodeNotifier extends _$PasscodeNotifier {
  static const maxAttempts = 5;
  static const _lockoutDuration = Duration(seconds: 30);
  Timer? _lockoutTimer;
  Future<Result<void, AppError>> _persistenceQueue = Future.value(
    Result.success(null),
  );
  bool _disposed = false;

  @override
  PasscodeState build(PasscodeMode mode) {
    _disposed = false;
    ref.onDispose(() {
      _disposed = true;
      _lockoutTimer?.cancel();
    });
    Future<void>.microtask(_restoreLockout);
    return PasscodeState(mode: mode);
  }

  static const _passcodeLength = 4;

  void addDigit(int digit) async {
    if (!state.isSecurityStateReady ||
        state.isProcessing ||
        state.isTransitioning ||
        _isLockedOut()) {
      return;
    }
    if (state.passcode.length >= _passcodeLength &&
        state.mode != PasscodeMode.confirm) {
      return;
    }
    if (state.confirmPasscode.length >= _passcodeLength &&
        state.mode == PasscodeMode.confirm) {
      return;
    }

    if (state.mode == PasscodeMode.confirm) {
      final newConfirm = state.confirmPasscode + digit.toString();
      state = state.copyWith(confirmPasscode: newConfirm, errorType: null);
      if (newConfirm.length == _passcodeLength) {
        _verifyConfirmation();
      }
    } else {
      final newPasscode = state.passcode + digit.toString();
      state = state.copyWith(passcode: newPasscode, errorType: null);
      if (newPasscode.length == _passcodeLength) {
        if (state.mode == PasscodeMode.setup) {
          state = state.copyWith(isTransitioning: true);
          await Future.delayed(const Duration(milliseconds: 500));
          if (state.mode != PasscodeMode.setup || !state.isTransitioning) {
            return;
          }
          state = state.copyWith(
            mode: PasscodeMode.confirm,
            isTransitioning: false,
          );
        } else if (state.mode == PasscodeMode.unlock) {
          _verifyUnlock();
        } else if (state.mode == PasscodeMode.verifyOld) {
          _verifyOld();
        }
      }
    }
  }

  void deleteDigit() {
    if (!state.isSecurityStateReady ||
        state.isProcessing ||
        state.isTransitioning ||
        _isLockedOut()) {
      return;
    }
    if (state.mode == PasscodeMode.confirm) {
      if (state.confirmPasscode.isEmpty) return;
      state = state.copyWith(
        confirmPasscode: state.confirmPasscode.substring(
          0,
          state.confirmPasscode.length - 1,
        ),
      );
    } else {
      if (state.passcode.isEmpty) return;
      state = state.copyWith(
        passcode: state.passcode.substring(0, state.passcode.length - 1),
      );
    }
  }

  Future<void> _verifyConfirmation() async {
    final repository = ref.read(securityRepositoryProvider);
    if (state.passcode == state.confirmPasscode) {
      state = state.copyWith(isProcessing: true);
      final hasPasscodeResult = await repository.hasPasscode();
      if (_disposed) return;
      if (hasPasscodeResult.isFailure) {
        state = state.copyWith(
          mode: PasscodeMode.setup,
          passcode: '',
          confirmPasscode: '',
          errorType: PasscodeError.storageFailed,
          isProcessing: false,
        );
        return;
      }
      final hasExistingPasscode = hasPasscodeResult.dataOrNull ?? false;
      if (hasExistingPasscode && !state.hasVerifiedExistingPasscode) {
        // ルーティングや将来の呼び出し元に不備があっても、既存PINは
        // 同一フロー内で旧PINを検証するまで上書きしない。
        state = state.copyWith(
          mode: PasscodeMode.setup,
          passcode: '',
          confirmPasscode: '',
          errorType: PasscodeError.verifyFailed,
          isProcessing: false,
        );
        return;
      }
      final result = await repository.setPasscode(state.passcode);
      if (_disposed) return;
      result.when(
        success: (_) {
          unawaited(_clearPersistedLockout());
          state = state.copyWith(
            isSuccess: true,
            isProcessing: false,
            errorType: null,
            failedAttempts: 0,
            lockoutUntil: null,
            lockoutRemainingSeconds: null,
            hasVerifiedExistingPasscode: false,
          );
        },
        failure: (error) {
          state = state.copyWith(
            mode: PasscodeMode.setup,
            passcode: '',
            confirmPasscode: '',
            errorType: PasscodeError.storageFailed,
            isProcessing: false,
          );
        },
      );
    } else {
      state = state.copyWith(
        mode: PasscodeMode.setup,
        passcode: '',
        confirmPasscode: '',
        errorType: PasscodeError.mismatch,
      );
    }
  }

  Future<void> _verifyUnlock() async {
    final repository = ref.read(securityRepositoryProvider);
    state = state.copyWith(isProcessing: true);
    final result = await repository.verifyPasscode(state.passcode);
    if (_disposed) return;
    if (result.isSuccess && result.dataOrNull == true) {
      unawaited(_clearPersistedLockout());
      state = state.copyWith(
        isSuccess: true,
        isProcessing: false,
        errorType: null,
        failedAttempts: 0,
        lockoutUntil: null,
        lockoutRemainingSeconds: null,
      );
      return;
    }
    await _handleFailedAttempt(
      errorType: result.isFailure
          ? PasscodeError.verifyFailed
          : PasscodeError.incorrect,
      isProcessing: false,
    );
  }

  Future<void> _verifyOld() async {
    final repository = ref.read(securityRepositoryProvider);
    final result = await repository.verifyPasscode(state.passcode);
    if (_disposed) return;
    if (result.isSuccess && result.dataOrNull == true) {
      unawaited(_clearPersistedLockout());
      state = state.copyWith(
        mode: PasscodeMode.setup,
        passcode: '',
        errorType: null,
        failedAttempts: 0,
        lockoutUntil: null,
        lockoutRemainingSeconds: null,
        hasVerifiedExistingPasscode: true,
      );
      return;
    }
    await _handleFailedAttempt(
      errorType: result.isFailure
          ? PasscodeError.verifyFailed
          : PasscodeError.oldIncorrect,
      isProcessing: false,
    );
  }

  void markAutoBiometricAttempted() {
    if (!state.hasAutoBiometricAttempted) {
      state = state.copyWith(hasAutoBiometricAttempted: true);
    }
  }

  /// 生体認証を実行する
  Future<void> authenticateWithBiometrics({
    required String localizedReason,
  }) async {
    if (!state.isSecurityStateReady ||
        state.isProcessing ||
        state.isSuccess ||
        _isLockedOut()) {
      return;
    }

    state = state.copyWith(
      isProcessing: true,
      errorType: null,
      hasAutoBiometricAttempted: true,
    );

    final repository = ref.read(securityRepositoryProvider);
    final result = await repository.authenticateWithBiometrics(
      localizedReason: localizedReason,
    );
    if (_disposed) return;

    result.when(
      success: (authenticated) {
        if (authenticated) {
          unawaited(_clearPersistedLockout());
          state = state.copyWith(
            isSuccess: true,
            isProcessing: false,
            errorType: null,
            failedAttempts: 0,
            lockoutUntil: null,
            lockoutRemainingSeconds: null,
          );
        } else {
          state = state.copyWith(isProcessing: false);
        }
      },
      failure: (error) {
        state = state.copyWith(
          isProcessing: false,
          errorType: PasscodeError.biometricsFailed,
        );
      },
    );
  }

  Future<void> _handleFailedAttempt({
    required PasscodeError errorType,
    required bool isProcessing,
  }) async {
    final updatedAttempts = state.failedAttempts + 1;
    if (updatedAttempts >= maxAttempts) {
      final level = ((updatedAttempts - maxAttempts) ~/ maxAttempts).clamp(
        0,
        4,
      );
      final started = await _startLockout(
        _lockoutDuration * (1 << level),
        updatedAttempts,
      );
      if (_disposed || !started) return;
      state = state.copyWith(
        passcode: '',
        confirmPasscode: '',
        errorType: null,
        isProcessing: isProcessing,
        failedAttempts: updatedAttempts,
      );
      return;
    }
    final persisted = await _persistLockout(updatedAttempts, null);
    if (_disposed) return;
    if (!persisted) {
      _failClosedForStorageError();
      return;
    }
    state = state.copyWith(
      passcode: '',
      confirmPasscode: '',
      errorType: errorType,
      isProcessing: isProcessing,
      failedAttempts: updatedAttempts,
    );
  }

  Future<bool> _startLockout(Duration duration, int failedAttempts) async {
    _lockoutTimer?.cancel();
    final until = DateTime.now().add(duration);
    var remaining = duration.inSeconds;
    state = state.copyWith(
      lockoutUntil: until,
      lockoutRemainingSeconds: duration.inSeconds,
    );
    final persisted = await _persistLockout(failedAttempts, until);
    if (_disposed) return false;
    if (!persisted) {
      _failClosedForStorageError();
      return false;
    }
    _lockoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_disposed) {
        timer.cancel();
        return;
      }
      remaining -= 1;
      if (remaining <= 0) {
        timer.cancel();
        unawaited(_persistLockout(failedAttempts, null));
        state = state.copyWith(
          lockoutUntil: null,
          lockoutRemainingSeconds: null,
          failedAttempts: failedAttempts,
        );
        return;
      }
      state = state.copyWith(lockoutRemainingSeconds: remaining);
    });
    return true;
  }

  bool _isLockedOut() {
    final remaining = state.lockoutRemainingSeconds ?? 0;
    return remaining > 0;
  }

  Future<void> _restoreLockout() async {
    final storage = ref.read(secureStorageServiceProvider);
    final result = await storage.read(key: SecureStorageKeys.pinLockoutState);
    if (_disposed) return;
    if (result.isFailure) {
      _failClosedForStorageError();
      return;
    }
    final value = result.dataOrNull;
    try {
      if (value == null || value.isEmpty) {
        state = state.copyWith(isSecurityStateReady: true);
        return;
      }
      final decoded = jsonDecode(value) as Map<String, dynamic>;
      if (decoded['version'] != 1 || decoded['failedAttempts'] is! int) {
        _failClosedForStorageError();
        return;
      }
      final attempts = (decoded['failedAttempts'] as int?) ?? 0;
      if (attempts < 0) {
        _failClosedForStorageError();
        return;
      }
      final untilValue = decoded['lockoutUntil'] as String?;
      if (untilValue != null && DateTime.tryParse(untilValue) == null) {
        _failClosedForStorageError();
        return;
      }
      if (untilValue != null) {
        state = state.copyWith(failedAttempts: attempts);
        // 永続化された壁時計の期限は端末時刻の変更で短縮できるため、
        // 再起動後は試行回数に対応する全時間を単調カウンタで再開する。
        final started = await _startLockout(
          _lockoutDurationForAttempts(attempts),
          attempts,
        );
        if (!started) return;
        state = state.copyWith(isSecurityStateReady: true);
      } else {
        state = state.copyWith(
          failedAttempts: attempts,
          isSecurityStateReady: true,
        );
      }
    } on Object {
      _failClosedForStorageError();
    }
  }

  Duration _lockoutDurationForAttempts(int attempts) {
    final level = ((attempts - maxAttempts) ~/ maxAttempts).clamp(0, 4);
    return _lockoutDuration * (1 << level);
  }

  Future<bool> _persistLockout(int attempts, DateTime? until) async {
    final storage = ref.read(secureStorageServiceProvider);
    _persistenceQueue = _persistenceQueue.then(
      (_) => storage.write(
        key: SecureStorageKeys.pinLockoutState,
        value: jsonEncode({
          'version': 1,
          'failedAttempts': attempts,
          'lockoutUntil': until?.toUtc().toIso8601String(),
        }),
      ),
    );
    final result = await _persistenceQueue;
    return result.isSuccess;
  }

  Future<void> _clearPersistedLockout() async {
    final storage = ref.read(secureStorageServiceProvider);
    _persistenceQueue = _persistenceQueue.then(
      (_) => storage.delete(key: SecureStorageKeys.pinLockoutState),
    );
    await _persistenceQueue;
  }

  void _failClosedForStorageError() {
    _lockoutTimer?.cancel();
    state = state.copyWith(
      passcode: '',
      confirmPasscode: '',
      isProcessing: false,
      isSecurityStateReady: false,
      errorType: PasscodeError.storageFailed,
    );
  }
}
