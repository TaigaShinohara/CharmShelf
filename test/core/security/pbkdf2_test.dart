import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:private_shelf/core/security/pbkdf2.dart';

void main() {
  group('derivePbkdf2Sha256', () {
    test('RFC互換のPBKDF2-HMAC-SHA256既知ベクトルと一致する (c=1)', () {
      final derived = derivePbkdf2Sha256(
        password: 'password',
        salt: utf8.encode('salt'),
        iterations: 1,
        length: 32,
      );

      expect(
        derived.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join(),
        '120fb6cffcf8b32c43e7225256c4f837a86548c92ccc35480805987cb70be17b',
      );
    });

    test('RFC互換のPBKDF2-HMAC-SHA256既知ベクトルと一致する (c=2)', () {
      final derived = derivePbkdf2Sha256(
        password: 'password',
        salt: utf8.encode('salt'),
        iterations: 2,
        length: 32,
      );

      expect(
        derived.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join(),
        'ae4d0c95af6b46d32d0adff928f06dd02a303f8ef3c251dfd6e2d85a95474c43',
      );
    });

    test('RFC互換のPBKDF2-HMAC-SHA256既知ベクトルと一致する (c=4096)', () {
      final derived = derivePbkdf2Sha256(
        password: 'password',
        salt: utf8.encode('salt'),
        iterations: 4096,
        length: 32,
      );

      expect(
        derived.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join(),
        'c5e478d59288c841aa530db6845c4c8d962893a001ce4e11a4963873aa98134a',
      );
    });

    test('不正な引数の場合はArgumentErrorをスローする', () {
      expect(
        () => derivePbkdf2Sha256(
          password: 'password',
          salt: utf8.encode('salt'),
          iterations: 0,
          length: 32,
        ),
        throwsArgumentError,
      );

      expect(
        () => derivePbkdf2Sha256(
          password: 'password',
          salt: utf8.encode('salt'),
          iterations: 1,
          length: 0,
        ),
        throwsArgumentError,
      );
    });
  });
}
