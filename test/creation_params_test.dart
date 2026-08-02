import 'package:flutter/foundation.dart';
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
  'autoSpacing',
  'pageFling',
  'pageSnap',
  'enableAntialiasing',
  'useBestQuality',
  'enableRenderDuringScale',
  'thumbnailRatio',
  'defaultPage',
  'fitPolicy',
  'preventLinkNavigation',
  'backgroundColor',
  'maxZoom',
  'minZoom',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Creation params of every platform view created during the current test.
  late List<Map<Object?, Object?>> created;

  /// Method calls seen on the per-view channels of those platform views.
  late List<MethodCall> viewCalls;

  /// Ids handed out by `PlatformViewsService` during the current test.
  late List<int> viewIds;

  void installPlatformViewsMock() {
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
            )! as Map<Object?, Object?>,
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

        // Texture id for the (unused) texture based path; harmless otherwise.
        return 0;
      },
    );
  }

  setUp(() {
    created = <Map<Object?, Object?>>[];
    viewCalls = <MethodCall>[];
    viewIds = <int>[];
    installPlatformViewsMock();
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform_views, null);
    for (final int id in viewIds) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(MethodChannel('plugins.endigo.io/pdfview_$id'), null);
    }
    debugDefaultTargetPlatformOverride = null;
  });

  /// Pumps [view] as an iOS platform view and returns its creation params.
  Future<Map<Object?, Object?>> pumpAndCapture(WidgetTester tester, PDFView view) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
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
    });

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
      expect(params['autoSpacing'], isTrue);
      expect(params['pageFling'], isTrue);
      expect(params['pageSnap'], isTrue);
      expect(params['enableAntialiasing'], isTrue);
      expect(params['useBestQuality'], isTrue);
      expect(params['enableRenderDuringScale'], isTrue);
      expect(params['thumbnailRatio'], 0.8);
      expect(params['defaultPage'], 0);
      expect(params['fitPolicy'], 'FitPolicy.WIDTH');
      expect(params['preventLinkNavigation'], isFalse);
      expect(params['maxZoom'], 4.0);
      expect(params['minZoom'], 1.0);
    });

    testWidgets('serializes a fully customised widget', (WidgetTester tester) async {
      final Map<Object?, Object?> params = await pumpAndCapture(
        tester,
        const PDFView(
          filePath: '/docs/demo.pdf',
          enableSwipe: false,
          swipeHorizontal: true,
          showScrollIndicators: true,
          password: 's3cret',
          nightMode: true,
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
      expect(params['nightMode'], isTrue);
      expect(params['autoSpacing'], isFalse);
      expect(params['pageFling'], isFalse);
      expect(params['pageSnap'], isFalse);
      expect(params['enableAntialiasing'], isFalse);
      expect(params['useBestQuality'], isFalse);
      expect(params['enableRenderDuringScale'], isFalse);
      expect(params['thumbnailRatio'], 0.5);
      expect(params['defaultPage'], 3);
      expect(params['fitPolicy'], 'FitPolicy.HEIGHT');
      expect(params['preventLinkNavigation'], isTrue);
      expect(params['backgroundColor'], 0xFF112233);
      expect(params['maxZoom'], 8.0);
      expect(params['minZoom'], 0.5);
    });

    testWidgets('serializes FitPolicy.BOTH', (WidgetTester tester) async {
      final Map<Object?, Object?> params = await pumpAndCapture(
        tester,
        const PDFView(filePath: 'a.pdf', fitPolicy: FitPolicy.BOTH),
      );
      expect(params['fitPolicy'], 'FitPolicy.BOTH');
    });

    testWidgets('serializes backgroundColor as an ARGB32 int', (WidgetTester tester) async {
      final Map<Object?, Object?> params = await pumpAndCapture(
        tester,
        const PDFView(filePath: 'a.pdf', backgroundColor: Color(0x80123456)),
      );
      expect(params['backgroundColor'], 0x80123456);
    });

    testWidgets('passes pdfData through and leaves filePath null', (WidgetTester tester) async {
      final Uint8List bytes = Uint8List.fromList(const <int>[0x25, 0x50, 0x44, 0x46]);
      final Map<Object?, Object?> params = await pumpAndCapture(
        tester,
        PDFView(pdfData: bytes),
      );
      expect(params['filePath'], isNull);
      expect(params['pdfData'], isA<Uint8List>());
      expect(params['pdfData'], bytes);
    });

    testWidgets('android uses the same creation params', (WidgetTester tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: PDFView(filePath: 'android.pdf', nightMode: true)),
        ),
      );
      await tester.pumpAndSettle();

      expect(created, hasLength(1));
      expect(created.single.keys.cast<String>().toSet(), _expectedKeys);
      expect(created.single['filePath'], 'android.pdf');
      expect(created.single['nightMode'], isTrue);
    });
  });

  group('Settings updates over the method channel', () {
    testWidgets('pushes only the changed, updatable settings', (WidgetTester tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
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
              nightMode: true,
              maxZoom: 6.0,
              // Not part of the updatable diff.
              swipeHorizontal: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(created, hasLength(1), reason: 'settings-only change must not remount the view');
      expect(viewCalls.map((MethodCall c) => c.method), <String>['updateSettings']);
      expect(
        viewCalls.single.arguments,
        <String, Object?>{'nightMode': true, 'maxZoom': 6.0},
      );
    });

    testWidgets('sends nothing when no updatable setting changed', (WidgetTester tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
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
    });

    testWidgets('a new document recreates the platform view', (WidgetTester tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
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
    });
  });

  group('Unsupported platform fallback', () {
    testWidgets('renders an explanatory Text instead of a platform view', (
      WidgetTester tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: PDFView(filePath: 'a.pdf')),
        ),
      );
      await tester.pump();

      expect(
        find.text(
          'TargetPlatform.linux is not yet supported by the pdfview_flutter plugin',
        ),
        findsOneWidget,
      );
      expect(created, isEmpty);
    });

    testWidgets('onViewCreated is never called on an unsupported platform', (
      WidgetTester tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
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
    });
  });

  group('onViewCreated', () {
    testWidgets('receives a working controller for the created view', (
      WidgetTester tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
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
      expect(viewCalls.single.arguments, <String, Object?>{'page': 2});
    });
  });
}
