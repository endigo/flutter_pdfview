import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_pdfview_platform_interface/flutter_pdfview_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// A conforming implementation: extends the interface, so it carries the token.
class _ExtendsPlatform extends FlutterPdfViewPlatform {}

/// A non-conforming implementation: `implements` without the mock mixin, which
/// the token check must reject.
class _ImplementsPlatform implements FlutterPdfViewPlatform {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// Mocks are allowed to `implements` when they mix in [MockPlatformInterfaceMixin].
class _MockPlatform with MockPlatformInterfaceMixin implements FlutterPdfViewPlatform {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  final FlutterPdfViewPlatform initial = FlutterPdfViewPlatform.instance;

  tearDown(() {
    FlutterPdfViewPlatform.instance = initial;
  });

  group('FlutterPdfViewPlatform.instance', () {
    test('defaults to the method channel implementation', () {
      expect(FlutterPdfViewPlatform.instance, isA<MethodChannelFlutterPdfView>());
    });

    test('accepts an implementation that extends the interface', () {
      final _ExtendsPlatform platform = _ExtendsPlatform();
      FlutterPdfViewPlatform.instance = platform;
      expect(FlutterPdfViewPlatform.instance, same(platform));
    });

    test('accepts a mock that mixes in MockPlatformInterfaceMixin', () {
      final _MockPlatform platform = _MockPlatform();
      FlutterPdfViewPlatform.instance = platform;
      expect(FlutterPdfViewPlatform.instance, same(platform));
    });

    test('rejects an implementation that only implements the interface', () {
      expect(
        () => FlutterPdfViewPlatform.instance = _ImplementsPlatform(),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('default buildView', () {
    test('throws UnimplementedError so subclasses must override it', () {
      expect(
        () => _ExtendsPlatform().buildView(
          creationParams: PdfViewCreationParams(filePath: 'a.pdf', settings: PdfViewSettings()),
          callbacks: const PdfViewCallbacks(),
          onPlatformViewCreated: (PdfViewPlatformController _) {},
        ),
        throwsUnimplementedError,
      );
    });
  });

  group('MethodChannelFlutterPdfView.buildView', () {
    testWidgets(
      'renders an explanatory Text on an unsupported platform',
      (WidgetTester tester) async {
        bool created = false;
        final Widget view = MethodChannelFlutterPdfView().buildView(
          creationParams: PdfViewCreationParams(filePath: 'a.pdf', settings: PdfViewSettings()),
          callbacks: const PdfViewCallbacks(),
          onPlatformViewCreated: (PdfViewPlatformController _) => created = true,
          gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{},
        );

        await tester.pumpWidget(Directionality(textDirection: TextDirection.ltr, child: view));

        expect(find.byType(Text), findsOneWidget);
        expect(
          find.text('$defaultTargetPlatform is not yet supported by the pdfview_flutter plugin'),
          findsOneWidget,
        );
        expect(created, isFalse);
      },
      variant: const TargetPlatformVariant(<TargetPlatform>{
        TargetPlatform.linux,
        TargetPlatform.windows,
        TargetPlatform.macOS,
        TargetPlatform.fuchsia,
      }),
    );
  });
}
