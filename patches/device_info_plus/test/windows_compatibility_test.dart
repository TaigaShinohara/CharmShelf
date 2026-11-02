import 'dart:io';
import 'dart:typed_data';

import 'package:device_info_plus/src/device_info_plus_windows.dart';
import 'package:device_info_plus/src/windows_registry_info.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reads typed registry metadata and closes both opened keys', () {
    final productId = Uint8List.fromList([1, 2, 255]);
    final current = _RegistryKey({
      'BuildLab': '22000.fixture',
      'BuildLabEx': '22000.fixture.amd64',
      'DigitalProductId': productId,
      'DisplayVersion': 'fixture-version',
      'EditionID': 'fixture-edition',
      'InstallDate': 1720000000,
      'ProductID': 'synthetic-product-id',
      'ProductName': 'Windows 10 Fixture',
      'RegisteredOwner': 'synthetic-owner',
      'ReleaseId': 'fixture-release',
    });
    final sqm = _RegistryKey({'MachineId': 'synthetic-device-id'});
    final paths = <String>[];
    final info = WindowsRegistryInfo.read((path) {
      paths.add(path);
      return path == WindowsRegistryInfo.currentVersionPath ? current : sqm;
    });

    expect(paths, [
      r'SOFTWARE\Microsoft\Windows NT\CurrentVersion',
      r'SOFTWARE\Microsoft\SQMClient',
    ]);
    expect(info.buildLab, '22000.fixture');
    expect(info.buildLabEx, '22000.fixture.amd64');
    expect(info.digitalProductId, productId);
    expect(info.displayVersion, 'fixture-version');
    expect(info.editionId, 'fixture-edition');
    expect(info.installDate.millisecondsSinceEpoch, 1720000000000);
    expect(info.productId, 'synthetic-product-id');
    expect(info.productName, 'Windows 10 Fixture');
    expect(info.registeredOwner, 'synthetic-owner');
    expect(info.releaseId, 'fixture-release');
    expect(info.deviceId, 'synthetic-device-id');
    expect(current.closeCount, 1);
    expect(sqm.closeCount, 1);
  });

  test('missing or wrong-type optional values preserve empty defaults', () {
    final current = _RegistryKey({
      'BuildLab': 123,
      'DigitalProductId': 'not-binary',
      'InstallDate': 'not-an-integer',
    });
    final sqm = _RegistryKey({});
    final info = WindowsRegistryInfo.read(
      (path) => path == WindowsRegistryInfo.currentVersionPath ? current : sqm,
    );

    expect(info.buildLab, '');
    expect(info.digitalProductId, isEmpty);
    expect(info.installDate.millisecondsSinceEpoch, 0);
    expect(info.productName, '');
    expect(info.deviceId, '');
    expect(current.closeCount, 1);
    expect(sqm.closeCount, 1);
  });

  test('read failure closes both keys and propagates the error', () {
    final current = _RegistryKey({}, failRead: true);
    final sqm = _RegistryKey({});
    expect(
      () => WindowsRegistryInfo.read(
        (path) =>
            path == WindowsRegistryInfo.currentVersionPath ? current : sqm,
      ),
      throwsStateError,
    );
    expect(current.closeCount, 1);
    expect(sqm.closeCount, 1);
  });

  test('failure to open SQMClient still closes CurrentVersion', () {
    final current = _RegistryKey({});
    expect(
      () => WindowsRegistryInfo.read((path) {
        if (path == WindowsRegistryInfo.currentVersionPath) return current;
        throw StateError('synthetic open failure');
      }),
      throwsStateError,
    );
    expect(current.closeCount, 1);
  });

  test('close failure still releases the outer registry key', () {
    final current = _RegistryKey({});
    final sqm = _RegistryKey({}, failClose: true);
    expect(
      () => WindowsRegistryInfo.read(
        (path) =>
            path == WindowsRegistryInfo.currentVersionPath ? current : sqm,
      ),
      throwsStateError,
    );
    expect(current.closeCount, 1);
    expect(sqm.closeCount, 1);
  });

  test(
    'reads native Windows device information and reuses the cache',
    () async {
      final plugin = DeviceInfoPlusWindowsPlugin();
      final first = await plugin.deviceInfo();
      final second = await plugin.deviceInfo();
      expect(identical(first, second), isTrue);
      expect(first.data['numberOfCores'], greaterThan(0));
      expect(first.data['systemMemoryInMegabytes'], greaterThan(0));
      expect(first.data['majorVersion'], greaterThan(0));
      expect(first.data['buildNumber'], greaterThan(0));
      expect(first.data['computerName'], isNotEmpty);
      expect(first.data['userName'], isNotEmpty);
    },
    skip: !Platform.isWindows,
  );
}

final class _RegistryKey implements WindowsRegistryKeyReader {
  _RegistryKey(this.values, {this.failRead = false, this.failClose = false});

  final Map<String, Object?> values;
  final bool failRead;
  final bool failClose;
  int closeCount = 0;

  Object? _read(String name) {
    if (closeCount != 0 || failRead) throw StateError('synthetic read failure');
    return values[name];
  }

  @override
  String? getString(String name) {
    final value = _read(name);
    return value is String ? value : null;
  }

  @override
  int? getInt(String name) {
    final value = _read(name);
    return value is int ? value : null;
  }

  @override
  Uint8List? getBinary(String name) {
    final value = _read(name);
    return value is Uint8List ? value : null;
  }

  @override
  void close() {
    closeCount++;
    if (failClose) throw StateError('synthetic close failure');
  }
}
