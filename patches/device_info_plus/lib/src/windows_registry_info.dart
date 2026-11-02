import 'dart:typed_data';

/// The read-only registry operations used for Windows device metadata.
///
/// Kept independent of native handles so decoding and handle cleanup can be
/// tested without reading a developer's actual registry.
abstract interface class WindowsRegistryKeyReader {
  String? getString(String name);
  int? getInt(String name);
  Uint8List? getBinary(String name);
  void close();
}

/// Values from the Windows CurrentVersion and SQMClient registry keys.
final class WindowsRegistryInfo {
  const WindowsRegistryInfo({
    required this.buildLab,
    required this.buildLabEx,
    required this.digitalProductId,
    required this.displayVersion,
    required this.editionId,
    required this.installDate,
    required this.productId,
    required this.productName,
    required this.registeredOwner,
    required this.releaseId,
    required this.deviceId,
  });

  factory WindowsRegistryInfo.read(
    WindowsRegistryKeyReader Function(String path) openKey,
  ) {
    final currentVersion = openKey(currentVersionPath);
    try {
      final sqmClient = openKey(sqmClientPath);
      try {
        return WindowsRegistryInfo(
          buildLab: currentVersion.getString('BuildLab') ?? '',
          buildLabEx: currentVersion.getString('BuildLabEx') ?? '',
          digitalProductId:
              currentVersion.getBinary('DigitalProductId') ?? Uint8List(0),
          displayVersion: currentVersion.getString('DisplayVersion') ?? '',
          editionId: currentVersion.getString('EditionID') ?? '',
          installDate: DateTime.fromMillisecondsSinceEpoch(
            1000 * (currentVersion.getInt('InstallDate') ?? 0),
          ),
          productId: currentVersion.getString('ProductID') ?? '',
          productName: currentVersion.getString('ProductName') ?? '',
          registeredOwner: currentVersion.getString('RegisteredOwner') ?? '',
          releaseId: currentVersion.getString('ReleaseId') ?? '',
          deviceId: sqmClient.getString('MachineId') ?? '',
        );
      } finally {
        sqmClient.close();
      }
    } finally {
      currentVersion.close();
    }
  }

  static const currentVersionPath =
      r'SOFTWARE\Microsoft\Windows NT\CurrentVersion';
  static const sqmClientPath = r'SOFTWARE\Microsoft\SQMClient';

  final String buildLab;
  final String buildLabEx;
  final Uint8List digitalProductId;
  final String displayVersion;
  final String editionId;
  final DateTime installDate;
  final String productId;
  final String productName;
  final String registeredOwner;
  final String releaseId;
  final String deviceId;
}
