import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:integration_test/integration_test_driver.dart';

const _stages = ['seed-old', 'read-write-new', 'verify-new'];
final _hashPattern = RegExp(r'^[a-f0-9]{64}$');

/// Run three cold starts with the exact same APK and --keep-app-running.
/// Every invocation must provide its expected stage, package, source/native
/// hashes, APK path and an isolated output directory using TAGSHELF_NATIVE_QA_*.
Future<void> main() async {
  final expectedStage = _required('EXPECTED_STAGE');
  final package = _required('PACKAGE');
  final sourceHash = _requiredHash('SOURCE_HASH');
  final baselineHash = _requiredHash('BASELINE_SHA256');
  final candidateHash = _requiredHash('CANDIDATE_SHA256');
  final apk = File(_required('APK'));
  final output = Directory(_required('OUTPUT'));
  if (!_stages.contains(expectedStage) ||
      !RegExp(
        r'^com\.tsmusic\.privateshelf\.opensource\.performanceqa[0-9]{1,8}$',
      ).hasMatch(package) ||
      baselineHash == candidateHash ||
      !await apk.exists()) {
    throw StateError('Invalid isolated native QA configuration');
  }
  final apkHash = (await apk.openRead().transform(sha256).first).toString();
  await _verifyApkNativeEntries(apk, baselineHash, candidateHash);
  final sequenceFile = File('${output.path}/sequence.json');
  final sequence = await sequenceFile.exists()
      ? jsonDecode(await sequenceFile.readAsString()) as Map<String, dynamic>
      : null;
  final previousPids = <int>[];
  final completedStages = <String>[];
  if (sequence != null) {
    if (sequence['schema'] != 1 ||
        sequence['packageName'] != package ||
        sequence['sourceHash'] != sourceHash ||
        sequence['apkSha256'] != apkHash ||
        sequence['baselineSha256'] != baselineHash ||
        sequence['candidateSha256'] != candidateHash) {
      throw StateError('Native QA evidence belongs to a different run');
    }
    previousPids.addAll((sequence['pids'] as List).cast<int>());
    completedStages.addAll(
      (sequence['completedStages'] as List).cast<String>(),
    );
  }
  if (completedStages.length >= _stages.length ||
      !_sameList(
        completedStages,
        _stages.take(completedStages.length).toList(),
      ) ||
      previousPids.length != completedStages.length ||
      previousPids.toSet().length != previousPids.length ||
      expectedStage != _stages[completedStages.length]) {
    throw StateError('Native QA stage is repeated, skipped or out of order');
  }
  final evidence = File('${output.path}/$expectedStage.json');
  if (await evidence.exists()) {
    throw StateError('Refusing to overwrite existing native QA stage evidence');
  }
  await output.create(recursive: true);
  await integrationDriver(
    timeout: const Duration(minutes: 3),
    responseDataCallback: (data) async {
      final report = data?['nativeDbCompatibility'];
      if (report is! Map<String, dynamic>) {
        throw StateError('Native QA result is missing');
      }
      final appPid = report['pid'];
      final baselineStage = expectedStage == 'seed-old';
      final expectedNext = switch (expectedStage) {
        'seed-old' => 'read-write-new',
        'read-write-new' => 'verify-new',
        _ => 'completed',
      };
      final appPreviousPids = report['previousPids'];
      if (report['schema'] != 1 ||
          report['completed'] != true ||
          report['stage'] != expectedStage ||
          report['nextStage'] != expectedNext ||
          report['packageName'] != package ||
          report['sourceHash'] != sourceHash ||
          report['baselineSha256'] != baselineHash ||
          report['candidateSha256'] != candidateHash ||
          report['library'] !=
              (baselineStage ? 'libisar_baseline.so' : 'libisar.so') ||
          report['librarySha256'] !=
              (baselineStage ? baselineHash : candidateHash) ||
          report['pageSize'] != 16384 ||
          report['abi'] != 'arm64-v8a' ||
          report['buildMode'] != 'profile' ||
          report['isarVersion'] != '3.1.0+1' ||
          appPid is! int ||
          appPid <= 0 ||
          previousPids.contains(appPid) ||
          appPreviousPids is! List ||
          !_sameList(appPreviousPids, previousPids) ||
          report['pids'] is! List ||
          !_sameList(report['pids'] as List, [...previousPids, appPid])) {
        throw StateError(
          'Native QA result does not match the expected cold stage',
        );
      }
      for (final key in [
        'databaseSha256',
        'baselineSnapshotSha256',
        'fixtureFileSha256',
      ]) {
        if (report[key] is! String ||
            !_hashPattern.hasMatch(report[key] as String)) {
          throw StateError('Native QA file evidence is incomplete');
        }
      }
      if (baselineStage) {
        if (report['beforeDatabaseSha256'] != null) {
          throw StateError('Baseline native QA did not start from fresh data');
        }
      } else if (report['beforeDatabaseSha256'] !=
              sequence!['databaseSha256'] ||
          report['baselineSnapshotSha256'] !=
              sequence['baselineSnapshotSha256'] ||
          report['fixtureFileSha256'] != sequence['fixtureFileSha256']) {
        throw StateError('Native QA did not reopen the previously verified DB');
      }
      if (expectedStage == 'read-write-new' &&
          report['databaseSha256'] == report['beforeDatabaseSha256']) {
        throw StateError('Candidate native QA did not persist its updates');
      }
      final counts = report['recordCounts'];
      if (counts is! Map ||
          counts['mediaItems'] != (baselineStage ? 1 : 2) ||
          [
            'collections',
            'tags',
            'facets',
            'storageRefs',
            'viewingHistory',
            'referenceMigrations',
          ].any((key) => counts[key] != 1)) {
        throw StateError('Native QA did not verify every application schema');
      }
      await _writeEvidence(evidence, {
        'allTestsPassed': true,
        'apkSha256': apkHash,
        ...report,
      });
      await _writeEvidence(sequenceFile, {
        'schema': 1,
        'packageName': package,
        'sourceHash': sourceHash,
        'apkSha256': apkHash,
        'baselineSha256': baselineHash,
        'candidateSha256': candidateHash,
        'completedStages': [...completedStages, expectedStage],
        'pids': [...previousPids, appPid],
        'databaseSha256': report['databaseSha256'],
        'baselineSnapshotSha256': report['baselineSnapshotSha256'],
        'fixtureFileSha256': report['fixtureFileSha256'],
      });
      // ignore: avoid_print
      print('Verified native database QA stage: $expectedStage');
    },
  );
}

String _required(String suffix) {
  final value = Platform.environment['TAGSHELF_NATIVE_QA_$suffix'];
  if (value == null || value.trim().isEmpty) {
    throw StateError('A native QA $suffix value is required');
  }
  return value;
}

String _requiredHash(String suffix) {
  final value = _required(suffix);
  if (!_hashPattern.hasMatch(value)) {
    throw StateError('A lowercase SHA-256 native QA $suffix value is required');
  }
  return value;
}

bool _sameList(List<dynamic> actual, List<dynamic> expected) =>
    actual.length == expected.length &&
    List.generate(
      actual.length,
      (index) => actual[index] == expected[index],
    ).every((matches) => matches);

Future<void> _writeEvidence(File destination, Map<String, dynamic> data) async {
  final temporary = File('${destination.path}.$pid.tmp');
  await temporary.writeAsString(
    const JsonEncoder.withIndent('  ').convert(data),
    flush: true,
  );
  await temporary.rename(destination.path);
}

Future<void> _verifyApkNativeEntries(
  File apk,
  String baselineHash,
  String candidateHash,
) async {
  // Python's standard ZIP reader avoids introducing a host-only app dependency.
  // Only the two explicitly named native entries are hashed; no values from the
  // baseline binary or application data are printed or retained.
  const script = '''
import hashlib,json,sys,zipfile
with zipfile.ZipFile(sys.argv[1]) as archive:
    names=archive.namelist()
    entries={
        'baseline':'lib/arm64-v8a/libisar_baseline.so',
        'candidate':'lib/arm64-v8a/libisar.so',
    }
    if any(names.count(name)!=1 for name in entries.values()):
        raise ValueError('Native QA entries are missing or duplicated')
    print(json.dumps({key:hashlib.sha256(archive.read(name)).hexdigest()
                      for key,name in entries.items()}))
''';
  final result = await Process.run('python3', [
    '-c',
    script,
    apk.absolute.path,
  ]);
  if (result.exitCode != 0) {
    throw StateError('Native QA APK entries could not be verified');
  }
  final hashes = jsonDecode(result.stdout as String);
  if (hashes is! Map ||
      hashes['baseline'] != baselineHash ||
      hashes['candidate'] != candidateHash) {
    throw StateError('Native QA APK contains unexpected native libraries');
  }
}
