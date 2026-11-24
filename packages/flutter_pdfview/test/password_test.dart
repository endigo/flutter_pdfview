// The Dart half of the password contract: what reaches the platform when a
// password changes, and what `onPasswordRequired` turns into.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:flutter_test/flutter_test.dart';

const int _viewId = 7274;
const String _channelName = 'plugins.endigo.io/pdfview_$_viewId';
const MethodChannel _channel = MethodChannel(_channelName);
const StandardMethodCodec _codec = StandardMethodCodec();

/// Runs a body on iOS, where `PDFView` uses the simplest platform view path.
final TargetPlatformVariant _iOS = TargetPlatformVariant.only(TargetPlatform.iOS);

void _mock(Future<Object?>? Function(MethodCall call)? handler) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
    _channel,
    handler,
  );
}

/// Pushes [call] into Dart the way the native side does.
Future<void> _emit(MethodCall call) {
  return TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
    _channelName,
    _codec.encodeMethodCall(call),
    (ByteData? _) {},
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PDFViewController.unlock', () {
    late List<MethodCall> log;
    late PDFViewController controller;

    setUp(() {
      log = <MethodCall>[];
      controller = PDFViewController.test(_viewId, const PDFView(filePath: 'locked.pdf'));
    });

    tearDown(() {
      _mock(null);
      controller.dispose();
    });

    test('sends {password} and returns the native verdict', () async {
      _mock((MethodCall call) async {
        log.add(call);
        return true;
      });

      expect(await controller.unlock('hunter2'), isTrue);
      expect(log.single.method, 'unlock');
      expect(log.single.arguments, <String, Object?>{'password': 'hunter2'});
    });

    test('returns false when the native side rejects the password', () async {
      _mock((MethodCall call) async => false);
      expect(await controller.unlock('wrong'), isFalse);
    });

    test('falls back to false when the platform answers null', () async {
      _mock((MethodCall call) async => null);
      expect(await controller.unlock('hunter2'), isFalse);
    });

    test('forwards an empty password rather than dropping the call', () async {
      _mock((MethodCall call) async {
        log.add(call);
        return false;
      });

      expect(await controller.unlock(''), isFalse);
      expect(log.single.arguments, <String, Object?>{'password': ''});
    });

    test('propagates a platform exception instead of swallowing it', () async {
      _mock((MethodCall call) async {
        throw PlatformException(code: 'INVALID_ARGS', message: 'password is required');
      });

      await expectLater(controller.unlock('hunter2'), throwsA(isA<PlatformException>()));
    });
  });

  group('onPasswordRequired decoding', () {
    late List<PDFPasswordFailure> failures;
    late PDFViewController controller;

    setUp(() {
      failures = <PDFPasswordFailure>[];
      controller = PDFViewController.test(
        _viewId,
        PDFView(
          filePath: 'locked.pdf',
          onPasswordRequired: (PDFPasswordFailure failure) => failures.add(failure),
        ),
      );
    });

    tearDown(() {
      _mock(null);
      controller.dispose();
    });

    test('incorrect: true reports PDFPasswordFailure.incorrect', () async {
      await _emit(const MethodCall('onPasswordRequired', <String, Object?>{'incorrect': true}));
      expect(failures, <PDFPasswordFailure>[PDFPasswordFailure.incorrect]);
    });

    test('incorrect: false reports PDFPasswordFailure.missing', () async {
      await _emit(const MethodCall('onPasswordRequired', <String, Object?>{'incorrect': false}));
      expect(failures, <PDFPasswordFailure>[PDFPasswordFailure.missing]);
    });

    test('a missing flag reports PDFPasswordFailure.missing', () async {
      await _emit(const MethodCall('onPasswordRequired', <String, Object?>{}));
      expect(failures, <PDFPasswordFailure>[PDFPasswordFailure.missing]);
    });

    test('every failed retry is reported, not just the first', () async {
      await _emit(const MethodCall('onPasswordRequired', <String, Object?>{'incorrect': false}));
      await _emit(const MethodCall('onPasswordRequired', <String, Object?>{'incorrect': true}));
      await _emit(const MethodCall('onPasswordRequired', <String, Object?>{'incorrect': true}));
      expect(failures, <PDFPasswordFailure>[
        PDFPasswordFailure.missing,
        PDFPasswordFailure.incorrect,
        PDFPasswordFailure.incorrect,
      ]);
    });

    test('nothing is delivered after the controller is disposed', () async {
      controller.dispose();
      await _emit(const MethodCall('onPasswordRequired', <String, Object?>{'incorrect': true}));
      expect(failures, isEmpty);
    });
  });

  test('a PDFView without onPasswordRequired ignores the callback', () async {
    final PDFViewController controller = PDFViewController.test(
      _viewId,
      const PDFView(filePath: 'locked.pdf'),
    );
    addTearDown(controller.dispose);

    await _emit(const MethodCall('onPasswordRequired', <String, Object?>{'incorrect': true}));
  });

  group('password changes over the method channel', () {
    late List<Map<Object?, Object?>> created;
    late List<MethodCall> viewCalls;
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

          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(MethodChannel('plugins.endigo.io/pdfview_$id'), (
                MethodCall viewCall,
              ) async {
                viewCalls.add(viewCall);
                return null;
              });
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

    Future<void> pumpPassword(WidgetTester tester, String? password) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PDFView(filePath: 'locked.pdf', password: password),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('a new password is pushed without remounting the view', (
      WidgetTester tester,
    ) async {
      await pumpPassword(tester, null);
      expect(created, hasLength(1));
      viewCalls.clear();

      await pumpPassword(tester, 'hunter2');

      expect(created, hasLength(1), reason: 'the document did not change, only the password');
      expect(viewCalls.map((MethodCall c) => c.method), <String>['updateSettings']);
      expect(viewCalls.single.arguments, <String, Object?>{'password': 'hunter2'});
    }, variant: _iOS);

    testWidgets('clearing the password pushes null', (WidgetTester tester) async {
      await pumpPassword(tester, 'hunter2');
      viewCalls.clear();

      await pumpPassword(tester, null);

      expect(viewCalls.single.arguments, <String, Object?>{'password': null});
    }, variant: _iOS);

    testWidgets('an unchanged password sends nothing', (WidgetTester tester) async {
      await pumpPassword(tester, 'hunter2');
      viewCalls.clear();

      await pumpPassword(tester, 'hunter2');

      expect(viewCalls, isEmpty);
    }, variant: _iOS);

    testWidgets('a wrong password can be retried as often as needed', (WidgetTester tester) async {
      await pumpPassword(tester, 'first-try');
      viewCalls.clear();

      await pumpPassword(tester, 'second-try');
      await pumpPassword(tester, 'hunter2');

      expect(created, hasLength(1), reason: 'retries must not recreate the platform view');
      expect(viewCalls.map((MethodCall c) => c.arguments), <Map<String, Object?>>[
        <String, Object?>{'password': 'second-try'},
        <String, Object?>{'password': 'hunter2'},
      ]);
    }, variant: _iOS);

    testWidgets('a new document still remounts, carrying its password', (
      WidgetTester tester,
    ) async {
      await pumpPassword(tester, 'hunter2');
      expect(created, hasLength(1));
      viewCalls.clear();

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PDFView(filePath: 'other.pdf', password: 'hunter2'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(created, hasLength(2));
      expect(created.last['filePath'], 'other.pdf');
      expect(created.last['password'], 'hunter2');
      expect(
        viewCalls.where((MethodCall c) => c.method == 'updateSettings'),
        isEmpty,
        reason: 'a remounted view gets the password through its creation params',
      );
    }, variant: _iOS);
  });
}
