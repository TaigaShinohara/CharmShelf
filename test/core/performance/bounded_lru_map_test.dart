import 'package:flutter_test/flutter_test.dart';
import 'package:private_shelf/core/performance/bounded_lru_map.dart';

void main() {
  test('多くの画像を開いても上限内で、最近使用した比率を保持する', () {
    final cache = BoundedLruMap<String, double>(3);
    cache['a'] = 1;
    cache['b'] = 2;
    cache['c'] = 3;
    expect(cache['a'], 1);
    cache['d'] = 4;
    expect(cache.containsKey('b'), isFalse);
    expect(cache.containsKey('a'), isTrue);
    for (var i = 0; i < 10000; i++) {
      cache['image-$i'] = 1;
    }
    expect(cache.length, 3);
    cache.clear();
    expect(cache.isEmpty, isTrue);
  });
}
