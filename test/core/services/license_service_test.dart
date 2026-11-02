import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:private_shelf/core/services/license_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('ライセンス一覧は同梱部品の著作権表示を含み、除去した部品を含まない', () async {
    LicenseRegistry.reset();
    LicenseService.registerCustomLicenses();

    final entries = await LicenseRegistry.licenses.toList();
    for (final name in [
      'file_picker_darwin',
      'Mantle',
      'SDWebImage',
      'SDWebImageWebPCoder',
      'libwebp',
      'libmdbx',
      'PDFium and bundled third-party libraries',
    ]) {
      final matching = entries.where((entry) => entry.packages.contains(name));
      expect(matching, isNotEmpty, reason: '$nameの表示が必要');
      expect(
        matching.expand((entry) => entry.paragraphs).map((p) => p.text).join(),
        contains('opyright'),
        reason: '$nameの著作権表示を省略しない',
      );
    }
    for (final name in [
      'DKImagePickerController',
      'DKPhotoGallery',
      'SwiftyGif',
    ]) {
      expect(entries.where((entry) => entry.packages.contains(name)), isEmpty);
    }
    expect(
      entries.where(
        (entry) => entry.packages.any((name) => name.startsWith('syncfusion')),
      ),
      isEmpty,
      reason: 'The public app no longer bundles Syncfusion components',
    );
  });
}
