import 'package:flutter_test/flutter_test.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';

void main() {
  test('MediaTier fromInt returns expected tier for each value', () {
    expect(MediaTier.fromInt(5), MediaTier.s);
    expect(MediaTier.fromInt(4), MediaTier.a);
    expect(MediaTier.fromInt(3), MediaTier.b);
    expect(MediaTier.fromInt(2), MediaTier.c);
    expect(MediaTier.fromInt(1), MediaTier.d);
    expect(MediaTier.fromInt(0), MediaTier.none);
  });
}
