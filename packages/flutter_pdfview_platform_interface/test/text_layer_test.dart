import 'package:flutter/services.dart';
import 'package:flutter_pdfview_platform_interface/flutter_pdfview_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

const int _viewId = 11;
final MethodChannel _channel = MethodChannel('plugins.endigo.io/pdfview_$_viewId');

/// The payload a platform with a text layer returns for one match.
Map<Object?, Object?> _match(int page, int index, String? text) => <Object?, Object?>{
  'pageIndex': page,
  'matchIndex': index,
  'text': text,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MethodChannelPdfViewController controller;
  final List<MethodCall> log = <MethodCall>[];

  void mockPlatform(Future<Object?>? Function(MethodCall call) handler) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      _channel,
      (MethodCall call) async {
        log.add(call);
        return handler(call);
      },
    );
  }

  /// Answers every text method the way a platform with no text layer must.
  void mockPlatformWithoutTextLayer() {
    mockPlatform((MethodCall call) async {
      if (call.method == 'isTextLayerSupported') return false;
      if (call.method == 'clearSearch' || call.method == 'clearSelection') return null;
      throw PlatformException(code: kPdfTextLayerUnsupportedCode, message: 'no text layer here');
    });
  }

  setUp(() {
    log.clear();
    controller = MethodChannelPdfViewController(_viewId, const PdfViewCallbacks());
  });

  tearDown(() {
    controller.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      _channel,
      null,
    );
  });

  group('search', () {
    test('decodes matches in order', () async {
      mockPlatform((_) async => <Object?>[_match(0, 0, 'lorem'), _match(3, 1, 'lorem')]);

      final List<PdfTextMatch> matches = await controller.searchText('lorem');

      expect(matches, <PdfTextMatch>[
        const PdfTextMatch(pageIndex: 0, matchIndex: 0, text: 'lorem'),
        const PdfTextMatch(pageIndex: 3, matchIndex: 1, text: 'lorem'),
      ]);
      expect(log.single.arguments, <String, dynamic>{'query': 'lorem', 'caseSensitive': false});
    });

    test('forwards caseSensitive', () async {
      mockPlatform((_) async => <Object?>[]);
      await controller.searchText('Lorem', caseSensitive: true);
      expect(log.single.arguments['caseSensitive'], isTrue);
    });

    test('an empty result means searched-and-found-nothing, not unsupported', () async {
      mockPlatform((_) async => <Object?>[]);
      expect(await controller.searchText('nope'), isEmpty);
    });

    test('skips entries that are not maps', () async {
      mockPlatform((_) async => <Object?>['garbage', _match(1, 0, 'ok')]);
      expect(await controller.searchText('ok'), <PdfTextMatch>[
        const PdfTextMatch(pageIndex: 1, matchIndex: 0, text: 'ok'),
      ]);
    });

    test('nextMatch / previousMatch decode the activated match', () async {
      mockPlatform((_) async => _match(2, 1, 'hit'));
      expect(
        await controller.nextMatch(),
        const PdfTextMatch(pageIndex: 2, matchIndex: 1, text: 'hit'),
      );
      expect(await controller.previousMatch(), isNotNull);
    });

    test('nextMatch returns null when there is no session', () async {
      mockPlatform((_) async => null);
      expect(await controller.nextMatch(), isNull);
    });

    test('setCurrentMatch passes the index', () async {
      mockPlatform((_) async => _match(0, 4, 'x'));
      await controller.setCurrentMatch(4);
      expect(log.single.arguments, <String, dynamic>{'index': 4});
    });
  });

  group('selection', () {
    test('getSelectedText returns the platform string', () async {
      mockPlatform((_) async => 'selected words');
      expect(await controller.getSelectedText(), 'selected words');
    });

    test('getSelectedText returns null when nothing is selected', () async {
      mockPlatform((_) async => null);
      expect(await controller.getSelectedText(), isNull);
    });
  });

  group('callbacks', () {
    Future<void> emit(String method, dynamic arguments) {
      return TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
            _channel.name,
            const StandardMethodCodec().encodeMethodCall(MethodCall(method, arguments)),
            (_) {},
          );
    }

    test('onTextSelectionChanged reports the text and the cleared state', () async {
      final List<String?> seen = <String?>[];
      controller.updateCallbacks(
        PdfViewCallbacks(onTextSelectionChanged: (String? text) => seen.add(text)),
      );

      await emit('onTextSelectionChanged', <String, dynamic>{'text': 'hello'});
      await emit('onTextSelectionChanged', <String, dynamic>{'text': null});

      expect(seen, <String?>['hello', null]);
    });

    test('onSearchResultChanged reports index and total', () async {
      int? index;
      int? total;
      controller.updateCallbacks(
        PdfViewCallbacks(
          onSearchResultChanged: (int i, int t) {
            index = i;
            total = t;
          },
        ),
      );

      await emit('onSearchResultChanged', <String, dynamic>{'currentIndex': 2, 'total': 7});
      expect(index, 2);
      expect(total, 7);

      await emit('onSearchResultChanged', <String, dynamic>{'currentIndex': -1, 'total': 0});
      expect(index, -1);
      expect(total, 0);
    });
  });

  group('platform without a text layer', () {
    setUp(mockPlatformWithoutTextLayer);

    test('isTextLayerSupported reports false', () async {
      expect(await controller.isTextLayerSupported(), isFalse);
    });

    test('searchText throws instead of returning an empty list', () async {
      // The whole point: "no matches" must never be confusable with
      // "this platform cannot search".
      await expectLater(controller.searchText('lorem'), throwsUnsupportedError);
    });

    test('getSelectedText throws instead of returning null', () async {
      await expectLater(controller.getSelectedText(), throwsUnsupportedError);
    });

    test('match navigation throws', () async {
      await expectLater(controller.nextMatch(), throwsUnsupportedError);
      await expectLater(controller.previousMatch(), throwsUnsupportedError);
      await expectLater(controller.setCurrentMatch(0), throwsUnsupportedError);
    });

    test('clearSearch and clearSelection stay no-ops', () async {
      // Clearing nothing is a truthful outcome, so these must not throw.
      await expectLater(controller.clearSearch(), completes);
      await expectLater(controller.clearSelection(), completes);
    });
  });

  test('an unrelated PlatformException is not turned into UnsupportedError', () async {
    mockPlatform((_) async => throw PlatformException(code: 'boom'));
    await expectLater(controller.searchText('x'), throwsA(isA<PlatformException>()));
  });

  group('PdfTextMatch', () {
    test('round-trips through its map form', () {
      const PdfTextMatch match = PdfTextMatch(pageIndex: 4, matchIndex: 9, text: 'hit');
      expect(PdfTextMatch.fromMap(match.toMap()), match);
    });

    test('defaults missing numbers to zero and tolerates a null text', () {
      final PdfTextMatch match = PdfTextMatch.fromMap(<Object?, Object?>{});
      expect(match.pageIndex, 0);
      expect(match.matchIndex, 0);
      expect(match.text, isNull);
    });

    test('equality and hashCode consider every field', () {
      const PdfTextMatch a = PdfTextMatch(pageIndex: 1, matchIndex: 2, text: 'x');
      expect(a, const PdfTextMatch(pageIndex: 1, matchIndex: 2, text: 'x'));
      expect(a.hashCode, const PdfTextMatch(pageIndex: 1, matchIndex: 2, text: 'x').hashCode);
      expect(a, isNot(const PdfTextMatch(pageIndex: 1, matchIndex: 2, text: 'y')));
      expect(a, isNot(const PdfTextMatch(pageIndex: 9, matchIndex: 2, text: 'x')));
    });
  });

  group('settings', () {
    test('text-interaction flags are in the creation wire format', () {
      final Map<String, dynamic> map = PdfViewSettings(
        enableTextSelection: false,
        enableCopy: false,
      ).toMap();
      expect(map['enableTextSelection'], isFalse);
      expect(map['enableCopy'], isFalse);
    });

    test('changing them is pushed as a runtime update', () {
      final PdfViewSettings before = PdfViewSettings(enableTextSelection: true, enableCopy: true);
      final PdfViewSettings after = PdfViewSettings(enableTextSelection: false, enableCopy: false);
      expect(before.updatesMap(after), <String, dynamic>{
        'enableTextSelection': false,
        'enableCopy': false,
      });
    });

    test('leaving them alone produces no update', () {
      final PdfViewSettings before = PdfViewSettings(enableTextSelection: true, enableCopy: true);
      final PdfViewSettings after = PdfViewSettings(enableTextSelection: true, enableCopy: true);
      expect(before.updatesMap(after), isEmpty);
    });
  });
}
