import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:private_shelf/features/samples/data/sample_preview_service.dart';
import 'package:private_shelf/features/samples/domain/sample_catalog.dart';

class _Bundle extends CachingAssetBundle {
  _Bundle(this.read);
  final Future<ByteData> Function(String key) read;
  @override
  Future<ByteData> load(String key) => read(key);
}

void main() {
  test(
    'concurrent requests share a load and completed bytes are reused',
    () async {
      var reads = 0;
      final completer = Completer<ByteData>();
      final service = SamplePreviewService(
        _Bundle((_) {
          reads++;
          return completer.future;
        }),
      );
      final first = service.load('example');
      final second = service.load('example');
      expect(identical(first, second), isTrue);
      completer.complete(ByteData.sublistView(Uint8List.fromList([1, 2, 3])));
      expect(await first, [1, 2, 3]);
      expect(await service.load('example'), [1, 2, 3]);
      expect(reads, 1);
    },
  );

  test(
    'a failed load can be retried without losing other completed assets',
    () async {
      var failingReads = 0;
      var goodReads = 0;
      final service = SamplePreviewService(
        _Bundle((key) async {
          if (key == 'good') {
            goodReads++;
          } else if (++failingReads == 1) {
            throw StateError('asset unavailable');
          }
          return ByteData(1);
        }),
      );
      await service.load('good');
      await expectLater(service.load('failed'), throwsStateError);
      await service.load('failed');
      await service.load('good');
      expect(failingReads, 2);
      expect(goodReads, 1);
    },
  );

  test('synchronous bundle errors also remain retryable', () async {
    var reads = 0;
    final service = SamplePreviewService(
      _Bundle((_) {
        if (++reads == 1) throw StateError('failure');
        return Future.value(ByteData(1));
      }),
    );
    await expectLater(service.load('asset'), throwsStateError);
    await service.load('asset');
    expect(reads, 2);
  });

  test('manifest uses stable IDs and locale-specific bundled text only', () {
    final ja = SampleCatalog.forLocale('ja');
    final en = SampleCatalog.forLocale('en');
    expect(ja.map((sample) => sample.id), en.map((sample) => sample.id));
    expect(ja.map((sample) => sample.id).toSet(), hasLength(ja.length));
    expect(ja.last.assets.single, contains('/ja/'));
    expect(en.last.assets.single, contains('/en/'));
    expect(SampleCatalog.forLocale('fr').last.assets.single, contains('/en/'));
  });
}
