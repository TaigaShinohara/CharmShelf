import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  // After devicectl copies Library/Application Support/release-qa from the QA app,
  // this mode validates those results without attaching to a VM service.
  final copiedArtifacts =
      Platform.environment['TAGSHELF_IOS_QA_COPIED_ARTIFACTS'];
  if (copiedArtifacts != null && copiedArtifacts.trim().isNotEmpty) {
    await _verifyCopiedArtifacts(Directory(copiedArtifacts));
    return;
  }
  final configured = Platform.environment['TAGSHELF_IOS_QA_OUTPUT'];
  final directory = Directory(
    configured == null || configured.trim().isEmpty
        ? 'build/ios-release-qa/screenshots'
        : configured,
  );
  await directory.create(recursive: true);
  await integrationDriver(
    onScreenshot: (name, bytes, [args]) async {
      if (!RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(name) || bytes.isEmpty) {
        return false;
      }
      await File(
        '${directory.path}/$name.png',
      ).writeAsBytes(bytes, flush: true);
      return true;
    },
    writeResponseOnFailure: true,
    responseDataCallback: (data) async {
      final report = <String, dynamic>{...?data};
      // PNGs are separate files; keep diagnostics small and readable.
      final screenshots = report.remove('screenshots') as List<dynamic>?;
      report['screenshotNames'] = screenshots
          ?.map(
            (dynamic shot) => (shot as Map<String, dynamic>)['screenshotName'],
          )
          .toList();
      await File('${directory.path}/diagnostics.json').writeAsString(
        const JsonEncoder.withIndent('  ').convert(report),
        flush: true,
      );
    },
  );
}

Future<void> _verifyCopiedArtifacts(Directory directory) async {
  final expectedSourceHash =
      Platform.environment['TAGSHELF_IOS_QA_EXPECTED_SOURCE_HASH'];
  if (expectedSourceHash == null ||
      !RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(expectedSourceHash)) {
    throw StateError('An expected QA source hash is required for offline QA');
  }
  final report =
      jsonDecode(
            await File('${directory.path}/diagnostics.json').readAsString(),
          )
          as Map<String, dynamic>;
  const allowedPackages = <String>{
    'org.charmshelf.opensource.releaseqa',
    'org.charmshelf.opensource.releaseqa2',
    'org.charmshelf.opensource.releaseqa3',
    'org.charmshelf.opensource.releaseqa4',
    'org.charmshelf.opensource.releaseqa5',
    'org.charmshelf.opensource.releaseqa6',
  };
  if (!allowedPackages.contains(report['packageName']) ||
      report['platform'] != 'ios' ||
      report['artifactDirectory'] != 'Library/Application Support/release-qa' ||
      report['sourceHash'] != expectedSourceHash) {
    throw StateError('Copied artifacts are not from an allowed iOS QA app');
  }
  if (report['completed'] != true || report['allTestsPassed'] != true) {
    throw StateError('Copied iOS QA test did not complete successfully');
  }
  final harnessErrors = report['harnessErrors'];
  if (harnessErrors != null &&
      (harnessErrors is! List || harnessErrors.isNotEmpty)) {
    throw StateError('Copied iOS QA harness reported errors');
  }
  final failures = report['failureDetails'];
  final itemCount = report['itemCount'];
  final duration = report['audioDurationMs'];
  final position = report['audioPositionMs'];
  final track = report['sampleTrackPath'];
  final buildNumber = report['buildNumber'];
  final started = DateTime.tryParse('${report['startedAtUtc']}');
  final completed = DateTime.tryParse('${report['completedAtUtc']}');
  if (failures is! List ||
      failures.isNotEmpty ||
      itemCount is! int ||
      itemCount != 1 ||
      report['initialItemCount'] != 0 ||
      report['audioFixtureImported'] != true ||
      duration is! int ||
      duration <= 60000 ||
      position is! int ||
      position <= 1000 ||
      position > duration ||
      track is! String ||
      !track.endsWith('suki_ga_totonou_tagshelf_pv.mp3') ||
      report['pauseVerified'] != true ||
      report['returnedToLibrary'] != true ||
      buildNumber is! String ||
      !RegExp(r'^\d+$').hasMatch(buildNumber) ||
      !const <String>{'profile', 'release'}.contains(report['buildMode']) ||
      started == null ||
      completed == null ||
      !started.isUtc ||
      !completed.isUtc ||
      completed.isBefore(started)) {
    throw StateError('Copied iOS QA diagnostics are incomplete or invalid');
  }
  final names = (report['screenshotNames'] as List<dynamic>).cast<String>();
  const expectedNames = <String>{
    'ios-sample-preview',
    'ios-library',
    'ios-home',
  };
  if (names.length != expectedNames.length ||
      !names.toSet().containsAll(expectedNames)) {
    throw StateError('Copied iOS QA screenshots are incomplete');
  }
  final files = (report['screenshotFiles'] as List<dynamic>)
      .cast<Map<String, dynamic>>();
  if (files.length != names.length ||
      files.map((file) => file['name']).toSet().length != names.length) {
    throw StateError('Copied QA screenshot manifest is incomplete');
  }
  const pngHeader = <int>[137, 80, 78, 71, 13, 10, 26, 10];
  const pngEnd = <int>[0, 0, 0, 0, 73, 69, 78, 68, 174, 66, 96, 130];
  for (final name in names) {
    if (!RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(name)) {
      throw StateError('Invalid copied QA screenshot name');
    }
    final manifest = files.singleWhere((file) => file['name'] == name);
    if (manifest['fileName'] != '$name.png') {
      throw StateError('Invalid copied QA screenshot filename');
    }
    final bytes = await File('${directory.path}/$name.png').readAsBytes();
    if (bytes.length < 45 ||
        !List.generate(
          pngHeader.length,
          (i) => bytes[i] == pngHeader[i],
        ).every((matches) => matches) ||
        ByteData.sublistView(bytes).getUint32(8) != 13 ||
        ascii.decode(bytes.sublist(12, 16)) != 'IHDR' ||
        ByteData.sublistView(bytes).getUint32(16) < 1 ||
        ByteData.sublistView(bytes).getUint32(20) < 1 ||
        !List.generate(
          pngEnd.length,
          (i) => bytes[bytes.length - pngEnd.length + i] == pngEnd[i],
        ).every((matches) => matches) ||
        manifest['byteLength'] != bytes.length ||
        manifest['sha256'] != sha256.convert(bytes).toString()) {
      throw StateError('Copied QA screenshot is not a PNG: $name');
    }
  }
  // This path only reads the copied artifacts. Success is the process exit
  // status; the diagnostic report and PNGs remain the collected evidence.
}
