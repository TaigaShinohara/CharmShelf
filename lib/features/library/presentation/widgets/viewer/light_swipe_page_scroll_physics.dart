import 'package:flutter/widgets.dart';

/// 画像・動画ビューワー向けの軽量スワイプ対応 [ScrollPhysics]。
///
/// Flutter標準の [PageScrollPhysics] は低速ドラッグ時に画面幅の 50% 以上ドラッグしないと
/// 元のページに戻ってしまう仕様ですが、本クラスでは [snapThresholdFraction]（デフォルト 15%）
/// を超えるドラッグ量で次のページ／前のページへ素早くスナップします。
class LightSwipePageScrollPhysics extends ScrollPhysics {
  /// [LightSwipePageScrollPhysics] を作成する。
  const LightSwipePageScrollPhysics({
    super.parent,
    this.snapThresholdFraction = 0.15,
  }) : assert(
         snapThresholdFraction > 0.0 && snapThresholdFraction < 0.5,
         'snapThresholdFraction must be between 0.0 and 0.5',
       );

  /// ページ移動とみなすドラッグ量の割合（画面幅に対する比率: 0.0 〜 0.5）。
  final double snapThresholdFraction;

  @override
  LightSwipePageScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return LightSwipePageScrollPhysics(
      parent: buildParent(ancestor),
      snapThresholdFraction: snapThresholdFraction,
    );
  }

  double _getPage(ScrollMetrics position) {
    if (position is PageMetrics) {
      return position.page!;
    }
    return position.pixels / position.viewportDimension;
  }

  double _getPixels(ScrollMetrics position, double page) {
    if (position is PageMetrics) {
      return page * position.viewportDimension * position.viewportFraction;
    }
    return page * position.viewportDimension;
  }

  double _getTargetPixels(
    ScrollMetrics position,
    Tolerance tolerance,
    double velocity,
  ) {
    var page = _getPage(position);

    if (velocity < -tolerance.velocity) {
      page -= 0.5;
      return _getPixels(position, page.roundToDouble());
    } else if (velocity > tolerance.velocity) {
      page += 0.5;
      return _getPixels(position, page.roundToDouble());
    }

    final floorPage = page.floorToDouble();
    final progress = page - floorPage;

    if (progress < 0.5) {
      if (progress >= snapThresholdFraction) {
        return _getPixels(position, floorPage + 1.0);
      } else {
        return _getPixels(position, floorPage);
      }
    } else {
      if (1.0 - progress >= snapThresholdFraction) {
        return _getPixels(position, floorPage);
      } else {
        return _getPixels(position, floorPage + 1.0);
      }
    }
  }

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    if ((velocity <= 0.0 && position.pixels <= position.minScrollExtent) ||
        (velocity >= 0.0 && position.pixels >= position.maxScrollExtent)) {
      return super.createBallisticSimulation(position, velocity);
    }
    final tolerance = toleranceFor(position);
    final target = _getTargetPixels(position, tolerance, velocity);
    if (target != position.pixels) {
      return ScrollSpringSimulation(
        // 指を離した後に移動先が決まったら、次のファイルをすぐ見せる。
        // 端でのバウンドやドラッグ中の追従は parent に引き続き任せる。
        SpringDescription.withDurationAndBounce(
          duration: const Duration(milliseconds: 50),
          bounce: 0.0,
        ),
        position.pixels,
        target,
        velocity,
        tolerance: tolerance,
      );
    }
    return null;
  }

  @override
  bool get allowImplicitScrolling => false;
}
