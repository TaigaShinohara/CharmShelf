import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:private_shelf/features/library/data/services/external_storage_service.dart';
import 'package:private_shelf/features/library/domain/models/selected_document.dart';
import 'package:private_shelf/features/library/presentation/providers/import_flow_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'MIME makes an extensionless document selectable without renaming its display',
    () async {
      final preferences = await SharedPreferences.getInstance();
      final storage = ExternalStorageService(preferences);
      final container = ProviderContainer(
        overrides: [
          externalStorageServiceProvider.overrideWith((ref) async => storage),
        ],
      );
      addTearDown(container.dispose);
      final flow = container.read(importFlowNotifierProvider.notifier);
      await flow.startDocumentsScan([
        SelectedDocument(
          uri: Uri.parse('content://provider/document/photo'),
          name: 'photo',
          mimeType: 'image/png',
        ),
        SelectedDocument(
          uri: Uri.parse('content://provider/document/unknown'),
          name: 'unknown',
          mimeType: 'image/unknown',
        ),
        SelectedDocument(
          uri: Uri.parse('content://provider/document/unsupported'),
          name: 'unsupported.bin',
          mimeType: 'image/png',
        ),
      ]);

      final state = container.read(importFlowNotifierProvider);
      expect(state.status, ImportFlowStatus.confirming);
      expect(state.rootNode!.children.map((node) => node.name), [
        'photo',
        'unknown',
        'unsupported.bin',
      ]);
      expect(state.rootNode!.children.map((node) => node.isMedia), [
        true,
        false,
        false,
      ]);
    },
  );
}
