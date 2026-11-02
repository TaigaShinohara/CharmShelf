import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

Uint8List derivePbkdf2Sha256({
  required String password,
  required List<int> salt,
  required int iterations,
  required int length,
}) {
  if (iterations < 1 || length < 1) {
    throw ArgumentError('Invalid PBKDF2 parameters');
  }
  final hmac = Hmac(sha256, utf8.encode(password));
  final output = BytesBuilder(copy: false);
  var blockIndex = 1;
  while (output.length < length) {
    final firstInput = List<int>.filled(salt.length + 4, 0);
    firstInput.setRange(0, salt.length, salt);
    firstInput[salt.length] = (blockIndex >> 24) & 0xff;
    firstInput[salt.length + 1] = (blockIndex >> 16) & 0xff;
    firstInput[salt.length + 2] = (blockIndex >> 8) & 0xff;
    firstInput[salt.length + 3] = blockIndex & 0xff;

    var u = hmac.convert(firstInput).bytes;
    final block = Uint8List.fromList(u);
    for (var i = 1; i < iterations; i++) {
      u = hmac.convert(u).bytes;
      for (var j = 0; j < block.length; j++) {
        block[j] ^= u[j];
      }
    }
    output.add(block);
    blockIndex++;
  }
  return Uint8List.sublistView(output.takeBytes(), 0, length);
}
