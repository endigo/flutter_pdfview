import 'package:flutter/foundation.dart' show TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';

/// Regression coverage for [#250](https://github.com/endigo/flutter_pdfview/issues/250),
/// [#272](https://github.com/endigo/flutter_pdfview/issues/272) (top alignment) and the
/// Dart side of the setPage placement surface used by
/// [#197](https://github.com/endigo/flutter_pdfview/issues/197).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final TargetPlatformVariant iOS = TargetPlatformVariant.only(TargetPlatform.iOS);

  late List<Map<Object?, Object?>> created;
  late List<int> viewIds;
  late List<MethodCall> viewCalls;

  setUp(() {
    created = <Map<Object?, Object?>>[];
    viewIds = <int>[];
    viewCalls = <MethodCall>[];

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

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
          MethodChannel('plugins.endigo.io/pdfview_$id'),
          (MethodCall viewCall) async {
            viewCalls.add(viewCall);
            return null;
          },
        );
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

  group('PageAlignment API', () {
    test('defaults to center', () {
      const PDFView view = PDFView(filePath: 'a.pdf');
      expect(view.pageAlignment, PageAlignment.center);
    });

    test('accepts top', () {
      const PDFView view = PDFView(filePath: 'a.pdf', pageAlignment: PageAlignment.top);
      expect(view.pageAlignment, PageAlignment.top);
    });

    test('enum toString matches native wire format', () {
      // Native Kotlin/Swift switch on these exact strings.
      expect(PageAlignment.center.toString(), 'PageAlignment.center');
      expect(PageAlignment.top.toString(), 'PageAlignment.top');
    });
  });

  group('PageAlignment creation params', () {
    testWidgets('default serializes PageAlignment.center', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: PDFView(filePath: 'a.pdf')),
        ),
      );
      await tester.pumpAndSettle();
      expect(created, hasLength(1));
      expect(created.single['pageAlignment'], 'PageAlignment.center');
    }, variant: iOS);

    testWidgets('top serializes PageAlignment.top', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PDFView(filePath: 'a.pdf', pageAlignment: PageAlignment.top),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(created, hasLength(1));
      expect(created.single['pageAlignment'], 'PageAlignment.top');
      // Independent of fitPolicy / autoSpacing (#150 style independence).
      expect(created.single['fitPolicy'], 'FitPolicy.WIDTH');
      expect(created.single['autoSpacing'], isTrue);
    }, variant: iOS);

    testWidgets('pageAlignment is independent of fitPolicy and autoSpacing', (
      WidgetTester tester,
    ) async {
      // Remount with a unique document path each time so the platform view is
      // recreated (settings-only changes only send updateSettings).
      var index = 0;
      for (final PageAlignment align in PageAlignment.values) {
        for (final FitPolicy policy in FitPolicy.values) {
          for (final bool autoSpacing in <bool>[true, false]) {
            created.clear();
            final String path = 'doc_${index++}.pdf';
            await tester.pumpWidget(
              MaterialApp(
                home: Scaffold(
                  body: PDFView(
                    filePath: path,
                    pageAlignment: align,
                    fitPolicy: policy,
                    autoSpacing: autoSpacing,
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(created, hasLength(1), reason: 'path=$path');
            expect(
              created.single['pageAlignment'],
              align.toString(),
              reason: 'align=$align policy=$policy autoSpacing=$autoSpacing',
            );
            expect(created.single['fitPolicy'], policy.toString());
            expect(created.single['autoSpacing'], autoSpacing);
          }
        }
      }
    }, variant: iOS);

    testWidgets('changing pageAlignment pushes updateSettings', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PDFView(filePath: 'a.pdf', pageAlignment: PageAlignment.center),
          ),
        ),
      );
      await tester.pumpAndSettle();
      viewCalls.clear();

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PDFView(filePath: 'a.pdf', pageAlignment: PageAlignment.top),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(viewCalls.map((MethodCall c) => c.method), <String>['updateSettings']);
      expect(viewCalls.single.arguments, <String, Object?>{'pageAlignment': 'PageAlignment.top'});
    }, variant: iOS);
  });
}
