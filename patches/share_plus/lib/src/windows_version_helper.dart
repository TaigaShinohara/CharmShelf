import 'dart:io';
import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:meta/meta.dart';
import 'package:win32/win32.dart';

class VersionHelper {
  static VersionHelper instance = VersionHelper._();

  /// Whether the current OS is Windows 10 Redstone 5 or later.
  /// This is used to determine whether the modern Share UI i.e. `DataTransferManager` is available or not.
  ///
  /// References: https://en.wikipedia.org/wiki/Windows_10_version_history
  ///             https://docs.microsoft.com/en-us/windows/win32/api/winnt/ns-winnt-osversioninfoexa
  ///
  bool isWindows10RS5OrGreater = false;

  static const int kWindows10RS5BuildNumber = 17763;

  VersionHelper._() {
    if (Platform.isWindows) {
      isWindows10RS5OrGreater = readWindowsVersionSupportsShareUI();
    }
  }

  @visibleForTesting
  static bool supportsModernShare({
    required int majorVersion,
    required int buildNumber,
  }) =>
      majorVersion >= 10 && buildNumber >= kWindows10RS5BuildNumber;

  /// Reads the actual NT version using win32 6's typed NTSTATUS API.
  /// Failed reads keep the legacy fallback rather than assuming Share UI exists.
  @visibleForTesting
  static bool readWindowsVersionSupportsShareUI() => using((arena) {
        final pointer = arena<OSVERSIONINFO>()
          ..ref.dwOSVersionInfoSize = sizeOf<OSVERSIONINFO>();
        final status = RtlGetVersion(pointer);
        if (status.isError) return false;
        return supportsModernShare(
          majorVersion: pointer.ref.dwMajorVersion,
          buildNumber: pointer.ref.dwBuildNumber,
        );
      });
}
