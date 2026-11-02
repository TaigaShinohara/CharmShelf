// audit: allow-file-io
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

enum FreshStartPhase {
  clearingStorage,
  clearingCredentials,
  clearingPreferences,
  finishing,
}

class FreshStartRecoveryState {
  const FreshStartRecoveryState({
    required this.entryChoice,
    required this.phase,
  });

  final String entryChoice;
  final FreshStartPhase phase;
}

/// 確定済みの新規開始を、DB・私有ファイル・設定と独立した場所に保存する。
/// 一時ファイルだけでは消去を開始せず、保存の検証後にのみ先へ進む。
class FreshStartRecoveryStore {
  FreshStartRecoveryStore({Future<Directory> Function()? supportDirectory})
    : _supportDirectory = supportDirectory ?? getApplicationSupportDirectory;

  static const markerFileName = '.fresh_start_pending_v1';
  final Future<Directory> Function() _supportDirectory;

  Future<FreshStartRecoveryState?> readState() async {
    final marker = await _markerFile();
    if (!await marker.exists()) return null;
    final decoded = jsonDecode(await marker.readAsString());
    if (decoded is! Map<String, dynamic> ||
        decoded['version'] != 1 ||
        !const ['first', 'fresh'].contains(decoded['entryChoice']) ||
        !FreshStartPhase.values.any(
          (phase) => phase.name == decoded['phase'],
        )) {
      throw const FormatException('Invalid fresh start recovery marker');
    }
    return FreshStartRecoveryState(
      entryChoice: decoded['entryChoice'] as String,
      phase: FreshStartPhase.values.byName(decoded['phase'] as String),
    );
  }

  Future<void> markPending(String entryChoice) async {
    if (!const ['first', 'fresh'].contains(entryChoice)) {
      throw ArgumentError.value(entryChoice, 'entryChoice');
    }
    final existing = await readState();
    if (existing != null) {
      if (existing.entryChoice != entryChoice) {
        throw StateError('A different fresh start is already pending');
      }
      return;
    }
    await writePhase(entryChoice, FreshStartPhase.clearingStorage);
  }

  Future<void> writePhase(String entryChoice, FreshStartPhase phase) async {
    if (!const ['first', 'fresh'].contains(entryChoice)) {
      throw ArgumentError.value(entryChoice, 'entryChoice');
    }
    final marker = await _markerFile();
    await marker.parent.create(recursive: true);
    final temporary = File('${marker.path}.tmp');
    await temporary.writeAsString(
      jsonEncode({
        'version': 1,
        'entryChoice': entryChoice,
        'phase': phase.name,
      }),
      flush: true,
    );
    await temporary.rename(marker.path);
    final saved = await readState();
    if (saved?.entryChoice != entryChoice || saved?.phase != phase) {
      throw const FileSystemException('Could not persist fresh start marker');
    }
  }

  Future<void> markComplete() async {
    final marker = await _markerFile();
    if (await marker.exists()) await marker.delete();
    if (await marker.exists()) {
      throw const FileSystemException('Could not remove fresh start marker');
    }
  }

  Future<File> _markerFile() async {
    final support = await _supportDirectory();
    return File(p.join(support.path, markerFileName));
  }
}
