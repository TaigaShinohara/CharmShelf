import 'dart:async';

import 'package:meta/meta.dart';
import 'package:wakelock_plus_platform_interface/wakelock_plus_platform_interface.dart';
import 'package:win32/win32.dart';

/// The Windows implementation of the [WakelockPlusPlatformInterface].
///
/// This class implements the `wakelock_plus` plugin functionality for Windows
/// using the `SetThreadExecutionState` win32 API
/// (see https://docs.microsoft.com/en-us/windows/win32/api/winbase/nf-winbase-setthreadexecutionstate).
class WakelockPlusWindowsPlugin extends WakelockPlusPlatformInterface {
  WakelockPlusWindowsPlugin({
    @visibleForTesting
    EXECUTION_STATE Function(EXECUTION_STATE)? setThreadExecutionState,
  }) : _setThreadExecutionState =
           setThreadExecutionState ?? SetThreadExecutionState;

  final EXECUTION_STATE Function(EXECUTION_STATE) _setThreadExecutionState;

  /// Registers this class as the default instance of [WakelockPlatformInterface].
  static void registerWith() {
    WakelockPlusPlatformInterface.instance = WakelockPlusWindowsPlugin();
  }

  var _enabled = false;

  @override
  Future<void> toggle({required bool enable}) async {
    final EXECUTION_STATE response;
    if (enable) {
      response = _setThreadExecutionState(ES_CONTINUOUS | ES_DISPLAY_REQUIRED);
    } else {
      response = _setThreadExecutionState(ES_CONTINUOUS);
    }

    // SetThreadExecutionState returns 0 if the operation failed.
    if (response != const EXECUTION_STATE(0)) {
      _enabled = enable;
    }
  }

  @override
  Future<bool> get enabled async => _enabled;

  @override
  bool get isMock => false;
}
