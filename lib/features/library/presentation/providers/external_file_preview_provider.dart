import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:private_shelf/features/library/data/services/external_storage_service.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:path/path.dart' as p;

part 'external_file_preview_provider.g.dart';

/// 外部参照ファイルの一時パスを取得・保持するプロバイダー。
///
/// 画面の再ビルドによって `copyToTemp` が何度も呼ばれるのを防ぎ、
/// Android/iOS での安定した画像表示を実現します。
@riverpod
Future<String?> externalFilePreview(Ref ref, MediaItem item) async {
  final keepAliveLink = ref.keepAlive();
  Timer? disposeTimer;
  String? copiedPath;
  ref.onCancel(() {
    disposeTimer = Timer(const Duration(minutes: 5), keepAliveLink.close);
  });
  ref.onResume(() {
    disposeTimer?.cancel();
    disposeTimer = null;
  });
  ref.onDispose(() {
    disposeTimer?.cancel();
    disposeTimer = null;
    final path = copiedPath;
    if (path != null) unawaited(_deleteManagedPreview(path));
  });

  final storageService = await ref.watch(externalStorageServiceProvider.future);
  if (!ref.mounted) return null;

  // URI をパース（必要に応じてスキームを補完）
  var uri = Uri.parse(item.path);
  if (!uri.hasScheme) {
    uri = Uri.file(item.path);
  }

  // 一時ディレクトリにコピー（既にある場合は再利用される）
  final fileName = p.basename(
    item.originalPath.isNotEmpty ? item.originalPath : item.path,
  );
  final resolvedPath = await storageService.copyToTemp(uri, fileName);
  if (!ref.mounted) {
    if (resolvedPath != null) await _deleteManagedPreview(resolvedPath);
    return null;
  }
  copiedPath = resolvedPath;
  return resolvedPath;
}

Future<void> _deleteManagedPreview(String path) async {
  final tempDir = await getTemporaryDirectory();
  final managedDir = p.join(tempDir.path, 'external_view');
  if (!p.isWithin(managedDir, path)) return;
  final file = File(path);
  if (await file.exists()) await file.delete();
}
