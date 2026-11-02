import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

const minimumAndroidPageAlignment = 0x4000;
const expectedIsarVersion = '3.1.0+1';

const expectedAndroidNativeLibraries = <String, String>{
  'patches/isar_flutter_libs/android/src/main/jniLibs/arm64-v8a/libisar.so':
      'fc8ba57331c06ae596a842f9b8ca80b257668f9029ebcd21d81b20b4c3f5b522',
  'patches/isar_flutter_libs/android/src/main/jniLibs/armeabi-v7a/libisar.so':
      '54acaa19df2815bfd1643efb26902a0092b6c705d29e1e71ad1277211612ffd5',
  'patches/isar_flutter_libs/android/src/main/jniLibs/x86/libisar.so':
      '587bbbf77357a5fdc8836a0a519e57fd594f6731a8dffaffbe3f592914ef0523',
  'patches/isar_flutter_libs/android/src/main/jniLibs/x86_64/libisar.so':
      'e6fdd23b9f4167cb88efbaedbc6ab7c9e2b452788de3b69b70e5d8958cfdaa98',
};

final class ElfAlignmentReport {
  const ElfAlignmentReport(this.loadAlignments);

  final List<int> loadAlignments;

  bool get supports16KbPages =>
      loadAlignments.isNotEmpty &&
      loadAlignments.every(
        (alignment) => alignment >= minimumAndroidPageAlignment,
      );
}

ElfAlignmentReport inspectAndroidElf(Uint8List bytes) {
  if (bytes.length < 16 ||
      bytes[0] != 0x7f ||
      bytes[1] != 0x45 ||
      bytes[2] != 0x4c ||
      bytes[3] != 0x46) {
    throw const FormatException('ELFヘッダーがありません');
  }

  final elfClass = bytes[4];
  if (elfClass != 1 && elfClass != 2) {
    throw FormatException('未対応のELFクラスです: $elfClass');
  }

  final byteOrder = switch (bytes[5]) {
    1 => Endian.little,
    2 => Endian.big,
    final value => throw FormatException('未対応のELFバイト順です: $value'),
  };
  final is64Bit = elfClass == 2;
  final minimumHeaderSize = is64Bit ? 58 : 46;
  if (bytes.length < minimumHeaderSize) {
    throw const FormatException('ELFヘッダーが途中で切れています');
  }

  final data = ByteData.sublistView(bytes);
  final programHeaderOffset = is64Bit
      ? data.getUint64(32, byteOrder)
      : data.getUint32(28, byteOrder);
  final programHeaderEntrySize = data.getUint16(is64Bit ? 54 : 42, byteOrder);
  final programHeaderCount = data.getUint16(is64Bit ? 56 : 44, byteOrder);
  final minimumEntrySize = is64Bit ? 56 : 32;
  if (programHeaderEntrySize < minimumEntrySize) {
    throw FormatException('ELFプログラムヘッダーが短すぎます: $programHeaderEntrySize');
  }

  final alignments = <int>[];
  for (var index = 0; index < programHeaderCount; index++) {
    final entryOffset = programHeaderOffset + index * programHeaderEntrySize;
    if (entryOffset < 0 || entryOffset + minimumEntrySize > bytes.length) {
      throw const FormatException('ELFプログラムヘッダーが途中で切れています');
    }
    final type = data.getUint32(entryOffset, byteOrder);
    if (type != 1) continue; // PT_LOAD
    final alignment = is64Bit
        ? data.getUint64(entryOffset + 48, byteOrder)
        : data.getUint32(entryOffset + 28, byteOrder);
    alignments.add(alignment);
  }

  return ElfAlignmentReport(List.unmodifiable(alignments));
}

Future<void> main() async {
  final failures = <String>[];

  for (final entry in expectedAndroidNativeLibraries.entries) {
    final file = File(entry.key);
    if (!await file.exists()) {
      failures.add('${entry.key}: ファイルがありません');
      continue;
    }

    try {
      final fileFailures = <String>[];
      final bytes = await file.readAsBytes();
      final report = inspectAndroidElf(bytes);
      if (!report.supports16KbPages) {
        final actual = report.loadAlignments
            .map((alignment) => '0x${alignment.toRadixString(16)}')
            .join(', ');
        fileFailures.add('${entry.key}: PT_LOAD alignment=$actual');
      }
      if (!_containsSequence(bytes, ascii.encode(expectedIsarVersion))) {
        fileFailures.add('${entry.key}: Isar $expectedIsarVersion を確認できません');
      }

      final actualDigest = sha256.convert(bytes).toString();
      if (actualDigest != entry.value) {
        fileFailures.add(
          '${entry.key}: SHA-256が監査済みバイナリと一致しません '
          '(actual=$actualDigest)',
        );
      }

      failures.addAll(fileFailures);
      if (fileFailures.isEmpty) {
        final alignments = report.loadAlignments
            .map((alignment) => '0x${alignment.toRadixString(16)}')
            .toSet()
            .join(',');
        stdout.writeln('${entry.key}: OK (PT_LOAD=$alignments)');
      }
    } on FormatException catch (error) {
      failures.add('${entry.key}: ${error.message}');
    }
  }

  if (failures.isNotEmpty) {
    stderr.writeln('Androidネイティブライブラリ検査に失敗しました:');
    for (final failure in failures) {
      stderr.writeln('  $failure');
    }
    exitCode = 1;
    return;
  }

  stdout.writeln('Android 16KB ELF alignmentチェック: OK');
}

bool _containsSequence(List<int> bytes, List<int> sequence) {
  if (sequence.isEmpty || sequence.length > bytes.length) return false;
  for (var start = 0; start <= bytes.length - sequence.length; start++) {
    var matches = true;
    for (var offset = 0; offset < sequence.length; offset++) {
      if (bytes[start + offset] != sequence[offset]) {
        matches = false;
        break;
      }
    }
    if (matches) return true;
  }
  return false;
}
