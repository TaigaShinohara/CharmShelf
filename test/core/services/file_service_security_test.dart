import 'package:flutter_test/flutter_test.dart';
import 'package:private_shelf/core/error/app_error.dart';
import 'package:private_shelf/core/services/file_service.dart';

void main() {
  final service = FileService();

  for (final root in ['library', '.thumbnails', '.trash', '.imports']) {
    test('管理ルート自身の再帰削除を拒否する: $root', () async {
      final result = await service.deleteFile(root);

      expect(result.isFailure, isTrue);
      expect(result.errorOrNull?.category, ErrorCategory.validation);
    });
  }
}
