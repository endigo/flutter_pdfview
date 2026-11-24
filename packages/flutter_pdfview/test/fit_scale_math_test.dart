import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';

/// Pure-math mirror of iOS `fitScaleForCurrentPolicy` in `FlutterPDFView.m`.
///
/// Kept in tests (not production Dart) so the native formula has a regression
/// oracle without requiring XCTest. If the ObjC implementation changes, update
/// both sides together.
double fitScaleForPolicy({
  required FitPolicy policy,
  required double viewWidth,
  required double viewHeight,
  required double pageWidth,
  required double pageHeight,
  int rotationDegrees = 0,
}) {
  if (viewWidth <= 0 || viewHeight <= 0 || pageWidth <= 0 || pageHeight <= 0) {
    return 0;
  }

  var width = pageWidth;
  var height = pageHeight;
  final int rotation = rotationDegrees % 360;
  if (rotation == 90 || rotation == 270) {
    final double tmp = width;
    width = height;
    height = tmp;
  }

  final double scaleWidth = viewWidth / width;
  final double scaleHeight = viewHeight / height;

  switch (policy) {
    case FitPolicy.HEIGHT:
      return scaleHeight;
    case FitPolicy.BOTH:
      return math.min(scaleWidth, scaleHeight);
    case FitPolicy.WIDTH:
      return scaleWidth;
  }
}

void main() {
  group('fitScaleForPolicy (iOS #150 / #247 formula)', () {
    const double viewW = 390;
    const double viewH = 844;
    // Typical US Letter points.
    const double pageW = 612;
    const double pageH = 792;

    test('WIDTH fills viewport width (may clip height)', () {
      // Short viewport so width-fit still overflows vertically.
      const double shortViewH = 400;
      final double scale = fitScaleForPolicy(
        policy: FitPolicy.WIDTH,
        viewWidth: viewW,
        viewHeight: shortViewH,
        pageWidth: pageW,
        pageHeight: pageH,
      );
      expect(scale, closeTo(viewW / pageW, 1e-9));
      expect(pageW * scale, closeTo(viewW, 1e-6));
      expect(pageH * scale, greaterThan(shortViewH));
    });

    test('HEIGHT fills viewport height (may clip width)', () {
      final double scale = fitScaleForPolicy(
        policy: FitPolicy.HEIGHT,
        viewWidth: viewW,
        viewHeight: viewH,
        pageWidth: pageW,
        pageHeight: pageH,
      );
      expect(scale, closeTo(viewH / pageH, 1e-9));
      expect(pageH * scale, closeTo(viewH, 1e-6));
    });

    test('BOTH keeps the whole page visible', () {
      final double scale = fitScaleForPolicy(
        policy: FitPolicy.BOTH,
        viewWidth: viewW,
        viewHeight: viewH,
        pageWidth: pageW,
        pageHeight: pageH,
      );
      expect(scale, closeTo(math.min(viewW / pageW, viewH / pageH), 1e-9));
      expect(pageW * scale, lessThanOrEqualTo(viewW + 1e-6));
      expect(pageH * scale, lessThanOrEqualTo(viewH + 1e-6));
      // For this portrait page on a tall phone, BOTH == WIDTH.
      expect(scale, closeTo(viewW / pageW, 1e-9));
    });

    test('BOTH is limited by the tighter axis on landscape pages', () {
      // Wide short viewport + landscape page → height is the limiting axis.
      const double wideViewW = 800;
      const double shortViewH = 400;
      const double landscapeW = 792;
      const double landscapeH = 612;
      final double scale = fitScaleForPolicy(
        policy: FitPolicy.BOTH,
        viewWidth: wideViewW,
        viewHeight: shortViewH,
        pageWidth: landscapeW,
        pageHeight: landscapeH,
      );
      expect(scale, closeTo(shortViewH / landscapeH, 1e-9));
      expect(scale, lessThan(wideViewW / landscapeW));
    });

    test('90° page rotation swaps dimensions before scaling (#247)', () {
      final double unrotated = fitScaleForPolicy(
        policy: FitPolicy.WIDTH,
        viewWidth: viewW,
        viewHeight: viewH,
        pageWidth: pageW,
        pageHeight: pageH,
        rotationDegrees: 0,
      );
      final double rotated = fitScaleForPolicy(
        policy: FitPolicy.WIDTH,
        viewWidth: viewW,
        viewHeight: viewH,
        pageWidth: pageW,
        pageHeight: pageH,
        rotationDegrees: 90,
      );
      // After 90°, page width becomes original height.
      expect(rotated, closeTo(viewW / pageH, 1e-9));
      expect(rotated, isNot(closeTo(unrotated, 1e-6)));
    });

    test('270° rotation matches 90°', () {
      final double r90 = fitScaleForPolicy(
        policy: FitPolicy.BOTH,
        viewWidth: viewW,
        viewHeight: viewH,
        pageWidth: pageW,
        pageHeight: pageH,
        rotationDegrees: 90,
      );
      final double r270 = fitScaleForPolicy(
        policy: FitPolicy.BOTH,
        viewWidth: viewW,
        viewHeight: viewH,
        pageWidth: pageW,
        pageHeight: pageH,
        rotationDegrees: 270,
      );
      expect(r270, closeTo(r90, 1e-9));
    });

    test('zero or negative sizes yield 0 (native early-exit)', () {
      expect(
        fitScaleForPolicy(
          policy: FitPolicy.WIDTH,
          viewWidth: 0,
          viewHeight: viewH,
          pageWidth: pageW,
          pageHeight: pageH,
        ),
        0,
      );
      expect(
        fitScaleForPolicy(
          policy: FitPolicy.WIDTH,
          viewWidth: viewW,
          viewHeight: viewH,
          pageWidth: pageW,
          pageHeight: 0,
        ),
        0,
      );
    });

    test('autoSpacing does not appear in the formula', () {
      // Document the #150 invariant: spacing is not an input to fit scale.
      final double a = fitScaleForPolicy(
        policy: FitPolicy.BOTH,
        viewWidth: viewW,
        viewHeight: viewH,
        pageWidth: pageW,
        pageHeight: pageH,
      );
      final double b = fitScaleForPolicy(
        policy: FitPolicy.BOTH,
        viewWidth: viewW,
        viewHeight: viewH,
        pageWidth: pageW,
        pageHeight: pageH,
      );
      expect(a, b);
    });
  });
}
