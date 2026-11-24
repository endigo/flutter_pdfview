import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';

/// Runs a body on iOS, where `PDFView` uses the simplest platform view path.
final TargetPlatformVariant _iOS = TargetPlatformVariant.only(TargetPlatform.iOS);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Creation params of every platform view created during the current test.
  late List<Map<Object?, Object?>> created;

  /// Method calls seen on the per-view channels of those platform views.
  late List<MethodCall> viewCalls;

  late List<int> viewIds;

  /// When set, native view creation waits for it, so the widget can be rebuilt
  /// while the platform view is still being created.
  Completer<void>? creationGate;

  setUp(() {
    created = <Map<Object?, Object?>>[];
    viewCalls = <MethodCall>[];
    viewIds = <int>[];
    creationGate = null;

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
        await creationGate?.future;
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

  Widget host(PDFView view) => MaterialApp(home: Scaffold(body: view));

  List<MethodCall> updates() =>
      viewCalls.where((MethodCall c) => c.method == 'updateSettings').toList();

  group('settings changed while the native view is being created', () {
    testWidgets('are pushed once the view exists', (WidgetTester tester) async {
      creationGate = Completer<void>();
      await tester.pumpWidget(host(const PDFView(filePath: 'a.pdf')));
      // Rebuilt before native creation finished: the native view still has the
      // creation params of the first build (no password).
      await tester.pumpWidget(host(const PDFView(filePath: 'a.pdf', password: 'secret')));
      expect(created.single['password'], isNull);

      creationGate!.complete();
      await tester.pumpAndSettle();

      expect(created, hasLength(1), reason: 'a settings change must not remount');
      expect(updates(), hasLength(1));
      expect(updates().single.arguments, <String, Object?>{'password': 'secret'});
    }, variant: _iOS);

    testWidgets('send nothing when the widget did not change', (WidgetTester tester) async {
      creationGate = Completer<void>();
      await tester.pumpWidget(host(const PDFView(filePath: 'a.pdf', password: 'secret')));
      await tester.pumpWidget(host(const PDFView(filePath: 'a.pdf', password: 'secret')));
      creationGate!.complete();
      await tester.pumpAndSettle();

      expect(updates(), isEmpty);
    }, variant: _iOS);

    testWidgets('later updates still diff against the pushed state', (WidgetTester tester) async {
      creationGate = Completer<void>();
      await tester.pumpWidget(host(const PDFView(filePath: 'a.pdf')));
      await tester.pumpWidget(host(const PDFView(filePath: 'a.pdf', enableSwipe: false)));
      creationGate!.complete();
      await tester.pumpAndSettle();
      expect(updates().single.arguments, <String, Object?>{'enableSwipe': false});

      await tester.pumpWidget(host(const PDFView(filePath: 'a.pdf', enableSwipe: false)));
      await tester.pumpAndSettle();
      expect(updates(), hasLength(1), reason: 'nothing changed since the push');
    }, variant: _iOS);
  });

  group('pdfData identity', () {
    Uint8List bytes(List<int> values) => Uint8List.fromList(values);

    testWidgets('a new list with equal bytes keeps the view', (WidgetTester tester) async {
      await tester.pumpWidget(host(PDFView(pdfData: bytes(<int>[1, 2, 3, 4]))));
      await tester.pumpAndSettle();
      await tester.pumpWidget(host(PDFView(pdfData: bytes(<int>[1, 2, 3, 4]))));
      await tester.pumpAndSettle();

      expect(created, hasLength(1));
    }, variant: _iOS);

    testWidgets('same length, different bytes reloads', (WidgetTester tester) async {
      await tester.pumpWidget(host(PDFView(pdfData: bytes(<int>[1, 2, 3, 4]))));
      await tester.pumpAndSettle();
      await tester.pumpWidget(host(PDFView(pdfData: bytes(<int>[1, 2, 3, 5]))));
      await tester.pumpAndSettle();

      expect(created, hasLength(2));
    }, variant: _iOS);
  });
}
