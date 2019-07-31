import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
// import 'package:flutter_pdfview/flutter_pdfview.dart';

void main() {
  const MethodChannel channel = MethodChannel('flutter_pdfview');

  setUp(() {
    channel.setMockMethodCallHandler((MethodCall methodCall) async {
      return '42';
    });
  });

  tearDown(() {
    channel.setMockMethodCallHandler(null);
  });

  test('getPlatformVersion', () async {
//    expect(await FlutterPdfview.platformVersion, '42');
  });
}
