import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Launch the same QA APK three times using run_android_dependency_smoke.py.
// This tests the pre-JNI on-disk format, not an upgrade from an old app binary.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  var stage = 'guard';
  var packageName = '';
  const sourceHash = String.fromEnvironment(
    'TAGSHELF_DEPENDENCY_QA_SOURCE_HASH',
  );
  binding.allTestsPassed.future.then((passed) {
    // A fixed marker lets the host read synthetic results even in Release/R8.
    // No preference values, device files, or user information are logged.
    // ignore: avoid_print
    print(
      'TAGSHELF_DEPENDENCY_QA_RESULT ${jsonEncode({'schema': 1, 'sourceHash': sourceHash, 'packageName': packageName, 'stage': stage, 'pid': pid, 'allTestsPassed': passed})}',
    );
  });

  testWidgets('legacy preferences survive two cold process restarts', (
    tester,
  ) async {
    expect(Platform.isAndroid, isTrue);
    expect(RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(sourceHash), isTrue);
    packageName = (await PackageInfo.fromPlatform()).packageName;
    expect(
      RegExp(
        r'^com\.tsmusic\.privateshelf\.opensource\.performanceqa[0-9]{1,8}$',
      ).hasMatch(packageName),
      isTrue,
      reason: 'Only a numbered, isolated QA application may write fixtures',
    );
    final support = await getApplicationSupportDirectory();
    final appData = Directory(await support.parent.resolveSymbolicLinks());
    expect(appData.path.endsWith('/$packageName'), isTrue);
    final stateFile = File('${support.path}/dependency-preferences-qa.json');
    final preferencesFile = File(
      '${appData.path}/shared_prefs/FlutterSharedPreferences.xml',
    );
    final state = await stateFile.exists()
        ? (jsonDecode(await stateFile.readAsString()) as Map<String, dynamic>)
        : null;
    final previousPids = <int>[];
    if (state != null) {
      expect(state['schema'], 1);
      expect(state['sourceHash'], sourceHash);
      previousPids.addAll((state['pids'] as List).cast<int>());
      expect(previousPids, isNot(contains(pid)));
    }
    stage = state?['nextStage'] as String? ?? 'seed-legacy';
    String nextStage;
    switch (stage) {
      case 'seed-legacy':
        expect(await preferencesFile.exists(), isFalse);
        expect(await File('${preferencesFile.path}.bak').exists(), isFalse);
        await preferencesFile.parent.create(recursive: true);
        await preferencesFile.writeAsString(_legacyFixture, flush: true);
        // Native plugin registration can have cached an empty preferences map.
        // Do not call SharedPreferences until the host starts a new process.
        nextStage = 'read-write';
      case 'read-write':
        final preferences = await SharedPreferences.getInstance();
        expect(preferences.getBool('dependency_qa_bool'), isTrue);
        expect(preferences.getInt('dependency_qa_int'), 730025);
        expect(preferences.getDouble('dependency_qa_double'), 1.25);
        expect(
          preferences.getString('dependency_qa_legacy'),
          'legacy-synthetic',
        );
        expect(preferences.getStringList('dependency_qa_list'), [
          'legacy-one',
          'legacy-two',
        ]);
        expect(await preferences.setBool('dependency_qa_bool', false), isTrue);
        expect(await preferences.setInt('dependency_qa_int', 730026), isTrue);
        expect(
          await preferences.setDouble('dependency_qa_double', 2.5),
          isTrue,
        );
        expect(
          await preferences.setStringList('dependency_qa_list', [
            'jni-one',
            'jni-two',
          ]),
          isTrue,
        );
        expect(
          await preferences.setString('dependency_qa_new', 'jni-synthetic'),
          isTrue,
        );
        expect(await preferences.remove('dependency_qa_remove'), isTrue);
        await preferences.reload();
        _expectUpdated(preferences);
        nextStage = 'verify-restart';
      case 'verify-restart':
        final preferences = await SharedPreferences.getInstance();
        _expectUpdated(preferences);
        nextStage = 'completed';
      default:
        throw StateError('Refusing an unknown or completed QA stage: $stage');
    }
    expect(
      await preferencesFile.readAsString(),
      contains('<string name="native_untouched">native-synthetic</string>'),
      reason: 'Plugin writes must preserve a non-Flutter preference entry',
    );
    await stateFile.writeAsString(
      jsonEncode({
        'schema': 1,
        'sourceHash': sourceHash,
        'nextStage': nextStage,
        'pids': [...previousPids, pid],
      }),
      flush: true,
    );
  }, timeout: const Timeout(Duration(seconds: 60)));
}

void _expectUpdated(SharedPreferences preferences) {
  expect(preferences.getBool('dependency_qa_bool'), isFalse);
  expect(preferences.getInt('dependency_qa_int'), 730026);
  expect(preferences.getDouble('dependency_qa_double'), 2.5);
  expect(preferences.getString('dependency_qa_legacy'), 'legacy-synthetic');
  expect(preferences.getString('dependency_qa_new'), 'jni-synthetic');
  expect(preferences.getStringList('dependency_qa_list'), [
    'jni-one',
    'jni-two',
  ]);
  expect(preferences.containsKey('dependency_qa_remove'), isFalse);
}

// Format and prefixes are from shared_preferences_android 2.4.28's official
// LegacySharedPreferencesPlugin and lib/src/strings.dart. Only synthetic keys.
const _legacyFixture =
    '''<?xml version='1.0' encoding='utf-8' standalone='yes' ?>
<map>
    <boolean name="flutter.dependency_qa_bool" value="true" />
    <long name="flutter.dependency_qa_int" value="730025" />
    <string name="flutter.dependency_qa_double">VGhpcyBpcyB0aGUgcHJlZml4IGZvciBEb3VibGUu1.25</string>
    <string name="flutter.dependency_qa_legacy">legacy-synthetic</string>
    <string name="flutter.dependency_qa_list">VGhpcyBpcyB0aGUgcHJlZml4IGZvciBhIGxpc3Qu!["legacy-one","legacy-two"]</string>
    <string name="flutter.dependency_qa_remove">remove-synthetic</string>
    <string name="native_untouched">native-synthetic</string>
</map>
''';
