import 'dart:ui' show Color;

import 'package:flutter_pdfview_platform_interface/flutter_pdfview_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PdfViewSettings.toMap', () {
    test('serializes every setting under its wire-format key', () {
      final PdfViewSettings settings = PdfViewSettings(
        enableSwipe: true,
        swipeHorizontal: false,
        showScrollIndicators: true,
        password: 'hunter2',
        nightMode: false,
        colorMode: PdfColorMode.dark,
        autoSpacing: true,
        spacing: 12,
        pageFling: false,
        pageSnap: true,
        enableAntialiasing: false,
        useBestQuality: true,
        enableRenderDuringScale: false,
        thumbnailRatio: 0.8,
        defaultPage: 3,
        fitPolicy: FitPolicy.BOTH,
        pageAlignment: PageAlignment.top,
        preventLinkNavigation: true,
        backgroundColor: const Color(0xFF102030),
        maxZoom: 4,
        minZoom: 1,
        enableTextSelection: false,
        enableCopy: false,
      );

      expect(settings.toMap(), <String, dynamic>{
        'enableSwipe': true,
        'swipeHorizontal': false,
        'showScrollIndicators': true,
        'password': 'hunter2',
        'nightMode': false,
        'colorMode': 'dark',
        'autoSpacing': true,
        'spacing': 12,
        'pageFling': false,
        'pageSnap': true,
        'enableAntialiasing': false,
        'useBestQuality': true,
        'enableRenderDuringScale': false,
        'thumbnailRatio': 0.8,
        'defaultPage': 3,
        'fitPolicy': 'FitPolicy.BOTH',
        'pageAlignment': 'PageAlignment.top',
        'preventLinkNavigation': true,
        'backgroundColor': 0xFF102030,
        'maxZoom': 4.0,
        'minZoom': 1.0,
        'enableTextSelection': false,
        'enableCopy': false,
      });
    });

    test('rejects an unresolved system color mode', () {
      expect(() => PdfViewSettings(colorMode: PdfColorMode.system), throwsA(isA<AssertionError>()));
    });
  });

  group('PdfViewSettings.updatesMap', () {
    test('is empty when nothing changed', () {
      final PdfViewSettings a = PdfViewSettings(enableSwipe: true, minZoom: 1);
      final PdfViewSettings b = PdfViewSettings(enableSwipe: true, minZoom: 1);
      expect(a.updatesMap(b), isEmpty);
    });

    test('reports only the settings that actually differ', () {
      final PdfViewSettings a = PdfViewSettings(enableSwipe: true, pageFling: true, maxZoom: 4);
      final PdfViewSettings b = PdfViewSettings(enableSwipe: false, pageFling: true, maxZoom: 4);
      expect(a.updatesMap(b), <String, dynamic>{'enableSwipe': false});
    });

    test('omits settings the native side cannot update in place', () {
      // swipeHorizontal, defaultPage, fitPolicy, autoSpacing and spacing are
      // creation-time only.
      final PdfViewSettings a = PdfViewSettings(
        swipeHorizontal: false,
        defaultPage: 0,
        fitPolicy: FitPolicy.WIDTH,
        autoSpacing: true,
        spacing: 0,
      );
      final PdfViewSettings b = PdfViewSettings(
        swipeHorizontal: true,
        defaultPage: 7,
        fitPolicy: FitPolicy.HEIGHT,
        autoSpacing: false,
        spacing: 16,
      );
      expect(a.updatesMap(b), isEmpty);
    });

    test('serializes a changed color mode by name', () {
      final PdfViewSettings a = PdfViewSettings(colorMode: PdfColorMode.light);
      final PdfViewSettings b = PdfViewSettings(colorMode: PdfColorMode.dark);
      expect(a.updatesMap(b), <String, dynamic>{'colorMode': 'dark'});
    });

    test('sends a new background color as ARGB32', () {
      final PdfViewSettings a = PdfViewSettings(backgroundColor: const Color(0xFF000000));
      final PdfViewSettings b = PdfViewSettings(backgroundColor: const Color(0xFF112233));
      expect(a.updatesMap(b), <String, dynamic>{'backgroundColor': 0xFF112233});
    });

    test('omits a background color cleared back to null', () {
      // Natives keep the previous color; sending null would leave it on screen
      // anyway, so the key is deliberately absent rather than present-with-null.
      final PdfViewSettings a = PdfViewSettings(backgroundColor: const Color(0xFF112233));
      final PdfViewSettings b = PdfViewSettings();
      expect(a.updatesMap(b), isEmpty);
    });
  });

  group('PdfViewCreationParams', () {
    test('merges the document source with the settings', () {
      final PdfViewCreationParams params = PdfViewCreationParams(
        filePath: '/tmp/demo.pdf',
        settings: PdfViewSettings(defaultPage: 2, colorMode: PdfColorMode.light),
      );

      final Map<String, dynamic> map = params.toMap();
      expect(map['filePath'], '/tmp/demo.pdf');
      expect(map['pdfData'], isNull);
      expect(map['defaultPage'], 2);
      expect(map['colorMode'], 'light');
    });
  });
}
