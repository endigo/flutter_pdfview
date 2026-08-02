import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';

const int _viewId = 7001;
const String _channelName = 'plugins.endigo.io/pdfview_$_viewId';
const MethodChannel _channel = MethodChannel(_channelName);
const StandardMethodCodec _codec = StandardMethodCodec();

/// Installs (or clears, when [handler] is null) the mock platform side of the
/// controller's per-view method channel.
void _mock(Future<Object?>? Function(MethodCall call)? handler) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_channel, handler);
}

/// Pushes [call] into Dart the way the native side does.
Future<void> _emit(MethodCall call, {String channel = _channelName}) {
  return TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .handlePlatformMessage(channel, _codec.encodeMethodCall(call), (ByteData? _) {});
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PDFViewController arguments and decoding', () {
    late List<MethodCall> log;
    late Map<String, Object?> responses;
    late PDFViewController controller;

    setUp(() {
      log = <MethodCall>[];
      responses = <String, Object?>{
        'pageCount': 12,
        'currentPage': 2,
        'setPage': true,
        'currentPageSize': <double>[612.0, 792.0],
        'getPosition': <double>[-10.0, -20.0],
        'getScale': 1.5,
        'setPosition': true,
        'setScale': true,
        'setZoomLimits': true,
        'reload': true,
        'getScreenshot': '/tmp/shot.png',
      };
      _mock((MethodCall call) async {
        log.add(call);
        return responses[call.method];
      });
      controller = PDFViewController.test(_viewId, const PDFView(filePath: 'test.pdf'));
    });

    tearDown(() {
      _mock(null);
      controller.dispose();
    });

    test('getPageCount forwards no arguments and returns the native value', () async {
      expect(await controller.getPageCount(), 12);
      expect(log.single.method, 'pageCount');
      expect(log.single.arguments, isNull);
    });

    test('getCurrentPage forwards no arguments and returns the native value', () async {
      expect(await controller.getCurrentPage(), 2);
      expect(log.single.method, 'currentPage');
      expect(log.single.arguments, isNull);
    });

    test('setPage sends {page: n}', () async {
      expect(await controller.setPage(5), isTrue);
      expect(log.single.method, 'setPage');
      expect(log.single.arguments, <String, Object?>{'page': 5});
    });

    test('getCurrentPageSize decodes [width, height] into a Size', () async {
      expect(await controller.getCurrentPageSize(), const Size(612, 792));
      expect(log.single.method, 'currentPageSize');
      expect(log.single.arguments, isNull);
    });

    test('getPosition decodes [dx, dy] into an Offset', () async {
      expect(await controller.getPosition(), const Offset(-10, -20));
      expect(log.single.method, 'getPosition');
    });

    test('getScale returns the native scale', () async {
      expect(await controller.getScale(), 1.5);
      expect(log.single.method, 'getScale');
    });

    test('setPosition sends {xPos, yPos}', () async {
      expect(await controller.setPosition(const Offset(1.5, -2.5)), isTrue);
      expect(log.single.method, 'setPosition');
      expect(log.single.arguments, <String, Object?>{'xPos': 1.5, 'yPos': -2.5});
    });

    test('setScale sends {scale}', () async {
      expect(await controller.setScale(2.25), isTrue);
      expect(log.single.method, 'setScale');
      expect(log.single.arguments, <String, Object?>{'scale': 2.25});
    });

    test('setZoomLimits sends {minZoom, midZoom, maxZoom}', () async {
      expect(await controller.setZoomLimits(1, 2, 4), isTrue);
      expect(log.single.method, 'setZoomLimits');
      expect(
        log.single.arguments,
        <String, Object?>{'minZoom': 1.0, 'midZoom': 2.0, 'maxZoom': 4.0},
      );
    });

    test('getScreenshot sends {fileName} and returns the native path', () async {
      expect(await controller.getScreenshot('/tmp/out.png'), '/tmp/shot.png');
      expect(log.single.method, 'getScreenshot');
      expect(log.single.arguments, <String, Object?>{'fileName': '/tmp/out.png'});
    });

    test('reload forwards no arguments', () async {
      expect(await controller.reload(), isTrue);
      expect(log.single.method, 'reload');
      expect(log.single.arguments, isNull);
    });
  });

  group('PDFViewController null fallbacks', () {
    late PDFViewController controller;

    setUp(() {
      _mock((MethodCall call) async {
        if (call.method == 'currentPageSize' || call.method == 'getPosition') {
          return <double?>[null, null];
        }
        return null;
      });
      controller = PDFViewController.test(_viewId, const PDFView(filePath: 'test.pdf'));
    });

    tearDown(() {
      _mock(null);
      controller.dispose();
    });

    test('getCurrentPageSize falls back to zeros', () async {
      expect(await controller.getCurrentPageSize(), Size.zero);
    });

    test('getPosition falls back to zeros', () async {
      expect(await controller.getPosition(), Offset.zero);
    });

    test('getScale falls back to 1', () async {
      expect(await controller.getScale(), 1);
    });

    test('setZoomLimits falls back to false', () async {
      expect(await controller.setZoomLimits(1, 2, 4), isFalse);
    });

    test('getScreenshot falls back to an empty string', () async {
      expect(await controller.getScreenshot('/tmp/out.png'), '');
    });

    test('reload falls back to false', () async {
      expect(await controller.reload(), isFalse);
    });

    test('getPageCount / getCurrentPage / setPage propagate null', () async {
      expect(await controller.getPageCount(), isNull);
      expect(await controller.getCurrentPage(), isNull);
      expect(await controller.setPage(1), isNull);
    });
  });

  group('PDFViewController deadlock regression', () {
    late PDFViewController controller;

    setUp(() {
      controller = PDFViewController.test(_viewId, const PDFView(filePath: 'test.pdf'));
    });

    tearDown(() {
      _mock(null);
      controller.dispose();
    });

    test('a failing setPosition still releases the guard', () async {
      _mock((MethodCall call) async {
        throw PlatformException(code: 'boom', message: 'native failure');
      });

      await expectLater(
        controller.setPosition(const Offset(1, 2)),
        throwsA(isA<PlatformException>()),
      );

      final List<String> after = <String>[];
      _mock((MethodCall call) async {
        after.add(call.method);
        return call.method == 'getPosition' ? <double>[3.0, 4.0] : true;
      });

      // Both of these hang forever if the guard completer is not released in
      // the `finally` block of setPosition.
      expect(
        await controller.setPosition(const Offset(3, 4)).timeout(const Duration(seconds: 2)),
        isTrue,
      );
      expect(
        await controller.getPosition().timeout(const Duration(seconds: 2)),
        const Offset(3, 4),
      );
      expect(after, <String>['setPosition', 'getPosition']);
    });

    test('a failing setScale still releases the guard', () async {
      _mock((MethodCall call) async {
        throw PlatformException(code: 'boom', message: 'native failure');
      });

      await expectLater(
        controller.setScale(2),
        throwsA(isA<PlatformException>()),
      );

      final List<String> after = <String>[];
      _mock((MethodCall call) async {
        after.add(call.method);
        return call.method == 'getScale' ? 3.0 : true;
      });

      expect(
        await controller.setScale(3).timeout(const Duration(seconds: 2)),
        isTrue,
      );
      expect(
        await controller.getScale().timeout(const Duration(seconds: 2)),
        3.0,
      );
      expect(after, <String>['setScale', 'getScale']);
    });
  });

  group('PDFViewController call serialization', () {
    late PDFViewController controller;

    setUp(() {
      controller = PDFViewController.test(_viewId, const PDFView(filePath: 'test.pdf'));
    });

    tearDown(() {
      _mock(null);
      controller.dispose();
    });

    test('a second setPosition only reaches the platform after the first settles', () async {
      final List<String> order = <String>[];
      final Completer<void> gate = Completer<void>();
      int calls = 0;

      _mock((MethodCall call) async {
        if (call.method != 'setPosition') {
          return null;
        }
        calls += 1;
        final int index = calls;
        order.add('platform:$index');
        if (index == 1) {
          await gate.future;
        }
        return true;
      });

      final Future<bool> first = controller.setPosition(const Offset(1, 1));
      final Future<bool> second = controller.setPosition(const Offset(2, 2));

      await pumpEventQueue();
      expect(order, <String>['platform:1'], reason: 'the second call must wait');

      order.add('gate-released');
      gate.complete();

      expect(await first.timeout(const Duration(seconds: 2)), isTrue);
      expect(await second.timeout(const Duration(seconds: 2)), isTrue);
      expect(order, <String>['platform:1', 'gate-released', 'platform:2']);
    });

    test('getPosition waits for a pending setPosition', () async {
      final List<String> order = <String>[];
      final Completer<void> gate = Completer<void>();

      _mock((MethodCall call) async {
        order.add(call.method);
        if (call.method == 'setPosition') {
          await gate.future;
          return true;
        }
        return <double>[5.0, 6.0];
      });

      final Future<bool> set = controller.setPosition(const Offset(5, 6));
      final Future<Offset> read = controller.getPosition();

      await pumpEventQueue();
      expect(order, <String>['setPosition']);

      gate.complete();
      expect(await set.timeout(const Duration(seconds: 2)), isTrue);
      expect(await read.timeout(const Duration(seconds: 2)), const Offset(5, 6));
      expect(order, <String>['setPosition', 'getPosition']);
    });

    test('getScale waits for a pending setScale', () async {
      final List<String> order = <String>[];
      final Completer<void> gate = Completer<void>();

      _mock((MethodCall call) async {
        order.add(call.method);
        if (call.method == 'setScale') {
          await gate.future;
          return true;
        }
        return 2.0;
      });

      final Future<bool> set = controller.setScale(2);
      final Future<double> read = controller.getScale();

      await pumpEventQueue();
      expect(order, <String>['setScale']);

      gate.complete();
      expect(await set.timeout(const Duration(seconds: 2)), isTrue);
      expect(await read.timeout(const Duration(seconds: 2)), 2.0);
      expect(order, <String>['setScale', 'getScale']);
    });
  });

  group('PDFViewController native callbacks', () {
    late List<String> events;
    late PDFView view;
    late PDFViewController controller;

    setUp(() {
      events = <String>[];
      view = PDFView(
        filePath: 'test.pdf',
        onRender: (int? pages) => events.add('onRender($pages)'),
        onPageChanged: (int? page, int? total) => events.add('onPageChanged($page,$total)'),
        onError: (dynamic error) => events.add('onError($error)'),
        onPageError: (int? page, dynamic error) => events.add('onPageError($page,$error)'),
        onLinkHandler: (String? uri) => events.add('onLinkHandler($uri)'),
        onLoadComplete: (int? pages) => events.add('onLoadComplete($pages)'),
        onDraw: (double x, double y, double scale) => events.add('onDraw($x,$y,$scale)'),
      );
      controller = PDFViewController.test(_viewId, view);
    });

    tearDown(() {
      controller.dispose();
    });

    test('onRender receives the page count', () async {
      await _emit(const MethodCall('onRender', <String, Object?>{'pages': 7}));
      expect(events, <String>['onRender(7)']);
    });

    test('onRender tolerates a null page count', () async {
      await _emit(const MethodCall('onRender', <String, Object?>{'pages': null}));
      expect(events, <String>['onRender(null)']);
    });

    test('onPageChanged receives page and total', () async {
      await _emit(const MethodCall('onPageChanged', <String, Object?>{'page': 3, 'total': 9}));
      expect(events, <String>['onPageChanged(3,9)']);
    });

    test('onPageChanged tolerates nulls', () async {
      await _emit(
        const MethodCall('onPageChanged', <String, Object?>{'page': null, 'total': null}),
      );
      expect(events, <String>['onPageChanged(null,null)']);
    });

    test('onError receives the error payload', () async {
      await _emit(const MethodCall('onError', <String, Object?>{'error': 'cannot open'}));
      expect(events, <String>['onError(cannot open)']);
    });

    test('onPageError receives page and error', () async {
      await _emit(
        const MethodCall('onPageError', <String, Object?>{'page': 4, 'error': 'bad page'}),
      );
      expect(events, <String>['onPageError(4,bad page)']);
    });

    test('onLinkHandler receives a bare string argument', () async {
      await _emit(const MethodCall('onLinkHandler', 'https://example.com'));
      expect(events, <String>['onLinkHandler(https://example.com)']);
    });

    test('onLinkHandler tolerates a null uri', () async {
      await _emit(const MethodCall('onLinkHandler'));
      expect(events, <String>['onLinkHandler(null)']);
    });

    test('onLoadComplete receives the page count', () async {
      await _emit(const MethodCall('onLoadComplete', <String, Object?>{'pages': 11}));
      expect(events, <String>['onLoadComplete(11)']);
    });

    test('onDraw receives offsets and scale', () async {
      await _emit(const MethodCall('onDraw', <String, Object?>{
        'pdfXOffset': 1.5,
        'pdfYOffset': 2.5,
        'pdfScale': 3.5,
      }));
      expect(events, <String>['onDraw(1.5,2.5,3.5)']);
    });

    test('an unknown native method is reported as a missing plugin', () async {
      ByteData? reply;
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
        _channelName,
        _codec.encodeMethodCall(const MethodCall('onSomethingNew')),
        (ByteData? data) => reply = data,
      );
      // MethodChannel turns MissingPluginException into a null (not-implemented)
      // reply rather than an error envelope.
      expect(reply, isNull);
      expect(events, isEmpty);
    });
  });

  group('PDFViewController dispose', () {
    test('native callbacks are ignored after dispose', () async {
      final List<String> events = <String>[];
      final PDFView view = PDFView(
        filePath: 'test.pdf',
        onRender: (int? pages) => events.add('onRender($pages)'),
        onPageChanged: (int? page, int? total) => events.add('onPageChanged'),
        onError: (dynamic error) => events.add('onError'),
      );
      final PDFViewController controller = PDFViewController.test(_viewId, view);

      await _emit(const MethodCall('onRender', <String, Object?>{'pages': 2}));
      expect(events, <String>['onRender(2)']);

      controller.dispose();

      await _emit(const MethodCall('onRender', <String, Object?>{'pages': 3}));
      await _emit(const MethodCall('onPageChanged', <String, Object?>{'page': 1, 'total': 3}));
      await _emit(const MethodCall('onError', <String, Object?>{'error': 'late'}));

      expect(events, <String>['onRender(2)'], reason: 'no callbacks after dispose');
    });

    test('dispose is idempotent', () async {
      final PDFViewController controller = PDFViewController.test(
        _viewId,
        const PDFView(filePath: 'test.pdf'),
      );
      controller.dispose();
      expect(controller.dispose, returnsNormally);
    });
  });
}
