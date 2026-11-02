// Keep this aligned with tagshelfQaInstance in android/app/build.gradle.kts:
// the isolated QA package may have no instance number or 1-8 ASCII digits.
final _performanceQaPackage = RegExp(
  r'com\.tsmusic\.privateshelf\.opensource\.performanceqa[0-9]{0,8}',
);

/// Rejects non-QA packages before the performance entry point accesses storage.
void requirePerformanceQaPackage(String packageName) {
  final match = _performanceQaPackage.matchAsPrefix(packageName);
  // Check the entire input, including trailing whitespace or line breaks.
  if (match == null || match.end != packageName.length) {
    throw StateError('Performance fixtures require the isolated QA package.');
  }
}
