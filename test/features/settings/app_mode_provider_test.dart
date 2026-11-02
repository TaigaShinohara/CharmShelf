import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:riverpod/riverpod.dart';
import 'package:private_shelf/features/settings/presentation/providers/app_mode_provider.dart';

class _SavedExternalMode extends AppModeAsync {
  @override
  Future<AppMode> build() async => AppMode.external;
}

void main() {
  test('外部モード無効中は保存値がexternalでも内部モードとして扱う', () async {
    final container = ProviderContainer(
      overrides: [
        appModeAsyncProvider.overrideWith(() => _SavedExternalMode()),
      ],
    );
    addTearDown(container.dispose);

    await container.read(appModeAsyncProvider.future);

    expect(container.read(appModeProvider), AppMode.internal);
    expect(container.read(isExternalModeProvider), isFalse);
  });

  test('外部モード無効中はexternalへの変更を拒否する', () async {
    final container = ProviderContainer(
      overrides: [
        appModeAsyncProvider.overrideWith(() => _SavedExternalMode()),
      ],
    );
    addTearDown(container.dispose);

    final changed = await container
        .read(appModeAsyncProvider.notifier)
        .setMode(AppMode.external);

    expect(changed, isFalse);
  });
}
