// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:local_auth_platform_interface/local_auth_platform_interface.dart';

import 'src/messages.g.dart' as pigeon;
import 'types/auth_messages_ios.dart';
import 'types/auth_messages_macos.dart';

export 'package:local_auth_darwin/types/auth_messages_ios.dart';
export 'package:local_auth_platform_interface/types/auth_messages.dart';
export 'package:local_auth_platform_interface/types/auth_options.dart';
export 'package:local_auth_platform_interface/types/biometric_type.dart';

/// The implementation of [LocalAuthPlatform] for iOS and macOS.
class LocalAuthDarwin extends LocalAuthPlatform {
  /// Creates a new plugin implementation instance.
  LocalAuthDarwin({
    @visibleForTesting pigeon.LocalAuthApi? api,
    @visibleForTesting bool? overrideUseMacOSAuthMessages,
  }) : _api = api ?? pigeon.LocalAuthApi(),
       _useMacOSAuthMessages = overrideUseMacOSAuthMessages ?? Platform.isMacOS;

  /// Registers this class as the default instance of [LocalAuthPlatform].
  static void registerWith() {
    LocalAuthPlatform.instance = LocalAuthDarwin();
  }

  final pigeon.LocalAuthApi _api;
  final bool _useMacOSAuthMessages;

  @override
  Future<bool> authenticate({
    required String localizedReason,
    required Iterable<AuthMessages> authMessages,
    AuthenticationOptions options = const AuthenticationOptions(),
  }) async {
    assert(localizedReason.isNotEmpty);
    final pigeon.AuthResultDetails resultDetails = await _api.authenticate(
      pigeon.AuthOptions(
        biometricOnly: options.biometricOnly,
        sticky: options.stickyAuth,
      ),
      _useMacOSAuthMessages
          ? _pigeonStringsFromMacOSAuthMessages(localizedReason, authMessages)
          : _pigeonStringsFromiOSAuthMessages(localizedReason, authMessages),
    );
    LocalAuthExceptionCode code;
    switch (resultDetails.result) {
      case pigeon.AuthResult.success:
        return true;
      case pigeon.AuthResult.authenticationFailed:
        return false;
      case pigeon.AuthResult.appCancel:
        // If the plugin client intentionally canceled authentication, no need
        // to return a specific error.
        return false;
      case pigeon.AuthResult.uiUnavailable:
        code = LocalAuthExceptionCode.uiUnavailable;
      case pigeon.AuthResult.systemCancel:
        code = LocalAuthExceptionCode.systemCanceled;
      case pigeon.AuthResult.userCancel:
        code = LocalAuthExceptionCode.userCanceled;
      case pigeon.AuthResult.biometryDisconnected:
        code = LocalAuthExceptionCode.biometricHardwareTemporarilyUnavailable;
      case pigeon.AuthResult.biometryLockout:
        code = LocalAuthExceptionCode.biometricLockout;
      case pigeon.AuthResult.biometryNotAvailable:
      // Treated as no hardware since docs suggest that this means that there is
      // no known device; paired but not connected is biometryDisconnected.
      case pigeon.AuthResult.biometryNotPaired:
        code = LocalAuthExceptionCode.noBiometricHardware;
      case pigeon.AuthResult.biometryNotEnrolled:
        code = LocalAuthExceptionCode.noBiometricsEnrolled;
      case pigeon.AuthResult.invalidContext:
      case pigeon.AuthResult.invalidDimensions:
      case pigeon.AuthResult.notInteractive:
        code = LocalAuthExceptionCode.uiUnavailable;
      case pigeon.AuthResult.passcodeNotSet:
        code = LocalAuthExceptionCode.noCredentialsSet;
      case pigeon.AuthResult.userFallback:
        code = LocalAuthExceptionCode.userRequestedFallback;
      case pigeon.AuthResult.unknownError:
        code = LocalAuthExceptionCode.unknownError;
    }
    throw LocalAuthException(
      code: code,
      description: resultDetails.errorMessage,
      details: resultDetails.errorDetails,
    );
  }

  @override
  Future<bool> deviceSupportsBiometrics() async {
    return _api.deviceCanSupportBiometrics();
  }

  @override
  Future<List<BiometricType>> getEnrolledBiometrics() async {
    final List<pigeon.AuthBiometric> result = await _api
        .getEnrolledBiometrics();
    return result.map((pigeon.AuthBiometric value) {
      switch (value) {
        case pigeon.AuthBiometric.face:
          return BiometricType.face;
        case pigeon.AuthBiometric.fingerprint:
          return BiometricType.fingerprint;
      }
    }).toList();
  }

  @override
  Future<bool> isDeviceSupported() async => _api.isDeviceSupported();

  /// Always returns false as this method is not supported on iOS or macOS.
  @override
  Future<bool> stopAuthentication() async => false;

  pigeon.AuthStrings _pigeonStringsFromiOSAuthMessages(
    String localizedReason,
    Iterable<AuthMessages> messagesList,
  ) {
    IOSAuthMessages? messages;
    for (final entry in messagesList) {
      if (entry is IOSAuthMessages) {
        messages = entry;
        break;
      }
    }
    return pigeon.AuthStrings(
      reason: localizedReason,
      cancelButton: messages?.cancelButton ?? iOSCancelButton,
      localizedFallbackTitle: messages?.localizedFallbackTitle,
    );
  }

  pigeon.AuthStrings _pigeonStringsFromMacOSAuthMessages(
    String localizedReason,
    Iterable<AuthMessages> messagesList,
  ) {
    MacOSAuthMessages? messages;
    for (final entry in messagesList) {
      if (entry is MacOSAuthMessages) {
        messages = entry;
        break;
      }
    }
    return pigeon.AuthStrings(
      reason: localizedReason,
      cancelButton: messages?.cancelButton ?? macOSCancelButton,
      localizedFallbackTitle: messages?.localizedFallbackTitle,
    );
  }
}
