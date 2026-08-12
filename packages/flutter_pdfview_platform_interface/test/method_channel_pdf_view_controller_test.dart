import 'package:flutter/services.dart';
import 'package:flutter_pdfview_platform_interface/flutter_pdfview_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

const int _viewId = 7;
final MethodChannel _channel = MethodChannel('plugins.endigo.io/pdfview_$_viewId');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final List<MethodCall> log = <MethodCall>[];

  /// Answers platform calls from the controller.
  void mockPlatform(Future<Object?>? Function(MethodCall call) handler) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      _channel,
      (MethodCall call) async {
        log.add(call);
        return handler(call);
      },
    );
  }

  /// Delivers a call from the "native" side to the controller's handler.
  Future<void> emit(String method, [dynamic arguments]) {
    return TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
      _channel.name,
      const StandardMethodCodec().encodeMethodCall(MethodCall(method, arguments)),
      (_) {},
    );
  }

  setUp(() => log.clear());

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      _channel,
      null,
    );
  });

  group('outgoing calls', () {
    late MethodChannelPdfViewController controller;

    setUp(() {
      controller = MethodChannelPdfViewController(_viewId, const PdfViewCallbacks());
    });

    tearDown(() => controller.dispose());

    test('getPageCount forwards to pageCount', () async {
      mockPlatform((_) async => 12);
      expect(await controller.getPageCount(), 12);
      expect(log.single.method, 'pageCount');
    });

    test('setPage passes the page index and default withAnimation false', () async {
      mockPlatform((_) async => true);
      expect(await controller.setPage(4), isTrue);
      expect(log.single.arguments, <String, dynamic>{'page': 4, 'withAnimation': false});
    });

    test('setPage forwards withAnimation when requested', () async {
      mockPlatform((_) async => true);
      expect(await controller.setPage(2, withAnimation: true), isTrue);
      expect(log.single.arguments, <String, dynamic>{'page': 2, 'withAnimation': true});
    });

    test('getCurrentPageSize builds a Size from the returned pair', () async {
      mockPlatform((_) async => <double>[200.5, 400.25]);
      expect(await controller.getCurrentPageSize(), const Size(200.5, 400.25));
    });

    test('getPosition builds an Offset from the returned pair', () async {
      mockPlatform((_) async => <double>[10, 20]);
      expect(await controller.getPosition(), const Offset(10, 20));
    });

    test('getScale falls back to 1 when the platform returns null', () async {
      mockPlatform((_) async => null);
      expect(await controller.getScale(), 1);
    });

    test('setZoomLimits passes all three levels', () async {
      mockPlatform((_) async => true);
      expect(await controller.setZoomLimits(1, 2, 4), isTrue);
      expect(log.single.arguments, <String, dynamic>{
        'minZoom': 1.0,
        'midZoom': 2.0,
        'maxZoom': 4.0,
      });
    });

    test('getScreenshot returns an empty string when the platform returns null', () async {
      mockPlatform((_) async => null);
      expect(await controller.getScreenshot('shot.png'), '');
    });

    test('unlock passes the password and reports the result', () async {
      mockPlatform((_) async => true);
      expect(await controller.unlock('hunter2'), isTrue);
      expect(log.single.arguments, <String, dynamic>{'password': 'hunter2'});
    });

    test('reload returns false when the platform returns null', () async {
      mockPlatform((_) async => null);
      expect(await controller.reload(), isFalse);
    });

    test('updateSettings forwards the diff verbatim', () async {
      mockPlatform((_) async => null);
      await controller.updateSettings(<String, dynamic>{'enableSwipe': false});
      expect(log.single.method, 'updateSettings');
      expect(log.single.arguments, <String, dynamic>{'enableSwipe': false});
    });
  });

  group('call ordering', () {
    late MethodChannelPdfViewController controller;

    setUp(() {
      controller = MethodChannelPdfViewController(_viewId, const PdfViewCallbacks());
    });

    tearDown(() => controller.dispose());

    test('overlapping setPosition calls reach the platform in call order', () async {
      mockPlatform((_) async => true);

      final Future<bool> first = controller.setPosition(const Offset(1, 1));
      final Future<bool> second = controller.setPosition(const Offset(2, 2));
      await Future.wait(<Future<bool>>[first, second]);

      expect(log.map((MethodCall c) => c.arguments['xPos']).toList(), <double>[1, 2]);
    });

    test('a failed setPosition does not stall later calls', () async {
      bool firstCall = true;
      mockPlatform((_) async {
        if (firstCall) {
          firstCall = false;
          throw PlatformException(code: 'boom');
        }
        return true;
      });

      await expectLater(controller.setPosition(const Offset(1, 1)), throwsA(anything));
      expect(await controller.setPosition(const Offset(2, 2)), isTrue);
    });

    test('getPosition waits for a pending setPosition', () async {
      final List<String> order = <String>[];
      mockPlatform((MethodCall call) async {
        order.add(call.method);
        return call.method == 'getPosition' ? <double>[2, 2] : true;
      });

      final Future<bool> set = controller.setPosition(const Offset(2, 2));
      final Future<Offset> get = controller.getPosition();
      await Future.wait(<Future<Object>>[set, get]);

      expect(order, <String>['setPosition', 'getPosition']);
    });

    test('getScale waits for a pending setScale', () async {
      final List<String> order = <String>[];
      mockPlatform((MethodCall call) async {
        order.add(call.method);
        return call.method == 'getScale' ? 2.0 : true;
      });

      final Future<bool> set = controller.setScale(2);
      final Future<double> get = controller.getScale();
      await Future.wait(<Future<Object>>[set, get]);

      expect(order, <String>['setScale', 'getScale']);
    });
  });

  group('incoming callbacks', () {
    test('dispatches every native event to the matching callback', () async {
      int? renderedPages;
      int? changedPage;
      int? changedTotal;
      Object? error;
      int? pageErrorPage;
      PDFPasswordFailure? passwordFailure;
      String? link;
      int? loadedPages;
      List<double>? drawn;
      bool tapped = false;

      final MethodChannelPdfViewController controller = MethodChannelPdfViewController(
        _viewId,
        PdfViewCallbacks(
          onRender: (int? pages) => renderedPages = pages,
          onPageChanged: (int? page, int? total) {
            changedPage = page;
            changedTotal = total;
          },
          onError: (dynamic e) => error = e,
          onPageError: (int? page, dynamic _) => pageErrorPage = page,
          onPasswordRequired: (PDFPasswordFailure f) => passwordFailure = f,
          onLinkHandler: (String? uri) => link = uri,
          onLoadComplete: (int? pages) => loadedPages = pages,
          onDraw: (double x, double y, double scale) => drawn = <double>[x, y, scale],
          onTap: () => tapped = true,
        ),
      );
      addTearDown(controller.dispose);

      await emit('onRender', <String, dynamic>{'pages': 9});
      await emit('onPageChanged', <String, dynamic>{'page': 2, 'total': 9});
      await emit('onError', <String, dynamic>{'error': 'bad'});
      await emit('onPageError', <String, dynamic>{'page': 3, 'error': 'bad page'});
      await emit('onPasswordRequired', <String, dynamic>{'incorrect': true});
      await emit('onLinkHandler', 'https://example.com');
      await emit('onLoadComplete', <String, dynamic>{'pages': 9});
      await emit('onDraw', <String, dynamic>{
        'pdfXOffset': 1.0,
        'pdfYOffset': 2.0,
        'pdfScale': 3.0,
      });
      await emit('onTap');

      expect(renderedPages, 9);
      expect(changedPage, 2);
      expect(changedTotal, 9);
      expect(error, 'bad');
      expect(pageErrorPage, 3);
      expect(passwordFailure, PDFPasswordFailure.incorrect);
      expect(link, 'https://example.com');
      expect(loadedPages, 9);
      expect(drawn, <double>[1, 2, 3]);
      expect(tapped, isTrue);
    });

    test('a missing incorrect flag reports a missing password', () async {
      PDFPasswordFailure? failure;
      final MethodChannelPdfViewController controller = MethodChannelPdfViewController(
        _viewId,
        PdfViewCallbacks(onPasswordRequired: (PDFPasswordFailure f) => failure = f),
      );
      addTearDown(controller.dispose);

      await emit('onPasswordRequired', <String, dynamic>{});
      expect(failure, PDFPasswordFailure.missing);
    });

    test('updateCallbacks re-points dispatch at the new closures', () async {
      int firstCount = 0;
      int secondCount = 0;
      final MethodChannelPdfViewController controller = MethodChannelPdfViewController(
        _viewId,
        PdfViewCallbacks(onTap: () => firstCount++),
      );
      addTearDown(controller.dispose);

      await emit('onTap');
      controller.updateCallbacks(PdfViewCallbacks(onTap: () => secondCount++));
      await emit('onTap');

      expect(firstCount, 1);
      expect(secondCount, 1);
    });

    test('a disposed controller stops delivering callbacks', () async {
      int taps = 0;
      final MethodChannelPdfViewController controller = MethodChannelPdfViewController(
        _viewId,
        PdfViewCallbacks(onTap: () => taps++),
      );

      await emit('onTap');
      controller.dispose();
      await emit('onTap');

      expect(taps, 1);
    });

    test('updateCallbacks after dispose does not revive the controller', () async {
      int taps = 0;
      final MethodChannelPdfViewController controller = MethodChannelPdfViewController(
        _viewId,
        const PdfViewCallbacks(),
      );

      controller.dispose();
      controller.updateCallbacks(PdfViewCallbacks(onTap: () => taps++));
      await emit('onTap');

      expect(taps, 0);
    });

    test('dispose is idempotent', () {
      final MethodChannelPdfViewController controller = MethodChannelPdfViewController(
        _viewId,
        const PdfViewCallbacks(),
      );
      controller.dispose();
      expect(controller.dispose, returnsNormally);
    });
  });
}
