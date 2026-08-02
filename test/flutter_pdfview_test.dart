import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const MethodChannel channel = MethodChannel('plugins.endigo.io/pdfview');

  late PDFView pdfView;

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      switch (methodCall.method) {
        case 'pageCount':
          return 10;
        case 'currentPage':
          return 1;
        case 'setPage':
          return true;
        case 'onRender':
          return 10;
        default:
          return null;
      }
    });

    pdfView = const PDFView(
      filePath: 'test.pdf',
      enableSwipe: true,
      swipeHorizontal: false,
      nightMode: false,
      autoSpacing: true,
      pageFling: true,
      pageSnap: true,
      fitEachPage: true,
      defaultPage: 0,
      fitPolicy: FitPolicy.WIDTH,
      preventLinkNavigation: false,
      maxZoom: 4.0,
      minZoom: 1.0,
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  group('PDFView Widget Tests', () {
    testWidgets('PDFView builds without crashing', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: pdfView,
          ),
        ),
      );
    });

    testWidgets('PDFView with custom background color', (WidgetTester tester) async {
      final customPdfView = PDFView(
        filePath: 'test.pdf',
        backgroundColor: Colors.blue,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: customPdfView,
          ),
        ),
      );
    });

    testWidgets('PDFView with password protection', (WidgetTester tester) async {
      final protectedPdfView = PDFView(
        filePath: 'test.pdf',
        password: 'test123',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: protectedPdfView,
          ),
        ),
      );
    });

    testWidgets('PDFView with onViewCreated callback', (WidgetTester tester) async {
      PDFViewController? controller;
      final pdfViewWithCallback = PDFView(
        filePath: 'test.pdf',
        onViewCreated: (PDFViewController c) {
          controller = c;
        },
      );
      expect(controller, isNull);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: pdfViewWithCallback,
          ),
        ),
      );

      // Wait for the widget to be fully built
      await tester.pumpAndSettle();

      // Verify that the widget was created
      expect(find.byType(PDFView), findsOneWidget);
    });

    testWidgets('PDFView with onRender callback', (WidgetTester tester) async {
      int? pageCount;
      final pdfViewWithCallback = PDFView(
        filePath: 'test.pdf',
        onRender: (int? pages) {
          pageCount = pages;
        },
      );
      expect(pageCount, isNull);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: pdfViewWithCallback,
          ),
        ),
      );

      // Wait for the widget to be fully built
      await tester.pumpAndSettle();

      // Verify that the widget was created
      expect(find.byType(PDFView), findsOneWidget);
    });
  });

  group('PDFView Settings Tests', () {
    test('PDFView with different fit policies', () {
      final widthFit = PDFView(
        filePath: 'test.pdf',
        fitPolicy: FitPolicy.WIDTH,
      );
      expect(widthFit.fitPolicy, FitPolicy.WIDTH);

      final heightFit = PDFView(
        filePath: 'test.pdf',
        fitPolicy: FitPolicy.HEIGHT,
      );
      expect(heightFit.fitPolicy, FitPolicy.HEIGHT);

      final bothFit = PDFView(
        filePath: 'test.pdf',
        fitPolicy: FitPolicy.BOTH,
      );
      expect(bothFit.fitPolicy, FitPolicy.BOTH);
    });

    test('PDFView with different navigation settings', () {
      final customPdfView = PDFView(
        filePath: 'test.pdf',
        enableSwipe: false,
        swipeHorizontal: true,
        pageFling: false,
        pageSnap: false,
      );

      expect(customPdfView.enableSwipe, false);
      expect(customPdfView.swipeHorizontal, true);
      expect(customPdfView.pageFling, false);
      expect(customPdfView.pageSnap, false);
    });
  });

  group('Error Handling Tests', () {
    test('PDFView handles missing file path and pdf data', () {
      expect(
        () => PDFView(
          filePath: null,
          pdfData: null,
        ),
        throwsAssertionError,
      );
    });
  });

  group('Document change / remount (#181)', () {
    testWidgets('PDFView rebuilds when filePath changes', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PDFView(filePath: 'first.pdf'),
          ),
        ),
      );
      expect(find.byType(PDFView), findsOneWidget);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PDFView(filePath: 'second.pdf'),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(PDFView), findsOneWidget);
    });

    testWidgets('PDFView rebuilds when pdfData changes', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PDFView(pdfData: Uint8List.fromList(const [1, 2, 3])),
          ),
        ),
      );
      expect(find.byType(PDFView), findsOneWidget);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PDFView(pdfData: Uint8List.fromList(const [4, 5, 6])),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(PDFView), findsOneWidget);
    });
  });

  group('Zoom validation', () {
    test('rejects invalid maxZoom/minZoom', () {
      expect(
        () => PDFView(filePath: 'test.pdf', maxZoom: 0),
        throwsAssertionError,
      );
      expect(
        () => PDFView(filePath: 'test.pdf', minZoom: 2, maxZoom: 1),
        throwsAssertionError,
      );
    });
  });

  group('thumbnailRatio validation', () {
    test('rejects out-of-range thumbnailRatio', () {
      expect(
        () => PDFView(filePath: 'test.pdf', thumbnailRatio: 0),
        throwsAssertionError,
      );
      expect(
        () => PDFView(filePath: 'test.pdf', thumbnailRatio: -0.5),
        throwsAssertionError,
      );
      expect(
        () => PDFView(filePath: 'test.pdf', thumbnailRatio: 1.5),
        throwsAssertionError,
      );
    });

    test('accepts thumbnailRatio within (0, 1]', () {
      expect(PDFView(filePath: 'test.pdf', thumbnailRatio: 0.5).thumbnailRatio, 0.5);
      expect(PDFView(filePath: 'test.pdf', thumbnailRatio: 1.0).thumbnailRatio, 1.0);
    });
  });
}
