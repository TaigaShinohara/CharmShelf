import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  if (goldenFileComparator is LocalFileComparator) {
    final comparator = goldenFileComparator as LocalFileComparator;
    goldenFileComparator = _TolerantFileComparator(comparator.basedir);
  }
  await testMain();
}

class _TolerantFileComparator extends LocalFileComparator {
  _TolerantFileComparator(super.basedir);

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final goldenFullUri = basedir.resolveUri(golden);
    debugPrint('Comparing against (resolved): $goldenFullUri');

    if (!await File.fromUri(goldenFullUri).exists()) {
      debugPrint('Golden file does NOT exist at: $goldenFullUri');
      // Fallback to default behavior to let it throw the standard error
      return super.compare(imageBytes, golden);
    }

    final result = await GoldenFileComparator.compareLists(
      imageBytes,
      await getGoldenBytes(golden),
    );

    if (result.passed) {
      return true;
    }

    if (result.diffPercent <= 0.005) {
      debugPrint('Golden comparison tolerant success: ${result.diffPercent * 100}% diff');
      return true;
    }

    final message = result.error ?? 'Golden file comparison failed';
    throw FlutterError('$message\n'
        'Detected a difference of ${(result.diffPercent * 100).toStringAsFixed(4)}% '
        'between the actual image and the golden file.');
  }
}
