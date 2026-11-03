import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Original, deterministic synthetic PDF; no user files or downloaded assets.
/// The encrypted variant uses the PDF 1.4 Standard security handler, revision 2,
/// solely to exercise password failure/recovery. Its test password is public.
Uint8List pdfFixture({bool encrypted = false}) {
  const padding = <int>[
    0x28,
    0xbf,
    0x4e,
    0x5e,
    0x4e,
    0x75,
    0x8a,
    0x41,
    0x64,
    0x00,
    0x4e,
    0x56,
    0xff,
    0xfa,
    0x01,
    0x08,
    0x2e,
    0x2e,
    0x00,
    0xb6,
    0xd0,
    0x68,
    0x3e,
    0x80,
    0x2f,
    0x0c,
    0xa9,
    0xfe,
    0x64,
    0x53,
    0x69,
    0x7a,
  ];
  List<int> pad(String value) =>
      [...ascii.encode(value), ...padding].take(32).toList();
  List<int> digest(List<int> value) => md5.convert(value).bytes;
  final id = digest(ascii.encode('CharmShelf original PDF QA fixture'));
  final owner = _rc4(
    digest(pad('qa-owner')).take(5).toList(),
    pad('qa-reader'),
  );
  final permissions = ByteData(4)..setInt32(0, -4, Endian.little);
  final key = digest([
    ...pad('qa-reader'),
    ...owner,
    ...permissions.buffer.asUint8List(),
    ...id,
  ]).take(5).toList();
  final user = _rc4(key, padding);
  String hex(List<int> bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  List<int> encode(int object, String text) {
    final bytes = ascii.encode(text);
    if (!encrypted) return bytes;
    final objectKey = digest([...key, object & 255, object >> 8, 0, 0, 0])
        .take(10)
        .toList();
    return _rc4(objectKey, bytes);
  }

  List<int> stream(int object, String text) {
    final data = encode(object, text);
    return [
      ...ascii.encode('<< /Length ${data.length} >>\nstream\n'),
      ...data,
      ...ascii.encode('\nendstream'),
    ];
  }

  final uri = hex(encode(8, 'https://example.invalid/charmshelf-pdf-qa'));
  final objects = <List<int>>[
    ascii.encode('<< /Type /Catalog /Pages 2 0 R >>'),
    ascii.encode('<< /Type /Pages /Kids [4 0 R 6 0 R] /Count 2 >>'),
    ascii.encode('<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>'),
    ascii.encode(
      '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 400 500] /Resources << /Font << /F1 3 0 R >> >> /Contents 5 0 R /Annots [8 0 R 9 0 R] >>',
    ),
    stream(
      5,
      'BT /F1 20 Tf 40 440 Td (CharmShelf PDF QA) Tj 0 -40 Td (Selectable synthetic text) Tj 0 -60 Td (External link) Tj 0 -60 Td (Go to page two) Tj ET',
    ),
    ascii.encode(
      '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 400 500] /Resources << /Font << /F1 3 0 R >> >> /Contents 7 0 R >>',
    ),
    stream(7, 'BT /F1 20 Tf 40 440 Td (Second synthetic page) Tj ET'),
    ascii.encode(
      '<< /Type /Annot /Subtype /Link /Rect [35 335 240 365] /Border [0 0 0] /A << /S /URI /URI <$uri> >> >>',
    ),
    ascii.encode(
      '<< /Type /Annot /Subtype /Link /Rect [35 275 240 305] /Border [0 0 0] /Dest [6 0 R /Fit] >>',
    ),
    if (encrypted)
      ascii.encode(
        '<< /Filter /Standard /V 1 /R 2 /O <${hex(owner)}> /U <${hex(user)}> /P -4 >>',
      ),
  ];
  final output = BytesBuilder()..add(ascii.encode('%PDF-1.4\n'));
  final offsets = <int>[0];
  for (var i = 0; i < objects.length; i++) {
    offsets.add(output.length);
    output.add(ascii.encode('${i + 1} 0 obj\n'));
    output.add(objects[i]);
    output.add(ascii.encode('\nendobj\n'));
  }
  final xref = output.length;
  output.add(ascii.encode('xref\n0 ${offsets.length}\n0000000000 65535 f \n'));
  for (final offset in offsets.skip(1)) {
    output.add(
      ascii.encode('${offset.toString().padLeft(10, '0')} 00000 n \n'),
    );
  }
  output.add(
    ascii.encode(
      'trailer\n<< /Size ${offsets.length} /Root 1 0 R /ID [<${hex(id)}> <${hex(id)}>] ${encrypted ? '/Encrypt 10 0 R' : ''} >>\nstartxref\n$xref\n%%EOF\n',
    ),
  );
  return output.takeBytes();
}

List<int> _rc4(List<int> key, List<int> input) {
  final state = List<int>.generate(256, (i) => i);
  var j = 0;
  void swap(int a, int b) {
    final value = state[a];
    state[a] = state[b];
    state[b] = value;
  }

  for (var i = 0; i < 256; i++) {
    j = (j + state[i] + key[i % key.length]) & 255;
    swap(i, j);
  }
  var i = 0;
  j = 0;
  return input.map((byte) {
    i = (i + 1) & 255;
    j = (j + state[i]) & 255;
    swap(i, j);
    return byte ^ state[(state[i] + state[j]) & 255];
  }).toList();
}
