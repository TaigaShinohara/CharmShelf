import 'package:flutter_test/flutter_test.dart';
import 'package:private_shelf/features/library/domain/models/file_tree.dart';

void main() {
  test(
    'document selection preserves its URI independently of a tree grant',
    () {
      final document = Uri.parse('content://provider/document/opaque-photo');
      final selected = FileTreeNode(
        name: 'photo.jpg',
        uri: document,
        sourceDocumentUri: document,
        relativePath: 'selected-document-1',
        isDirectory: false,
        isMedia: true,
        mimeType: 'image/jpeg',
      );

      final edited = selected.copyWith(includeInImport: false, isCatalog: true);
      final restored = FileTreeNode.fromMap(edited.toMap());

      expect(restored.uri, document);
      expect(restored.sourceDocumentUri, document);
      expect(restored.sourceTreeUri, isNull);
      expect(restored.relativePath, 'selected-document-1');
      expect(restored.size, isNull);
      expect(restored.mimeType, 'image/jpeg');
      expect(restored.includeInImport, isFalse);
      expect(restored.isCatalog, isTrue);
    },
  );

  test(
    'old draft without a document grant retains its tree and source identity',
    () {
      final restored = FileTreeNode.fromMap({
        'name': 'photo.jpg',
        'uri': 'content://provider/tree/root/document/photo',
        'sourceTreeUri': 'content://provider/tree/root',
        'sourceIdentity': 'legacy-identity',
        'relativePath': 'Album/photo.jpg',
        'isDirectory': false,
        'isMedia': true,
        'size': 3,
      });

      expect(restored.sourceDocumentUri, isNull);
      expect(restored.sourceTreeUri, Uri.parse('content://provider/tree/root'));
      expect(restored.sourceIdentity, 'legacy-identity');
      expect(restored.size, 3);
      expect(restored.includeInImport, isTrue);
      expect(
        restored.copyWith(isCatalog: true).sourceTreeUri,
        restored.sourceTreeUri,
      );
    },
  );
}
