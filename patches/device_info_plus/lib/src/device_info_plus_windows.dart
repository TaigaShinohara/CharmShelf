/// The Windows implementation of `device_info_plus`.
library;

import 'dart:ffi';
import 'dart:developer' as developer;
import 'dart:typed_data';

import 'package:device_info_plus_platform_interface/device_info_plus_platform_interface.dart';
import 'package:ffi/ffi.dart';
import 'package:meta/meta.dart';
import 'package:win32/win32.dart';
import 'package:win32_registry/win32_registry.dart';

import 'model/windows_device_info.dart';
import 'windows_registry_info.dart';

/// The Windows implementation of [DeviceInfoPlatform].
class DeviceInfoPlusWindowsPlugin extends DeviceInfoPlatform {
  /// Register this dart class as the platform implementation for windows
  static void registerWith() {
    DeviceInfoPlatform.instance = DeviceInfoPlusWindowsPlugin();
  }

  WindowsDeviceInfo? _cache;

  /// Returns a [WindowsDeviceInfo] with information about the device.
  @override
  Future<BaseDeviceInfo> deviceInfo() {
    return Future.value(_cache ??= getInfo());
  }

  @visibleForTesting
  WindowsDeviceInfo getInfo() {
    final systemInfo = calloc<SYSTEM_INFO>();
    final osVersionInfo =
        calloc<OSVERSIONINFOEX>()
          ..ref.dwOSVersionInfoSize = sizeOf<OSVERSIONINFOEX>();

    try {
      final registry = WindowsRegistryInfo.read(_openRegistryKey);
      var productName = registry.productName;

      GetSystemInfo(systemInfo);

      // win32 6 exposes the NT API and its actual NTSTATUS return value.
      final status = RtlGetVersion(osVersionInfo.cast<OSVERSIONINFO>());
      if (status.isError) throw WindowsException(status.toHRESULT());

      // Handle [productName] for Windows 11 separately (as per Raymond Chen's comment).
      // https://stackoverflow.com/questions/69460588/how-can-i-find-the-windows-product-name-in-windows-11
      if (osVersionInfo.ref.dwBuildNumber >= 22000) {
        productName = productName.replaceAll('10', '11');
      }
      final data = WindowsDeviceInfo(
        numberOfCores: systemInfo.ref.dwNumberOfProcessors,
        computerName: getComputerName(),
        systemMemoryInMegabytes: getSystemMemoryInMegabytes(),
        userName: getUserName(),
        majorVersion: osVersionInfo.ref.dwMajorVersion,
        minorVersion: osVersionInfo.ref.dwMinorVersion,
        buildNumber: osVersionInfo.ref.dwBuildNumber,
        platformId: osVersionInfo.ref.dwPlatformId,
        csdVersion: osVersionInfo.ref.szCSDVersion,
        servicePackMajor: osVersionInfo.ref.wServicePackMajor,
        servicePackMinor: osVersionInfo.ref.wServicePackMinor,
        suitMask: osVersionInfo.ref.wSuiteMask,
        productType: osVersionInfo.ref.wProductType,
        // The SDK reserves this byte for future use; win32 6 makes it private.
        reserved: 0,
        buildLab: registry.buildLab,
        buildLabEx: registry.buildLabEx,
        digitalProductId: registry.digitalProductId,
        displayVersion: registry.displayVersion,
        editionId: registry.editionId,
        installDate: registry.installDate,
        productId: registry.productId,
        productName: productName,
        registeredOwner: registry.registeredOwner,
        releaseId: registry.releaseId,
        deviceId: registry.deviceId,
      );
      return data;
    } finally {
      free(systemInfo);
      free(osVersionInfo);
    }
  }

  @visibleForTesting
  int getSystemMemoryInMegabytes() {
    final memoryInKilobytes = calloc<Uint64>();
    try {
      final result = GetPhysicallyInstalledSystemMemory(memoryInKilobytes);
      if (result.value) {
        return memoryInKilobytes.value ~/ 1024;
      } else {
        developer.log('Failed to get system memory', error: result.error);
        return 0;
      }
    } finally {
      free(memoryInKilobytes);
    }
  }

  @visibleForTesting
  String getComputerName() {
    // We call this a first time to get the length of the string in characters,
    // so we can allocate sufficient memory.
    final nSize = calloc<Uint32>();
    try {
      final sizeResult = GetComputerNameEx(
        ComputerNameDnsFullyQualified,
        null,
        nSize,
      );
      if (nSize.value == 0) {
        developer.log('Failed to get computer name', error: sizeResult.error);
        return '';
      }
      // wsalloc now returns a PWSTR rather than a raw UTF-16 pointer.
      final lpBuffer = wsalloc(nSize.value);
      try {
        final result = GetComputerNameEx(
          ComputerNameDnsFullyQualified,
          lpBuffer,
          nSize,
        );
        if (result.value) return lpBuffer.toDartString();
        developer.log('Failed to get computer name', error: result.error);
        return '';
      } finally {
        free(lpBuffer);
      }
    } finally {
      free(nSize);
    }
  }

  @visibleForTesting
  String getUserName() {
    const maxLength = 256; // defined as UNLEN in Lmcons.h
    final lpBuffer = wsalloc(maxLength + 1); // allow for terminating null
    final pcbBuffer = calloc<Uint32>()..value = maxLength + 1;
    try {
      final result = GetUserName(lpBuffer, pcbBuffer);
      if (result.value) {
        return lpBuffer.toDartString();
      } else {
        developer.log('Failed to get user name', error: result.error);
        return '';
      }
    } finally {
      free(pcbBuffer);
      free(lpBuffer);
    }
  }

  static WindowsRegistryKeyReader _openRegistryKey(String path) =>
      _NativeRegistryKeyReader(
        LOCAL_MACHINE.open(
          path,
          config: const RegistryOpenConfig(access: RegistryAccess.read),
        ),
      );
}

final class _NativeRegistryKeyReader implements WindowsRegistryKeyReader {
  _NativeRegistryKeyReader(this.key);

  final RegistryKey key;

  @override
  String? getString(String name) => key.getString(name);

  @override
  int? getInt(String name) => key.getInt(name);

  @override
  Uint8List? getBinary(String name) => key.getBinary(name);

  @override
  void close() => key.close();
}
