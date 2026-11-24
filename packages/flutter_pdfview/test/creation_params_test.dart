import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';

/// Every key `_CreationParams.toMap()` is expected to produce.
const Set<String> _expectedKeys = <String>{
  'filePath',
  'pdfData',
  'enableSwipe',
  'swipeHorizontal',
  'showScrollIndicators',
  'password',
  'nightMode',
  'colorMode',
  'autoSpacing',
  'spacing',
  'pageFling',
  'pageSnap',
  'enableAntialiasing',
  'useBestQuality',
  'enableRenderDuringScale',
  'thumbnailRatio',
  'defaultPage',
  'fitPolicy',
  'pageAlignment',
  'preventLinkNavigation',
  'backgroundColor',
  'maxZoom',
  'minZoom',
  'enableTextSelection',
  'enableCopy',
};

/// Runs a body on iOS, where `PDFView` uses the simplest platform view path.
final TargetPlatformVariant _iOS = TargetPlatformVariant.only(TargetPlatform.iOS);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Creation params of every platform view created during the current test.
  late List<Map<Object?, Object?>> created;

  /// Method calls seen on the per-view channels of those platform views.
  late List<MethodCall> viewCalls;

  /// Ids handed out by `PlatformViewsService` during the current test.
  late List<int> viewIds;

  setUp(() {
    created = <Map<Object?, Object?>>[];
    viewCalls = <MethodCall>[];
    viewIds = <int>[];

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform_views,
      (MethodCall call) async {
        if (call.method != 'create') {
          return null;
        }
        final Map<Object?, Object?> args = call.arguments as Map<Object?, Object?>;
        final int id = args['id']! as int;
        viewIds.add(id);

        final Uint8List? raw = args['params'] as Uint8List?;
        if (raw != null) {
          created.add(
            const StandardMessageCodec().decodeMessage(
                  ByteData.view(raw.buffer, raw.offsetInBytes, raw.lengthInBytes),
                )!
                as Map<Object?, Object?>,
          );
        }

        // Listen in on the channel the controller will use for this view so the
        // `updateSettings` diff can be asserted.
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
          MethodChannel('plugins.endigo.io/pdfview_$id'),
          (MethodCall viewCall) async {
            viewCalls.add(viewCall);
            return null;
          },
        );

        // Texture id for the texture based path; harmless for the others.
        return 0;
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform_views,
      null,
    );
    for (final int id in viewIds) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        MethodChannel('plugins.endigo.io/pdfview_$id'),
        null,
      );
    }
  });

  /// Pumps [view] and returns the creation params of the single platform view.
  Future<Map<Object?, Object?>> pumpAndCapture(WidgetTester tester, PDFView view) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: view)));
    await tester.pumpAndSettle();
    expect(created, hasLength(1));
    return created.single;
  }

  group('Creation params serialization', () {
    testWidgets('carries every documented key', (WidgetTester tester) async {
      final Map<Object?, Object?> params = await pumpAndCapture(
        tester,
        const PDFView(filePath: 'a.pdf'),
      );
      expect(params.keys.cast<String>().toSet(), _expectedKeys);
    }, variant: _iOS);

    testWidgets('serializes the default settings', (WidgetTester tester) async {
      final Map<Object?, Object?> params = await pumpAndCapture(
        tester,
        const PDFView(filePath: 'a.pdf'),
      );

      expect(params['filePath'], 'a.pdf');
      expect(params['pdfData'], isNull);
      expect(params['password'], isNull);
      expect(params['backgroundColor'], isNull);
      expect(params['enableSwipe'], isTrue);
      expect(params['swipeHorizontal'], isFalse);
      expect(params['showScrollIndicators'], isFalse);
      expect(params['nightMode'], isFalse);
      // Default colorMode is system; MaterialApp Theme is light → light.
      expect(params['colorMode'], 'light');
      expect(params['autoSpacing'], isTrue);
      expect(params['spacing'], isNull);
      expect(params['pageFling'], isTrue);
      expect(params['pageSnap'], isTrue);
      expect(params['enableAntialiasing'], isTrue);
      expect(params['useBestQuality'], isTrue);
      expect(params['enableRenderDuringScale'], isTrue);
      expect(params['thumbnailRatio'], 0.8);
      expect(params['defaultPage'], 0);
      expect(params['fitPolicy'], 'FitPolicy.WIDTH');
      expect(params['pageAlignment'], 'PageAlignment.center');
      expect(params['preventLinkNavigation'], isFalse);
      expect(params['maxZoom'], 4.0);
      expect(params['minZoom'], 1.0);
      expect(params['enableTextSelection'], isTrue);
      expect(params['enableCopy'], isTrue);
    }, variant: _iOS);

    testWidgets('serializes a fully customised widget', (WidgetTester tester) async {
      final Map<Object?, Object?> params = await pumpAndCapture(
        tester,
        const PDFView(
          filePath: '/docs/demo.pdf',
          enableSwipe: false,
          swipeHorizontal: true,
          showScrollIndicators: true,
          password: 's3cret',
          colorMode: PdfColorMode.dark,
          autoSpacing: false,
          spacing: 12,
          pageFling: false,
          pageSnap: false,
          enableAntialiasing: false,
          useBestQuality: false,
          enableRenderDuringScale: false,
          thumbnailRatio: 0.5,
          defaultPage: 3,
          fitPolicy: FitPolicy.HEIGHT,
          pageAlignment: PageAlignment.top,
          preventLinkNavigation: true,
          backgroundColor: Color(0xFF112233),
          maxZoom: 8.0,
          minZoom: 0.5,
        ),
      );

      expect(params['filePath'], '/docs/demo.pdf');
      expect(params['password'], 's3cret');
      expect(params['enableSwipe'], isFalse);
      expect(params['swipeHorizontal'], isTrue);
      expect(params['showScrollIndicators'], isTrue);
      expect(params['colorMode'], 'dark');
      expect(params['autoSpacing'], isFalse);
      expect(params['spacing'], 12);
      expect(params['pageFling'], isFalse);
      expect(params['pageSnap'], isFalse);
      expect(params['enableAntialiasing'], isFalse);
      expect(params['useBestQuality'], isFalse);
      expect(params['enableRenderDuringScale'], isFalse);
      expect(params['thumbnailRatio'], 0.5);
      expect(params['defaultPage'], 3);
      expect(params['fitPolicy'], 'FitPolicy.HEIGHT');
      expect(params['pageAlignment'], 'PageAlignment.top');
      expect(params['preventLinkNavigation'], isTrue);
      expect(params['backgroundColor'], 0xFF112233);
      expect(params['maxZoom'], 8.0);
      expect(params['minZoom'], 0.5);
    }, variant: _iOS);

    testWidgets('serializes PageAlignment.center', (WidgetTester tester) async {
      final Map<Object?, Object?> params = await pumpAndCapture(
        tester,
        const PDFView(filePath: 'a.pdf', pageAlignment: PageAlignment.center),
      );
      expect(params['pageAlignment'], 'PageAlignment.center');
    }, variant: _iOS);

    testWidgets('serializes PageAlignment.top', (WidgetTester tester) async {
      final Map<Object?, Object?> params = await pumpAndCapture(
        tester,
        const PDFView(filePath: 'a.pdf', pageAlignment: PageAlignment.top),
      );
      expect(params['pageAlignment'], 'PageAlignment.top');
    }, variant: _iOS);

    testWidgets('serializes FitPolicy.BOTH', (WidgetTester tester) async {
      final Map<Object?, Object?> params = await pumpAndCapture(
        tester,
        const PDFView(filePath: 'a.pdf', fitPolicy: FitPolicy.BOTH),
      );
      expect(params['fitPolicy'], 'FitPolicy.BOTH');
    }, variant: _iOS);

    testWidgets('serializes backgroundColor as an ARGB32 int', (WidgetTester tester) async {
      final Map<Object?, Object?> params = await pumpAndCapture(
        tester,
        const PDFView(filePath: 'a.pdf', backgroundColor: Color(0x80123456)),
      );
      expect(params['backgroundColor'], 0x80123456);
    }, variant: _iOS);

    testWidgets('passes pdfData through and leaves filePath null', (WidgetTester tester) async {
      final Uint8List bytes = Uint8List.fromList(const <int>[0x25, 0x50, 0x44, 0x46]);
      final Map<Object?, Object?> params = await pumpAndCapture(tester, PDFView(pdfData: bytes));
      expect(params['filePath'], isNull);
      expect(params['pdfData'], isA<Uint8List>());
      expect(params['pdfData'], bytes);
    }, variant: _iOS);

    testWidgets(
      'android uses the same creation params',
      (WidgetTester tester) async {
        final Map<Object?, Object?> params = await pumpAndCapture(
          tester,
          const PDFView(filePath: 'android.pdf', colorMode: PdfColorMode.dark),
        );
        expect(params.keys.cast<String>().toSet(), _expectedKeys);
        expect(params['filePath'], 'android.pdf');
        expect(params['colorMode'], 'dark');
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );

    testWidgets('serializes colorMode light and dark by name', (WidgetTester tester) async {
      final Map<Object?, Object?> lightParams = await pumpAndCapture(
        tester,
        const PDFView(filePath: 'a.pdf', colorMode: PdfColorMode.light),
      );
      expect(lightParams['colorMode'], 'light');

      // Remount with a new document so create fires again with dark params.
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PDFView(filePath: 'b.pdf', colorMode: PdfColorMode.dark),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(created, hasLength(2));
      expect(created.last['colorMode'], 'dark');
    }, variant: _iOS);

    testWidgets('deprecated nightMode: true resolves to dark when colorMode is system', (
      WidgetTester tester,
    ) async {
      final Map<Object?, Object?> params = await pumpAndCapture(
        tester,
        // ignore: deprecated_member_use_from_same_package
        const PDFView(filePath: 'a.pdf', nightMode: true),
      );
      expect(params['colorMode'], 'dark');
      expect(params['nightMode'], isTrue);
    }, variant: _iOS);

    testWidgets('explicit colorMode beats deprecated nightMode', (WidgetTester tester) async {
      final Map<Object?, Object?> params = await pumpAndCapture(
        tester,
        // ignore: deprecated_member_use_from_same_package
        const PDFView(filePath: 'a.pdf', colorMode: PdfColorMode.light, nightMode: true),
      );
      expect(params['colorMode'], 'light');
    }, variant: _iOS);

    testWidgets('system colorMode resolves from ambient Theme brightness', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          darkTheme: ThemeData.dark(),
          themeMode: ThemeMode.dark,
          home: const Scaffold(body: PDFView(filePath: 'a.pdf')),
        ),
      );
      await tester.pumpAndSettle();
      expect(created, hasLength(1));
      expect(created.single['colorMode'], 'dark');
    }, variant: _iOS);
  });

  group('Settings updates over the method channel', () {
    testWidgets('pushes only the changed, updatable settings', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: PDFView(filePath: 'a.pdf')),
        ),
      );
      await tester.pumpAndSettle();
      expect(created, hasLength(1));
      viewCalls.clear();

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PDFView(
              filePath: 'a.pdf',
              colorMode: PdfColorMode.dark,
              maxZoom: 6.0,
              backgroundColor: Color(0xFF112233),
              // Not part of the updatable diff.
              swipeHorizontal: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(created, hasLength(1), reason: 'settings-only change must not remount the view');
      expect(viewCalls.map((MethodCall c) => c.method), <String>['updateSettings']);
      expect(viewCalls.single.arguments, <String, Object?>{
        'colorMode': 'dark',
        'maxZoom': 6.0,
        'backgroundColor': 0xFF112233,
      });
    }, variant: _iOS);

    testWidgets('theme brightness change updates colorMode without remounting', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          darkTheme: ThemeData.dark(),
          themeMode: ThemeMode.light,
          home: const Scaffold(body: PDFView(filePath: 'a.pdf')),
        ),
      );
      await tester.pumpAndSettle();
      expect(created, hasLength(1));
      expect(created.single['colorMode'], 'light');
      viewCalls.clear();

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          darkTheme: ThemeData.dark(),
          themeMode: ThemeMode.dark,
          home: const Scaffold(body: PDFView(filePath: 'a.pdf')),
        ),
      );
      await tester.pumpAndSettle();

      expect(created, hasLength(1), reason: 'theme toggle must not remount the platform view');
      final List<MethodCall> updates = viewCalls
          .where((MethodCall c) => c.method == 'updateSettings')
          .toList();
      expect(updates, hasLength(1));
      expect(updates.single.arguments, <String, Object?>{'colorMode': 'dark'});
    }, variant: _iOS);

    testWidgets('sends nothing when no updatable setting changed', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: PDFView(filePath: 'a.pdf', defaultPage: 0)),
        ),
      );
      await tester.pumpAndSettle();
      viewCalls.clear();

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: PDFView(filePath: 'a.pdf', defaultPage: 4)),
        ),
      );
      await tester.pumpAndSettle();

      expect(viewCalls, isEmpty);
    }, variant: _iOS);

    testWidgets('a new document recreates the platform view', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: PDFView(filePath: 'first.pdf')),
        ),
      );
      await tester.pumpAndSettle();
      expect(created, hasLength(1));

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: PDFView(filePath: 'second.pdf')),
        ),
      );
      await tester.pumpAndSettle();

      expect(created, hasLength(2));
      expect(created.first['filePath'], 'first.pdf');
      expect(created.last['filePath'], 'second.pdf');
      expect(
        viewCalls.map((MethodCall c) => c.method),
        isNot(contains('updateSettings')),
        reason: 'a document change remounts instead of diffing settings',
      );
    }, variant: _iOS);
  });

  group('pdfData change detection (#181)', () {
    Future<void> pumpBytes(WidgetTester tester, Uint8List bytes) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: PDFView(pdfData: bytes)),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('equal bytes in a new list do not remount', (WidgetTester tester) async {
      await pumpBytes(tester, Uint8List.fromList(const <int>[1, 2, 3]));
      expect(created, hasLength(1));

      await pumpBytes(tester, Uint8List.fromList(const <int>[1, 2, 3]));
      expect(created, hasLength(1));
    }, variant: _iOS);

    testWidgets('a single differing byte remounts', (WidgetTester tester) async {
      await pumpBytes(tester, Uint8List.fromList(const <int>[1, 2, 3]));
      expect(created, hasLength(1));

      await pumpBytes(tester, Uint8List.fromList(const <int>[1, 2, 4]));
      expect(created, hasLength(2));
      expect(created.last['pdfData'], Uint8List.fromList(const <int>[1, 2, 4]));
    }, variant: _iOS);

    testWidgets('a different length remounts', (WidgetTester tester) async {
      await pumpBytes(tester, Uint8List.fromList(const <int>[1, 2, 3]));
      await pumpBytes(tester, Uint8List.fromList(const <int>[1, 2, 3, 4]));
      expect(created, hasLength(2));
    }, variant: _iOS);

    testWidgets('the identical list instance does not remount', (WidgetTester tester) async {
      final Uint8List bytes = Uint8List.fromList(const <int>[9, 9, 9]);
      await pumpBytes(tester, bytes);
      await pumpBytes(tester, bytes);
      expect(created, hasLength(1));
    }, variant: _iOS);

    testWidgets('switching from pdfData to filePath remounts', (WidgetTester tester) async {
      await pumpBytes(tester, Uint8List.fromList(const <int>[1, 2, 3]));
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: PDFView(filePath: 'a.pdf')),
        ),
      );
      await tester.pumpAndSettle();

      expect(created, hasLength(2));
      expect(created.last['filePath'], 'a.pdf');
      expect(created.last['pdfData'], isNull);
    }, variant: _iOS);
  });

  group('Unsupported platform fallback', () {
    testWidgets(
      'renders an explanatory Text instead of a platform view',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(body: PDFView(filePath: 'a.pdf')),
          ),
        );
        await tester.pump();

        expect(
          find.text('$defaultTargetPlatform is not yet supported by the pdfview_flutter plugin'),
          findsOneWidget,
        );
        expect(created, isEmpty);
      },
      variant: TargetPlatformVariant(<TargetPlatform>{
        TargetPlatform.linux,
        TargetPlatform.windows,
        TargetPlatform.macOS,
        TargetPlatform.fuchsia,
      }),
    );

    testWidgets(
      'onViewCreated is never called on an unsupported platform',
      (WidgetTester tester) async {
        PDFViewController? controller;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: PDFView(
                filePath: 'a.pdf',
                onViewCreated: (PDFViewController c) => controller = c,
              ),
            ),
          ),
        );
        await tester.pump();

        expect(controller, isNull);
        expect(find.textContaining('is not yet supported'), findsOneWidget);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.windows),
    );
  });

  group('onViewCreated', () {
    testWidgets('receives a working controller for the created view', (WidgetTester tester) async {
      PDFViewController? controller;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PDFView(
              filePath: 'a.pdf',
              onViewCreated: (PDFViewController c) => controller = c,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(controller, isNotNull);
      viewCalls.clear();
      await controller!.setPage(2);
      expect(viewCalls.single.method, 'setPage');
      expect(viewCalls.single.arguments, <String, Object?>{'page': 2, 'withAnimation': false});
    }, variant: _iOS);
  });
}
