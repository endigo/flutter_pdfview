// End-to-end coverage for the text layer, driving the real native viewers:
// PDFKit on iOS and AndroidPdfViewer on Android.
//
//   cd example && flutter test integration_test/text_layer_test.dart
//
// The fixture has known text on known pages; see scripts/make_text_pdf.py.
// Every assertion here is deliberately platform-aware: iOS has a text layer,
// Android does not, and the point of these tests is that the difference is
// reported honestly rather than as "no matches found".
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

/// Appears once on page 0 and twice on page 2 of the fixture.
const String searchTerm = 'searchable';

/// Appears exactly once, on page 1.
const String singleMatchTerm = 'Gamma';

const int textPageCount = 3;

Future<File> copyAsset(String asset, String fileName) async {
  final Directory dir = await getApplicationDocumentsDirectory();
  final File file = File('${dir.path}/$fileName');
  final ByteData data = await rootBundle.load(asset);
  await file.writeAsBytes(data.buffer.asUint8List(), flush: true);
  return file;
}

Future<bool> waitFor(
  WidgetTester tester,
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  final DateTime deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    if (condition()) return true;
    await tester.pump(const Duration(milliseconds: 100));
  }
  return condition();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late File textPdf;

  setUpAll(() async {
    textPdf = await copyAsset('assets/demo-text.pdf', 'demo-text.pdf');
  });

  /// Mounts the fixture and returns its controller once the document rendered.
  Future<PDFViewController> pumpViewer(
    WidgetTester tester, {
    bool enableTextSelection = true,
    bool enableCopy = true,
    List<int>? searchIndices,
    List<int>? searchTotals,
  }) async {
    PDFViewController? controller;
    int? rendered;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 600,
            child: PDFView(
              filePath: textPdf.path,
              enableTextSelection: enableTextSelection,
              enableCopy: enableCopy,
              onViewCreated: (PDFViewController c) => controller = c,
              onRender: (int? pages) => rendered = pages,
              onSearchResultChanged: (int index, int total) {
                searchIndices?.add(index);
                searchTotals?.add(total);
              },
            ),
          ),
        ),
      ),
    );

    final bool ready = await waitFor(tester, () => controller != null && rendered != null);
    expect(ready, isTrue, reason: 'the document never rendered');
    expect(rendered, textPageCount);
    return controller!;
  }

  testWidgets('reports whether this platform has a text layer', (WidgetTester tester) async {
    final PDFViewController controller = await pumpViewer(tester);
    final bool supported = await controller.isTextLayerSupported();

    // This is the contract the rest of the suite branches on, so pin it per
    // platform rather than accepting whatever the native side happens to say.
    expect(supported, Platform.isIOS);
  });

  group('search', () {
    testWidgets('finds every match with its page index', (WidgetTester tester) async {
      final PDFViewController controller = await pumpViewer(tester);
      if (!await controller.isTextLayerSupported()) return;

      final List<PdfTextMatch> matches = await controller.searchText(searchTerm);

      expect(matches.length, 3);
      expect(matches.map((PdfTextMatch m) => m.pageIndex), <int>[0, 2, 2]);
      expect(matches.map((PdfTextMatch m) => m.matchIndex), <int>[0, 1, 2]);
    });

    testWidgets('a term that is absent returns no matches', (WidgetTester tester) async {
      final PDFViewController controller = await pumpViewer(tester);
      if (!await controller.isTextLayerSupported()) return;

      // Empty here means "searched, found nothing" — the platform that cannot
      // search at all throws instead, which the Android test below asserts.
      expect(await controller.searchText('Zeta-not-present'), isEmpty);
    });

    testWidgets('search is case-insensitive by default', (WidgetTester tester) async {
      final PDFViewController controller = await pumpViewer(tester);
      if (!await controller.isTextLayerSupported()) return;

      expect(await controller.searchText(searchTerm.toUpperCase()), hasLength(3));
      expect(await controller.searchText(searchTerm.toUpperCase(), caseSensitive: true), isEmpty);
    });

    testWidgets('an empty query clears the session', (WidgetTester tester) async {
      final PDFViewController controller = await pumpViewer(tester);
      if (!await controller.isTextLayerSupported()) return;

      await controller.searchText(searchTerm);
      expect(await controller.searchText(''), isEmpty);
      expect(await controller.nextMatch(), isNull, reason: 'the session should be gone');
    });

    testWidgets('navigation wraps in both directions', (WidgetTester tester) async {
      final PDFViewController controller = await pumpViewer(tester);
      if (!await controller.isTextLayerSupported()) return;

      await controller.searchText(searchTerm); // activates match 0
      expect((await controller.nextMatch())?.matchIndex, 1);
      expect((await controller.nextMatch())?.matchIndex, 2);
      expect((await controller.nextMatch())?.matchIndex, 0, reason: 'should wrap forward');
      expect((await controller.previousMatch())?.matchIndex, 2, reason: 'should wrap back');
    });

    testWidgets('setCurrentMatch activates a match and rejects a bad index', (
      WidgetTester tester,
    ) async {
      final PDFViewController controller = await pumpViewer(tester);
      if (!await controller.isTextLayerSupported()) return;

      await controller.searchText(searchTerm);
      expect((await controller.setCurrentMatch(2))?.pageIndex, 2);
      expect(await controller.setCurrentMatch(99), isNull);
      expect(await controller.setCurrentMatch(-1), isNull);
    });

    testWidgets('navigating a single-match term stays on that match', (WidgetTester tester) async {
      final PDFViewController controller = await pumpViewer(tester);
      if (!await controller.isTextLayerSupported()) return;

      final List<PdfTextMatch> matches = await controller.searchText(singleMatchTerm);
      expect(matches, hasLength(1));
      expect(matches.single.pageIndex, 1);
      expect((await controller.nextMatch())?.matchIndex, 0);
    });

    testWidgets('onSearchResultChanged tracks the active match', (WidgetTester tester) async {
      final List<int> indices = <int>[];
      final List<int> totals = <int>[];
      final PDFViewController controller = await pumpViewer(
        tester,
        searchIndices: indices,
        searchTotals: totals,
      );
      if (!await controller.isTextLayerSupported()) return;

      await controller.searchText(searchTerm);
      await waitFor(tester, () => indices.isNotEmpty);
      expect(indices.last, 0);
      expect(totals.last, 3);

      await controller.nextMatch();
      await waitFor(tester, () => indices.last == 1);
      expect(indices.last, 1);

      await controller.clearSearch();
      await waitFor(tester, () => indices.last == -1);
      expect(indices.last, -1);
      expect(totals.last, 0);
    });
  });

  group('selection', () {
    testWidgets('nothing is selected on a freshly opened document', (WidgetTester tester) async {
      final PDFViewController controller = await pumpViewer(tester);
      if (!await controller.isTextLayerSupported()) return;

      expect(await controller.getSelectedText(), isNull);
    });

    testWidgets('clearSelection is safe with no selection', (WidgetTester tester) async {
      final PDFViewController controller = await pumpViewer(tester);
      await expectLater(controller.clearSelection(), completes);
    });

    testWidgets('a viewer built with selection disabled still renders and searches', (
      WidgetTester tester,
    ) async {
      // #108: disabling selection must not cost the document its text layer.
      final PDFViewController controller = await pumpViewer(
        tester,
        enableTextSelection: false,
        enableCopy: false,
      );
      if (!await controller.isTextLayerSupported()) return;

      expect(await controller.searchText(searchTerm), hasLength(3));
      expect(await controller.getSelectedText(), isNull);
    });
  });

  group('platform without a text layer', () {
    testWidgets('text queries throw instead of reporting nothing found', (
      WidgetTester tester,
    ) async {
      final PDFViewController controller = await pumpViewer(tester);
      if (await controller.isTextLayerSupported()) return;

      // The regression this guards: returning [] / null here would read as
      // "this document has no matches" and silently ship broken search.
      await expectLater(controller.searchText(searchTerm), throwsUnsupportedError);
      await expectLater(controller.getSelectedText(), throwsUnsupportedError);
      await expectLater(controller.nextMatch(), throwsUnsupportedError);
      await expectLater(controller.previousMatch(), throwsUnsupportedError);
      await expectLater(controller.setCurrentMatch(0), throwsUnsupportedError);
    });

    testWidgets('clearing stays a no-op', (WidgetTester tester) async {
      final PDFViewController controller = await pumpViewer(tester);
      if (await controller.isTextLayerSupported()) return;

      await expectLater(controller.clearSearch(), completes);
      await expectLater(controller.clearSelection(), completes);
    });
  });
}
