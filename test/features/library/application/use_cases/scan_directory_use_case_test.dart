import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:private_shelf/features/library/application/use_cases/scan_directory_use_case.dart';
import 'package:private_shelf/features/library/data/services/external_storage_service.dart';

class _MockExternalStorageService extends Mock
    implements ExternalStorageService {}

void main() {
  test('直下と子孫のメディアを区別してツリーを構築する', () async {
    final storage = _MockExternalStorageService();
    final rootUri = Uri.file('/library');
    final entries = [
      ExternalFileInfo(
        uri: 'file:///library/Parent',
        name: 'Parent',
        relativePath: 'Parent',
        isDirectory: true,
      ),
      ExternalFileInfo(
        uri: 'file:///library/Parent/Child',
        name: 'Child',
        relativePath: 'Parent/Child',
        isDirectory: true,
      ),
      ExternalFileInfo(
        uri: 'file:///library/Parent/Child/photo.jpg',
        name: 'photo.jpg',
        relativePath: 'Parent/Child/photo.jpg',
        isMedia: true,
      ),
      ExternalFileInfo(
        uri: 'file:///library/Empty',
        name: 'Empty',
        relativePath: 'Empty',
        isDirectory: true,
      ),
    ];
    when(
      () => storage.listFiles(rootUri),
    ).thenAnswer((_) => Stream.fromIterable(entries));

    final result = await ScanDirectoryUseCase(storage).invoke(rootUri);
    expect(result.isSuccess, isTrue);
    final root = result.dataOrNull!;
    final parent = root.children.singleWhere((node) => node.name == 'Parent');
    final child = parent.children.singleWhere((node) => node.name == 'Child');
    final empty = root.children.singleWhere((node) => node.name == 'Empty');
    expect(parent.isMedia, isTrue);
    expect(child.isMedia, isTrue);
    expect(child.isCatalog, isTrue);
    expect(empty.isMedia, isFalse);
    expect(empty.isCatalog, isTrue);
  });
}
