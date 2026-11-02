import 'package:flutter_test/flutter_test.dart';
import 'package:private_shelf/core/error/result.dart';

void main() {
  test('Result.success stores data', () {
    final r = Result<int, String>.success(42);
    expect(r.isSuccess, true);
    expect(r.isFailure, false);
    expect(r.dataOrNull, 42);
    expect(r.errorOrNull, null);
  });

  test('Result.failure stores error', () {
    final r = Result<int, String>.failure('oops');
    expect(r.isSuccess, false);
    expect(r.isFailure, true);
    expect(r.dataOrNull, null);
    expect(r.errorOrNull, 'oops');
  });
}
