import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import '../../scripts/maintenance/check_android_elf_alignment.dart';

void main() {
  test('accepts a 64-bit ELF whose PT_LOAD segment is 16KB aligned', () {
    final report = inspectAndroidElf(_elf64WithLoadAlignment(0x4000));

    expect(report.loadAlignments, [0x4000]);
    expect(report.supports16KbPages, isTrue);
  });

  test('rejects a 64-bit ELF whose PT_LOAD segment is only 4KB aligned', () {
    final report = inspectAndroidElf(_elf64WithLoadAlignment(0x1000));

    expect(report.loadAlignments, [0x1000]);
    expect(report.supports16KbPages, isFalse);
  });

  test('rejects truncated ELF input', () {
    expect(
      () => inspectAndroidElf(Uint8List.fromList([0x7f, 0x45, 0x4c, 0x46])),
      throwsFormatException,
    );
  });
}

Uint8List _elf64WithLoadAlignment(int alignment) {
  const programHeaderOffset = 64;
  const programHeaderSize = 56;
  final bytes = Uint8List(programHeaderOffset + programHeaderSize);
  bytes.setAll(0, [0x7f, 0x45, 0x4c, 0x46, 2, 1, 1]);
  final data = ByteData.sublistView(bytes);
  data.setUint64(32, programHeaderOffset, Endian.little);
  data.setUint16(54, programHeaderSize, Endian.little);
  data.setUint16(56, 1, Endian.little);
  data.setUint32(programHeaderOffset, 1, Endian.little); // PT_LOAD
  data.setUint64(programHeaderOffset + 48, alignment, Endian.little);
  return bytes;
}
