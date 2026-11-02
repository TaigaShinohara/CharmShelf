import 'dart:convert';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:private_shelf/features/library/data/repositories/import_source_repository.dart';
import 'package:private_shelf/features/library/domain/models/import_source.dart';

class _FailingPreferences extends Mock implements SharedPreferences {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  ImportSource source(String id, [String? tree]) => ImportSource(
    id: id,
    name: id,
    treeUri: Uri.parse('content://test/tree/${tree ?? id}'),
  );
  late SharedPreferences preferences;
  late ImportSourceRepository repo;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
    repo = ImportSourceRepository(preferences);
  });
  test(
    'failed platform persistence restores the optimistic preferences cache',
    () async {
      final failing = _FailingPreferences();
      String? cache;
      when(
        () => failing.getString(ImportSourceRepository.storageKey),
      ).thenAnswer((_) => cache);
      when(
        () => failing.setString(ImportSourceRepository.storageKey, any()),
      ).thenAnswer((call) async {
        cache = call.positionalArguments[1] as String;
        return false;
      });
      when(() => failing.remove(ImportSourceRepository.storageKey)).thenAnswer((
        _,
      ) async {
        cache = null;
        return false;
      });
      final store = ImportSourceRepository(failing);
      await expectLater(store.save(source('one')), throwsStateError);
      expect(store.read(), isEmpty);
      expect(cache, isNull);
    },
  );

  test(
    'concurrent registrations survive, duplicate grants keep identity',
    () async {
      await Future.wait([repo.save(source('one')), repo.save(source('two'))]);
      await repo.save(source('another', 'one'));
      expect(repo.read().map((s) => s.id).toSet(), {'one', 'two'});
      expect(ImportSourceRepository(preferences).read(), hasLength(2));
    },
  );
  test(
    'reconnect and remove record cleanup without deleting other registrations',
    () async {
      await repo.save(source('one'));
      await repo.save(source('two'));
      await repo.save(source('one', 'replacement'));
      expect(repo.pendingReleases(), [source('one').treeUri]);
      await repo.remove(source('one', 'replacement'));
      expect(repo.read().single.id, 'two');
      expect(
        repo.pendingReleases(),
        contains(source('one', 'replacement').treeUri),
      );
      await repo.released(source('one').treeUri);
      expect(repo.pendingReleases(), [source('one', 'replacement').treeUri]);
    },
  );
  test(
    'corrupt registry fails visibly and is not replaced by an empty list',
    () async {
      await preferences.setString(ImportSourceRepository.storageKey, '{broken');
      expect(repo.read, throwsFormatException);
      await expectLater(repo.save(source('one')), throwsFormatException);
      expect(
        preferences.getString(ImportSourceRepository.storageKey),
        '{broken',
      );
      await preferences.setString(
        ImportSourceRepository.storageKey,
        jsonEncode({'version': 99, 'sources': [], 'pending': []}),
      );
      expect(repo.read, throwsFormatException);
    },
  );
  test('grant ownership uses exact opaque tree IDs, not name prefixes', () {
    final grant = Uri.parse('content://test/tree/primary%3AFoo');
    expect(
      sharesImportGrant(
        grant,
        Uri.parse('content://test/tree/primary%3AFoo/document/arbitrary'),
      ),
      isTrue,
    );
    expect(
      sharesImportGrant(
        grant,
        Uri.parse('content://test/tree/primary%3AFoobar'),
      ),
      isFalse,
    );
    expect(
      sharesImportGrant(grant, Uri.parse('content://other/tree/primary%3AFoo')),
      isFalse,
    );
    expect(
      sharesImportGrant(grant, Uri.parse('content://test/document/opaque')),
      isTrue,
    );
  });
}
