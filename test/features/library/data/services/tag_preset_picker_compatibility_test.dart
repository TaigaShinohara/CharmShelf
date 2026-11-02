import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:mocktail/mocktail.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:private_shelf/core/error/app_error.dart';
import 'package:private_shelf/core/services/import_safety_policy.dart';
import 'package:private_shelf/features/library/data/services/tag_preset_service.dart';

import '../../../../helpers/picker_test_file.dart';

class _Isar extends Mock implements Isar {}

class _Picker extends Mock
    with MockPlatformInterfaceMixin
    implements FilePickerPlatform {}

class _ExportService extends TagPresetService {
  _ExportService() : super(_Isar());

  @override
  Future<TagPresetExportData> exportPresetsAsJsonString({
    int? facetId,
    DateTime? exportedAt,
  }) async => const TagPresetExportData(
    jsonString: '{"charms":[]}',
    fileName: 'synthetic.json',
    facetCount: 0,
    tagCount: 0,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Picker picker;
  late FilePickerPlatform original;
  late TagPresetService service;

  setUpAll(() => registerFallbackValue(Uint8List(0)));
  setUp(() {
    original = FilePickerPlatform.instance;
    picker = _Picker();
    FilePickerPlatform.instance = picker;
    service = _ExportService();
  });
  tearDown(() => FilePickerPlatform.instance = original);

  void selected(PlatformFile? file) => when(
    () => picker.pickFile(
      type: FileType.custom,
      allowedExtensions: any(named: 'allowedExtensions'),
    ),
  ).thenAnswer((_) async => file);

  test('single selection cancellation remains cancellation', () async {
    selected(null);
    expect(await service.pickPresetFileContent(), isNull);
  });

  test('a file without a local path is read through its byte stream', () async {
    const source = '{"charms":[{"name":"合成データ📚"}]}';
    selected(
      PickerTestFile(
        name: 'synthetic.json',
        uri: Uri.parse('content://synthetic/42'),
        bytes: utf8.encode(source),
      ),
    );
    expect(await service.pickPresetFileContent(), source);
  });

  test(
    'unknown and misleading lengths cannot bypass the metadata byte limit',
    () async {
      for (final length in <int?>[null, 1]) {
        final chunk = Uint8List(1024 * 1024);
        selected(
          PickerTestFile(
            name: 'oversized.json',
            uri: Uri.parse('content://synthetic/oversized'),
            knownLength: length,
            stream: () => Stream.fromIterable(
              List.filled(
                ImportSafetyPolicy.maxMetadataBytes ~/ chunk.length + 1,
                chunk,
              ),
            ),
          ),
        );
        await expectLater(
          service.pickPresetFileContent(),
          throwsA(isA<AppError>()),
        );
      }
    },
  );

  test(
    'save accepts the URI returned after the plugin writes the bytes',
    () async {
      final uri = Uri.parse('content://synthetic/export/42');
      when(
        () => picker.saveFile(
          fileName: 'synthetic.json',
          bytes: any(named: 'bytes'),
          mimeType: 'application/json',
        ),
      ).thenAnswer((_) async => uri);
      final result = await service.exportPresetsToFile();
      expect(result!.path, uri.toString());
      final bytes =
          verify(
                () => picker.saveFile(
                  fileName: 'synthetic.json',
                  bytes: captureAny(named: 'bytes'),
                  mimeType: 'application/json',
                ),
              ).captured.single
              as Uint8List;
      expect(utf8.decode(bytes), '{"charms":[]}\n');
    },
  );

  test('save cancellation does not become a successful export', () async {
    when(
      () => picker.saveFile(
        fileName: 'synthetic.json',
        bytes: any(named: 'bytes'),
        mimeType: 'application/json',
      ),
    ).thenAnswer((_) async => null);
    expect(await service.exportPresetsToFile(), isNull);
  });
}
