import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:private_shelf/features/library/domain/models/restorable_data_summary.dart';
import 'package:private_shelf/features/library/presentation/providers/data_restore_provider.dart';

void main() {
  test('Androidの自動検出は空として完了し公開フォルダ選択を要求しない', () async {
    final container = ProviderContainer(
      overrides: [dataRestoreIsAndroidProvider.overrideWithValue(true)],
    );
    addTearDown(container.dispose);

    final result = await container
        .read(dataRestoreNotifierProvider.notifier)
        .detect();

    expect(result.isSuccess, isTrue);
    expect(result.dataOrNull, RestorableDataSummary.empty);
    expect(
      container.read(dataRestoreNotifierProvider).status,
      DataRestoreStatus.idle,
    );
  });

  test('手動復元を選ぶとフォルダ選択待ちになる', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container
        .read(dataRestoreNotifierProvider.notifier)
        .prepareManualFolderRestore();

    expect(
      container.read(dataRestoreNotifierProvider).status,
      DataRestoreStatus.permissionRequired,
    );
  });
}
