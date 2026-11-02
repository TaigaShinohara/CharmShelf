import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:private_shelf/shared/widgets/accessibility/semantic_wrapper.dart';

void main() {
  test('最小タップターゲットサイズが48dp以上である', () {
    expect(AccessibilityHelper.minTapTargetSize, 48.0);
    expect(AccessibilityHelper.isValidTapTarget(48, 48), isTrue);
    expect(AccessibilityHelper.isValidTapTarget(47, 48), isFalse);
    expect(AccessibilityHelper.isValidTapTarget(48, 47), isFalse);
  });

  test('コントラスト比の計算とWCAG判定が機能する', () {
    final ratio = AccessibilityHelper.calculateContrastRatio(
      Colors.black,
      Colors.white,
    );

    expect(ratio, greaterThanOrEqualTo(21.0));
    expect(AccessibilityHelper.meetsWcagAA(Colors.black, Colors.white), isTrue);
    expect(
      AccessibilityHelper.meetsWcagAAA(Colors.black, Colors.white),
      isTrue,
    );
    expect(
      AccessibilityHelper.meetsWcagAA(const Color(0xFF666666), Colors.white),
      isTrue,
    );
    expect(
      AccessibilityHelper.meetsWcagAAA(const Color(0xFF666666), Colors.white),
      isFalse,
    );
  });
}
