import 'package:path/path.dart' as p;

import 'storage_sandbox.dart';

/// Exact temporary paths owned by one journaled import; never a glob to clean.
class ImportCopyArtifacts {
  ImportCopyArtifacts({
    required this.operationId,
    required this.destinationPath,
  }) {
    if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$').hasMatch(operationId) ||
        p.normalize(destinationPath) != destinationPath ||
        p.split(destinationPath).length < 2) {
      throw const FormatException('Invalid import copy identity');
    }
    StorageSandbox.resolveRelative(
      '/managed',
      destinationPath,
      allowedTopLevelDirectories: const {'library'},
    );
  }

  final String operationId;
  final String destinationPath;

  String get partialPath => '$destinationPath.$operationId.tagshelf-part';
  String get reservationPath => '$destinationPath.tagshelf-reservation';

  Map<String, dynamic> toMap() => {
    'version': 1,
    'partialPath': partialPath,
    'reservationPath': reservationPath,
  };

  Map<String, dynamic> get ownership => {
    'version': 1,
    'operationId': operationId,
    'destinationPath': destinationPath,
    'partialPath': partialPath,
  };

  bool ownsReservation(Object? value) =>
      value is Map &&
      value['version'] == 1 &&
      value['operationId'] == operationId &&
      value['destinationPath'] == destinationPath &&
      value['partialPath'] == partialPath;

  static ImportCopyArtifacts fromMap(
    Object? value, {
    required String operationId,
    required String destinationPath,
  }) {
    final expected = ImportCopyArtifacts(
      operationId: operationId,
      destinationPath: destinationPath,
    );
    if (value is! Map ||
        value['version'] != 1 ||
        value['partialPath'] != expected.partialPath ||
        value['reservationPath'] != expected.reservationPath) {
      throw const FormatException(
        'Import copy paths do not match their operation',
      );
    }
    return expected;
  }
}
