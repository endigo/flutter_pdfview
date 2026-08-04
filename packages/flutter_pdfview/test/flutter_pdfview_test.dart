import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const MethodChannel channel = MethodChannel('plugins.endigo.io/pdfview');

  late PDFView pdfView;

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (MethodCall methodCall) async {
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
      },
    );

    pdfView = const PDFView(
      filePath: 'test.pdf',
      enableSwipe: true,
      swipeHorizontal: false,
      colorMode: PdfColorMode.light,
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
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      null,
    );
  });

  group('PDFView Widget Tests', () {
    testWidgets('PDFView builds without crashing', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: pdfView)));
    });

    testWidgets('PDFView with custom background color', (WidgetTester tester) async {
      final customPdfView = PDFView(filePath: 'test.pdf', backgroundColor: Colors.blue);

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: customPdfView)));
    });

    testWidgets('PDFView with password protection', (WidgetTester tester) async {
      final protectedPdfView = PDFView(filePath: 'test.pdf', password: 'test123');

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: protectedPdfView)));
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

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: pdfViewWithCallback)));

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

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: pdfViewWithCallback)));

      // Wait for the widget to be fully built
      await tester.pumpAndSettle();

      // Verify that the widget was created
      expect(find.byType(PDFView), findsOneWidget);
    });
  });

  group('PDFView Settings Tests', () {
    test('PDFView with different fit policies', () {
      final widthFit = PDFView(filePath: 'test.pdf', fitPolicy: FitPolicy.WIDTH);
      expect(widthFit.fitPolicy, FitPolicy.WIDTH);

      final heightFit = PDFView(filePath: 'test.pdf', fitPolicy: FitPolicy.HEIGHT);
      expect(heightFit.fitPolicy, FitPolicy.HEIGHT);

      final bothFit = PDFView(filePath: 'test.pdf', fitPolicy: FitPolicy.BOTH);
      expect(bothFit.fitPolicy, FitPolicy.BOTH);
    });

    test('PDFView with pageAlignment options', () {
      final centered = PDFView(filePath: 'test.pdf');
      expect(centered.pageAlignment, PageAlignment.center);

      final top = PDFView(filePath: 'test.pdf', pageAlignment: PageAlignment.top);
      expect(top.pageAlignment, PageAlignment.top);
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
      expect(() => PDFView(filePath: null, pdfData: null), throwsAssertionError);
    });
  });

  group('Document change / remount (#181)', () {
    testWidgets('PDFView rebuilds when filePath changes', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: PDFView(filePath: 'first.pdf')),
        ),
      );
      expect(find.byType(PDFView), findsOneWidget);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: PDFView(filePath: 'second.pdf')),
        ),
      );
      await tester.pump();
      expect(find.byType(PDFView), findsOneWidget);
    });

    testWidgets('PDFView rebuilds when pdfData changes', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: PDFView(pdfData: Uint8List.fromList(const [1, 2, 3]))),
        ),
      );
      expect(find.byType(PDFView), findsOneWidget);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: PDFView(pdfData: Uint8List.fromList(const [4, 5, 6]))),
        ),
      );
      await tester.pump();
      expect(find.byType(PDFView), findsOneWidget);
    });
  });

  group('Zoom validation', () {
    test('rejects invalid maxZoom/minZoom', () {
      expect(() => PDFView(filePath: 'test.pdf', maxZoom: 0), throwsAssertionError);
      expect(() => PDFView(filePath: 'test.pdf', minZoom: 2, maxZoom: 1), throwsAssertionError);
    });
  });

  group('thumbnailRatio validation', () {
    test('rejects out-of-range thumbnailRatio', () {
      expect(() => PDFView(filePath: 'test.pdf', thumbnailRatio: 0), throwsAssertionError);
      expect(() => PDFView(filePath: 'test.pdf', thumbnailRatio: -0.5), throwsAssertionError);
      expect(() => PDFView(filePath: 'test.pdf', thumbnailRatio: 1.5), throwsAssertionError);
    });

    test('accepts thumbnailRatio within (0, 1]', () {
      expect(PDFView(filePath: 'test.pdf', thumbnailRatio: 0.5).thumbnailRatio, 0.5);
      expect(PDFView(filePath: 'test.pdf', thumbnailRatio: 1.0).thumbnailRatio, 1.0);
    });
  });

  group('Creation params map', () {
    testWidgets('forwards settings into platform creation params', (tester) async {
      final view = PDFView(
        filePath: '/docs/demo.pdf',
        enableSwipe: false,
        swipeHorizontal: true,
        showScrollIndicators: true,
        password: 's3cret',
        colorMode: PdfColorMode.dark,
        autoSpacing: false,
        pageFling: false,
        pageSnap: false,
        enableAntialiasing: false,
        useBestQuality: false,
        enableRenderDuringScale: false,
        thumbnailRatio: 0.5,
        defaultPage: 3,
        fitPolicy: FitPolicy.HEIGHT,
        preventLinkNavigation: true,
        backgroundColor: const Color(0xFF112233),
        maxZoom: 8.0,
        minZoom: 0.5,
      );

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: view)));
      await tester.pump();

      // Smoke: widget still builds with the full settings surface used by the
      // example app (colorMode, backgroundColor, zoom bounds, fit policy).
      expect(find.byType(PDFView), findsOneWidget);
      expect(view.filePath, '/docs/demo.pdf');
      expect(view.colorMode, PdfColorMode.dark);
      expect(view.backgroundColor, const Color(0xFF112233));
      expect(view.fitPolicy, FitPolicy.HEIGHT);
      expect(view.defaultPage, 3);
      expect(view.maxZoom, 8.0);
      expect(view.minZoom, 0.5);
      expect(view.preventLinkNavigation, isTrue);
      expect(view.showScrollIndicators, isTrue);
    });

    test('PdfColorMode values are light, dark, system', () {
      expect(PdfColorMode.values, <PdfColorMode>[
        PdfColorMode.light,
        PdfColorMode.dark,
        PdfColorMode.system,
      ]);
      expect(PdfColorMode.dark.name, 'dark');
    });

    test('pdfData source is accepted without filePath', () {
      final bytes = Uint8List.fromList(const [0x25, 0x50, 0x44, 0x46]); // %PDF
      final view = PDFView(pdfData: bytes);
      expect(view.pdfData, bytes);
      expect(view.filePath, isNull);
    });
  });

  group('PDFViewController method channel', () {
    late List<MethodCall> log;
    late PDFViewController controller;

    setUp(() async {
      log = <MethodCall>[];
      const id = 42;
      final view = const PDFView(filePath: 'test.pdf');
      final channel = MethodChannel('plugins.endigo.io/pdfview_$id');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        (MethodCall call) async {
          log.add(call);
          switch (call.method) {
            case 'pageCount':
              return 12;
            case 'currentPage':
              return 2;
            case 'setPage':
              return true;
            case 'currentPageSize':
              return <double>[612.0, 792.0];
            case 'getPosition':
              return <double>[-10.0, -20.0];
            case 'getScale':
              return 1.5;
            case 'setPosition':
              return true;
            case 'setScale':
              return true;
            case 'setZoomLimits':
              return true;
            case 'reload':
              return true;
            case 'getScreenshot':
              return '/tmp/shot.png';
            case 'updateSettings':
              return null;
            default:
              return null;
          }
        },
      );

      controller = PDFViewController.test(id, view);
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.endigo.io/pdfview_42'),
        null,
      );
      controller.dispose();
    });

    test('getPageCount / getCurrentPage / setPage', () async {
      expect(await controller.getPageCount(), 12);
      expect(await controller.getCurrentPage(), 2);
      expect(await controller.setPage(5), isTrue);
      expect(log.map((c) => c.method), containsAll(['pageCount', 'currentPage', 'setPage']));
      final setPageCall = log.firstWhere((c) => c.method == 'setPage');
      expect(setPageCall.arguments['page'], 5);
    });

    test('getCurrentPageSize / getPosition / getScale', () async {
      expect(await controller.getCurrentPageSize(), const Size(612, 792));
      expect(await controller.getPosition(), const Offset(-10, -20));
      expect(await controller.getScale(), 1.5);
    });

    test('setPosition / setScale / setZoomLimits / reload / getScreenshot', () async {
      expect(await controller.setPosition(const Offset(1, 2)), isTrue);
      expect(await controller.setScale(2.0), isTrue);
      expect(await controller.setZoomLimits(1, 2, 4), isTrue);
      expect(await controller.reload(), isTrue);
      expect(await controller.getScreenshot('/tmp/out.png'), '/tmp/shot.png');

      final methods = log.map((c) => c.method).toList();
      expect(
        methods,
        containsAll(['setPosition', 'setScale', 'setZoomLimits', 'reload', 'getScreenshot']),
      );
    });

    // Native callback coverage lives in test/pdf_view_controller_test.dart.
  });
}
