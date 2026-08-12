import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';

/// Regression coverage for
/// https://github.com/endigo/flutter_pdfview/issues/150
///
/// Native iOS used to couple `autoSpacing` to initial fit/zoom. Dart must keep
/// sending both flags independently so each platform can treat spacing and fit
/// as separate concerns. These tests lock that creation-param contract for iOS
/// and Android.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<Map<Object?, Object?>> created;

  setUp(() {
    created = <Map<Object?, Object?>>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform_views,
      (MethodCall call) async {
        if (call.method != 'create') {
          return null;
        }
        final Map<Object?, Object?> args = call.arguments as Map<Object?, Object?>;
        final Uint8List? raw = args['params'] as Uint8List?;
        if (raw != null) {
          created.add(
            const StandardMessageCodec().decodeMessage(
                  ByteData.view(raw.buffer, raw.offsetInBytes, raw.lengthInBytes),
                )!
                as Map<Object?, Object?>,
          );
        }
        return 0;
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform_views,
      null,
    );
  });

  Future<Map<Object?, Object?>> pumpAndCapture(WidgetTester tester, PDFView view) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: view)));
    await tester.pumpAndSettle();
    expect(created, hasLength(1));
    return created.single;
  }

  /// The exact configuration from the #150 report.
  const PDFView issue150Config = PDFView(
    filePath: 'widget.pdf',
    enableSwipe: true,
    swipeHorizontal: false,
    autoSpacing: false,
    pageFling: true,
    pageSnap: true,
    defaultPage: 0,
    fitPolicy: FitPolicy.BOTH,
    preventLinkNavigation: false,
  );

  group('Issue #150 creation params (iOS)', () {
    testWidgets(
      'reporter config keeps autoSpacing false and FitPolicy.BOTH',
      (WidgetTester tester) async {
        final Map<Object?, Object?> params = await pumpAndCapture(tester, issue150Config);

        expect(params['autoSpacing'], isFalse, reason: 'spacing must not be forced true for fit');
        expect(params['fitPolicy'], 'FitPolicy.BOTH');
        expect(params['swipeHorizontal'], isFalse);
        expect(params['enableSwipe'], isTrue);
        expect(params['pageFling'], isTrue);
        expect(params['pageSnap'], isTrue);
        expect(params['defaultPage'], 0);
        expect(params['preventLinkNavigation'], isFalse);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );

    testWidgets(
      'autoSpacing and fitPolicy serialize independently',
      (WidgetTester tester) async {
        for (final bool autoSpacing in <bool>[true, false]) {
          for (final FitPolicy policy in FitPolicy.values) {
            // Tear down the previous platform view so the next create is recorded
            // (settings-only rebuilds would not remount).
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pumpAndSettle();
            created.clear();

            final Map<Object?, Object?> params = await pumpAndCapture(
              tester,
              PDFView(filePath: 'a.pdf', autoSpacing: autoSpacing, fitPolicy: policy),
            );
            expect(
              params['autoSpacing'],
              autoSpacing,
              reason: 'autoSpacing=$autoSpacing with $policy must pass through',
            );
            expect(
              params['fitPolicy'],
              policy.toString(),
              reason: 'fitPolicy=$policy with autoSpacing=$autoSpacing must pass through',
            );
          }
        }
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );

    testWidgets(
      'default still ships FitPolicy.WIDTH with autoSpacing true',
      (WidgetTester tester) async {
        final Map<Object?, Object?> params = await pumpAndCapture(
          tester,
          const PDFView(filePath: 'a.pdf'),
        );
        // Defaults match Android so iOS no longer silently "fits both".
        expect(params['fitPolicy'], 'FitPolicy.WIDTH');
        expect(params['autoSpacing'], isTrue);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );
  });

  group('Issue #150 creation params (Android)', () {
    testWidgets(
      'reporter config matches iOS serialization',
      (WidgetTester tester) async {
        final Map<Object?, Object?> params = await pumpAndCapture(tester, issue150Config);

        expect(params['autoSpacing'], isFalse);
        expect(params['fitPolicy'], 'FitPolicy.BOTH');
        expect(params['enableSwipe'], isTrue);
        expect(params['swipeHorizontal'], isFalse);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );

    testWidgets(
      'autoSpacing false does not drop fitPolicy',
      (WidgetTester tester) async {
        final Map<Object?, Object?> params = await pumpAndCapture(
          tester,
          const PDFView(filePath: 'a.pdf', autoSpacing: false, fitPolicy: FitPolicy.WIDTH),
        );
        expect(params.containsKey('autoSpacing'), isTrue);
        expect(params.containsKey('fitPolicy'), isTrue);
        expect(params['autoSpacing'], isFalse);
        expect(params['fitPolicy'], 'FitPolicy.WIDTH');
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );
  });

  group('Issue #150 FitPolicy enum contract', () {
    test('toString values match native string parsers', () {
      // Android FlutterPDFView.getFitPolicy and iOS fitPolicyFromArguments
      // switch on these exact strings.
      expect(FitPolicy.WIDTH.toString(), 'FitPolicy.WIDTH');
      expect(FitPolicy.HEIGHT.toString(), 'FitPolicy.HEIGHT');
      expect(FitPolicy.BOTH.toString(), 'FitPolicy.BOTH');
    });

    test('all policies are covered', () {
      expect(FitPolicy.values, hasLength(3));
      expect(FitPolicy.values.map((FitPolicy p) => p.name).toSet(), <String>{
        'WIDTH',
        'HEIGHT',
        'BOTH',
      });
    });
  });
}
