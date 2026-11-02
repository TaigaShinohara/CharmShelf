import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:private_shelf/core/providers/unsaved_data_provider.dart';

void main() {
  group('UnsavedDataKeys', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('初期状態は空のSet', () {
      final keys = container.read(unsavedDataKeysProvider);
      expect(keys, isEmpty);
    });

    test('markAsUnsavedでキーを追加できる', () {
      container.read(unsavedDataKeysProvider.notifier).markAsUnsaved('form1');

      final keys = container.read(unsavedDataKeysProvider);
      expect(keys, contains('form1'));
      expect(keys.length, 1);
    });

    test('複数のキーを追加できる', () {
      final notifier = container.read(unsavedDataKeysProvider.notifier);
      notifier.markAsUnsaved('form1');
      notifier.markAsUnsaved('form2');
      notifier.markAsUnsaved('form3');

      final keys = container.read(unsavedDataKeysProvider);
      expect(keys.length, 3);
      expect(keys, containsAll(['form1', 'form2', 'form3']));
    });

    test('同じキーを複数回追加しても重複しない', () {
      final notifier = container.read(unsavedDataKeysProvider.notifier);
      notifier.markAsUnsaved('form1');
      notifier.markAsUnsaved('form1');
      notifier.markAsUnsaved('form1');

      final keys = container.read(unsavedDataKeysProvider);
      expect(keys.length, 1);
    });

    test('markAsSavedでキーを削除できる', () {
      final notifier = container.read(unsavedDataKeysProvider.notifier);
      notifier.markAsUnsaved('form1');
      notifier.markAsUnsaved('form2');

      notifier.markAsSaved('form1');

      final keys = container.read(unsavedDataKeysProvider);
      expect(keys, isNot(contains('form1')));
      expect(keys, contains('form2'));
    });

    test('clearAllで全てのキーを削除できる', () {
      final notifier = container.read(unsavedDataKeysProvider.notifier);
      notifier.markAsUnsaved('form1');
      notifier.markAsUnsaved('form2');
      notifier.markAsUnsaved('form3');

      notifier.clearAll();

      final keys = container.read(unsavedDataKeysProvider);
      expect(keys, isEmpty);
    });

    test('存在しないキーをmarkAsSavedしてもエラーにならない', () {
      final notifier = container.read(unsavedDataKeysProvider.notifier);

      // 例外が発生しないことを確認
      expect(() => notifier.markAsSaved('nonexistent'), returnsNormally);
    });

    test('hasUnsavedDataゲッターが正しく動作する', () {
      final notifier = container.read(unsavedDataKeysProvider.notifier);

      expect(notifier.hasUnsavedData, false);

      notifier.markAsUnsaved('form1');
      expect(notifier.hasUnsavedData, true);

      notifier.clearAll();
      expect(notifier.hasUnsavedData, false);
    });
  });

  group('UnsavedDataKeys state changes', () {
    test('未保存データがある場合は空でないSetを返す', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(unsavedDataKeysProvider.notifier).markAsUnsaved('form1');

      final keys = container.read(unsavedDataKeysProvider);
      expect(keys.isNotEmpty, true);
    });

    test('未保存データがない場合は空のSetを返す', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final keys = container.read(unsavedDataKeysProvider);
      expect(keys.isEmpty, true);
    });

    test('全てクリアした後は空のSetを返す', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(unsavedDataKeysProvider.notifier).markAsUnsaved('form1');
      container.read(unsavedDataKeysProvider.notifier).clearAll();

      final keys = container.read(unsavedDataKeysProvider);
      expect(keys.isEmpty, true);
    });
  });
}
