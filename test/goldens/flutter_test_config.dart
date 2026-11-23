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

/// Golden baselines are host-dependent (font rasterization differs between
/// macOS and Linux), so Linux runs use baselines under a `linux/` subfolder
/// next to the macOS ones. This keeps the pre-delivery golden check runnable
/// in the Linux development VM instead of skipping it there.
Uri _platformGolden(Uri golden) {
  if (!Platform.isLinux) return golden;
  const prefix = 'goldens/goldens/';
  final path = golden.path;
  if (!path.startsWith(prefix)) return golden;
  return Uri.parse('goldens/goldens/linux/${path.substring(prefix.length)}');
}

class _TolerantFileComparator extends LocalFileComparator {
  _TolerantFileComparator(super.basedir);

  @override
  Future<void> update(Uri testName, Uint8List imageBytes) {
    return super.update(_platformGolden(testName), imageBytes);
  }

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final effectiveGolden = _platformGolden(golden);
    final goldenFullUri = basedir.resolveUri(effectiveGolden);
    debugPrint('Comparing against (resolved): $goldenFullUri');

    if (!await File.fromUri(goldenFullUri).exists()) {
      debugPrint('Golden file does NOT exist at: $goldenFullUri');
      // Fallback to default behavior to let it throw the standard error
      return super.compare(imageBytes, effectiveGolden);
    }

    final result = await GoldenFileComparator.compareLists(
      imageBytes,
      await getGoldenBytes(effectiveGolden),
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
