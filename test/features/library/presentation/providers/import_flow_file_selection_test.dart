import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:private_shelf/features/library/presentation/providers/import_flow_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'file picker records actual support while retaining the explicit selection',
    () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await container.read(importFlowNotifierProvider.notifier).startFilesScan([
        '/source/photo.jpg',
        '/source/unsupported.bin',
        '/source/archive.zip',
        '/source/.hidden.jpg',
      ]);
      final state = container.read(importFlowNotifierProvider);
      expect(state.status, ImportFlowStatus.confirming);
      final children = state.rootNode!.children;
      expect(children.map((node) => node.isMedia), [true, false, true, false]);
      // Unsupported picks remain represented so completion can explain their
      // rejection, instead of silently dropping what the user selected.
      expect(children.every((node) => node.includeInImport), isTrue);
      // Registration is the user's choice, independent of media detection.
      expect(children.every((node) => node.isCatalog), isTrue);
      container
          .read(importFlowNotifierProvider.notifier)
          .updateCatalogRegistration('/source/photo.jpg', false);
      final updated = container.read(importFlowNotifierProvider).rootNode!;
      expect(updated.children.first.isCatalog, isFalse);
      expect(updated.children.first.isMedia, isTrue);
      expect(updated.children[1].isCatalog, isTrue);
      expect(children.map((node) => node.relativePath), [
        '/source/photo.jpg',
        '/source/unsupported.bin',
        '/source/archive.zip',
        '/source/.hidden.jpg',
      ]);
    },
  );
}
