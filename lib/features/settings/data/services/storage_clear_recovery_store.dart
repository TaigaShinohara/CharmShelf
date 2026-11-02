// audit: allow-file-io
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

enum StorageClearRecoveryStage { clearingInternal, releasingExternal }

/// ストレージ消去が完了するまで残す永続マーカー。
///
/// 通常の操作ジャーナルや消去対象ディレクトリとは分離し、プロセス終了後も
/// 次回起動時に消去処理を再開できるようにする。
class StorageClearRecoveryStore {
  StorageClearRecoveryStore({Future<Directory> Function()? supportDirectory})
    : _supportDirectory = supportDirectory ?? getApplicationSupportDirectory;

  static const _markerFileName = '.storage_clear_pending_v1';
  static const _temporarySuffix = '.tmp';

  final Future<Directory> Function() _supportDirectory;

  Future<bool> isPending() async => (await readStage()) != null;

  Future<StorageClearRecoveryStage?> readStage() async {
    final marker = await _markerFile();
    if (!await marker.exists()) return null;

    final content = await marker.readAsString();
    if (content == '{"version":1}') {
      return StorageClearRecoveryStage.clearingInternal;
    }
    if (content == '{"version":2,"stage":"clearingInternal"}') {
      return StorageClearRecoveryStage.clearingInternal;
    }
    if (content == '{"version":2,"stage":"releasingExternal"}') {
      return StorageClearRecoveryStage.releasingExternal;
    }
    throw const FormatException('Invalid storage clear recovery marker');
  }

  Future<void> markPending() async {
    if (await readStage() != null) return;
    await _writeStage(StorageClearRecoveryStage.clearingInternal);
  }

  Future<void> markExternalReleasePending() async {
    await _writeStage(StorageClearRecoveryStage.releasingExternal);
  }

  Future<void> _writeStage(StorageClearRecoveryStage stage) async {
    final marker = await _markerFile();

    await marker.parent.create(recursive: true);
    final temporary = File('${marker.path}$_temporarySuffix');
    if (await temporary.exists()) {
      await temporary.delete(); // audit: allow-file-io
    }
    await temporary.writeAsString(
      '{"version":2,"stage":"${stage.name}"}',
      flush: true,
    );
    await temporary.rename(marker.path);

    if (await readStage() != stage) {
      throw const FileSystemException('ストレージ消去の復旧マーカーを保存できませんでした');
    }
  }

  Future<void> markComplete() async {
    final marker = await _markerFile();
    if (await marker.exists()) {
      await marker.delete(); // audit: allow-file-io
    }
    if (await marker.exists()) {
      throw const FileSystemException('ストレージ消去の復旧マーカーを削除できませんでした');
    }
  }

  Future<File> _markerFile() async {
    final support = await _supportDirectory();
    return File(p.join(support.path, _markerFileName));
  }
}
