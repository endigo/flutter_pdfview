// End-to-end coverage for password-protected documents, driving the real native
// viewers: AndroidPdfViewer on Android and PDFKit on iOS.
//
//   cd example && flutter test integration_test/password_test.dart
//
// The fixture is encrypted with the standard security handler; see
// scripts/make_protected_pdf.py for its passwords.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

const String userPassword = 'hunter2';
const String ownerPassword = '0wn3r-s3cret';
const int protectedPageCount = 2;

/// Everything the widget reported back, so tests assert on callbacks, not pixels.
class Reported {
  final List<PDFPasswordFailure> passwordFailures = <PDFPasswordFailure>[];
  final List<String> errors = <String>[];
  int? renderedPages;
  int? loadedPages;
  PDFViewController? controller;

  bool get didRender => renderedPages != null;

  void clear() {
    passwordFailures.clear();
    errors.clear();
    renderedPages = null;
    loadedPages = null;
  }
}

Future<File> copyAsset(String asset, String fileName) async {
  final Directory dir = await getApplicationDocumentsDirectory();
  final File file = File('${dir.path}/$fileName');
  final ByteData data = await rootBundle.load(asset);
  await file.writeAsBytes(data.buffer.asUint8List(), flush: true);
  return file;
}

/// Pumps until [condition] holds, giving the native viewer real time to load.
/// Returns whether it ever held, so a failure names the expectation.
Future<bool> waitFor(
  WidgetTester tester,
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  final DateTime deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    if (condition()) {
      return true;
    }
    await tester.pump(const Duration(milliseconds: 100));
  }
  return condition();
}

/// Keeps pumping for [duration] so late callbacks can still arrive.
Future<void> settleFor(
  WidgetTester tester, [
  Duration duration = const Duration(seconds: 3),
]) async {
  final DateTime deadline = DateTime.now().add(duration);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late String protectedPath;
  late String plainPath;
  late Uint8List protectedBytes;

  setUpAll(() async {
    final File protectedFile = await copyAsset('assets/demo-protected.pdf', 'demo-protected.pdf');
    protectedPath = protectedFile.path;
    protectedBytes = await protectedFile.readAsBytes();
    plainPath = (await copyAsset('assets/demo.pdf', 'demo-plain.pdf')).path;
  });

  /// Mounts a [PDFView] and returns the callbacks it reported. Passing [into]
  /// re-mounts with a different password, the declarative half of the API.
  Future<Reported> pumpViewer(
    WidgetTester tester, {
    String? filePath,
    Uint8List? pdfData,
    String? password,
    Reported? into,
  }) async {
    final Reported reported = into ?? Reported();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PDFView(
            filePath: filePath,
            pdfData: pdfData,
            password: password,
            onViewCreated: (PDFViewController controller) {
              reported.controller = controller;
            },
            onPasswordRequired: (PDFPasswordFailure failure) {
              reported.passwordFailures.add(failure);
            },
            onError: (dynamic error) {
              reported.errors.add(error.toString());
            },
            onRender: (int? pages) {
              reported.renderedPages = pages;
            },
            onLoadComplete: (int? pages) {
              reported.loadedPages = pages;
            },
          ),
        ),
      ),
    );
    await tester.pump();
    return reported;
  }

  /// Tears the platform view down between tests so native resources are freed.
  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 500));
  }

  group('locked document', () {
    testWidgets('reports a missing password when none is supplied', (WidgetTester tester) async {
      final Reported reported = await pumpViewer(tester, filePath: protectedPath);

      expect(
        await waitFor(tester, () => reported.passwordFailures.isNotEmpty),
        isTrue,
        reason: 'an encrypted document must ask for a password instead of staying blank',
      );
      expect(reported.passwordFailures.first, PDFPasswordFailure.missing);
      // onError still fires, so viewers written before this callback work.
      expect(
        await waitFor(tester, () => reported.errors.isNotEmpty),
        isTrue,
        reason: 'onError must keep firing alongside onPasswordRequired',
      );
      expect(reported.didRender, isFalse);

      await unmount(tester);
    });

    testWidgets('reports an incorrect password when a wrong one is supplied', (
      WidgetTester tester,
    ) async {
      final Reported reported = await pumpViewer(
        tester,
        filePath: protectedPath,
        password: 'not-the-password',
      );

      expect(await waitFor(tester, () => reported.passwordFailures.isNotEmpty), isTrue);
      expect(reported.passwordFailures.first, PDFPasswordFailure.incorrect);
      expect(reported.didRender, isFalse);

      await unmount(tester);
    });

    testWidgets('renders when the user password is supplied up front', (WidgetTester tester) async {
      final Reported reported = await pumpViewer(
        tester,
        filePath: protectedPath,
        password: userPassword,
      );

      expect(
        await waitFor(tester, () => reported.didRender),
        isTrue,
        reason: 'the correct password must open the document',
      );
      expect(reported.renderedPages, protectedPageCount);
      expect(await waitFor(tester, () => reported.loadedPages != null), isTrue);
      expect(reported.passwordFailures, isEmpty);
      expect(await reported.controller!.getPageCount(), protectedPageCount);

      await unmount(tester);
    });

    testWidgets('accepts the owner password too', (WidgetTester tester) async {
      final Reported reported = await pumpViewer(
        tester,
        filePath: protectedPath,
        password: ownerPassword,
      );

      expect(await waitFor(tester, () => reported.didRender), isTrue);
      expect(reported.renderedPages, protectedPageCount);
      expect(reported.passwordFailures, isEmpty);

      await unmount(tester);
    });

    testWidgets('opens an encrypted document loaded from bytes', (WidgetTester tester) async {
      final Reported reported = await pumpViewer(
        tester,
        pdfData: protectedBytes,
        password: userPassword,
      );

      expect(
        await waitFor(tester, () => reported.didRender),
        isTrue,
        reason: 'pdfData must honour the password like filePath does',
      );
      expect(reported.renderedPages, protectedPageCount);

      await unmount(tester);
    });
  });

  group('unlocking after the prompt', () {
    testWidgets('controller.unlock opens the document without remounting', (
      WidgetTester tester,
    ) async {
      final Reported reported = await pumpViewer(tester, filePath: protectedPath);
      expect(await waitFor(tester, () => reported.passwordFailures.isNotEmpty), isTrue);

      final PDFViewController controller = reported.controller!;
      reported.clear();

      // The user types the right password into the app's own prompt.
      late bool unlocked;
      await tester.runAsync(() async {
        unlocked = await controller.unlock(userPassword);
      });

      expect(unlocked, isTrue, reason: 'unlock must report that the document opened');
      expect(await waitFor(tester, () => reported.didRender), isTrue);
      expect(reported.renderedPages, protectedPageCount);
      expect(reported.passwordFailures, isEmpty);
      expect(await controller.getPageCount(), protectedPageCount);
      expect(
        identical(controller, reported.controller),
        isTrue,
        reason: 'the platform view must survive the unlock',
      );

      await unmount(tester);
    });

    testWidgets('a wrong unlock is rejected and can be retried', (WidgetTester tester) async {
      final Reported reported = await pumpViewer(tester, filePath: protectedPath);
      expect(await waitFor(tester, () => reported.passwordFailures.isNotEmpty), isTrue);

      final PDFViewController controller = reported.controller!;
      reported.clear();

      late bool firstAttempt;
      await tester.runAsync(() async {
        firstAttempt = await controller.unlock('still-wrong');
      });
      expect(firstAttempt, isFalse);
      expect(await waitFor(tester, () => reported.passwordFailures.isNotEmpty), isTrue);
      expect(reported.passwordFailures.last, PDFPasswordFailure.incorrect);
      expect(reported.didRender, isFalse);

      reported.clear();
      late bool secondAttempt;
      await tester.runAsync(() async {
        secondAttempt = await controller.unlock(userPassword);
      });

      expect(secondAttempt, isTrue, reason: 'a failed attempt must not poison later ones');
      expect(await waitFor(tester, () => reported.didRender), isTrue);
      expect(reported.renderedPages, protectedPageCount);

      await unmount(tester);
    });

    testWidgets('rebuilding with the password opens the document in place', (
      WidgetTester tester,
    ) async {
      final Reported reported = await pumpViewer(tester, filePath: protectedPath);
      expect(await waitFor(tester, () => reported.passwordFailures.isNotEmpty), isTrue);

      final PDFViewController controller = reported.controller!;
      reported.clear();

      await pumpViewer(tester, filePath: protectedPath, password: userPassword, into: reported);

      expect(
        await waitFor(tester, () => reported.didRender),
        isTrue,
        reason: 'a rebuild with the new password must reopen the document',
      );
      expect(reported.renderedPages, protectedPageCount);
      expect(
        identical(controller, reported.controller),
        isTrue,
        reason: 'only the password changed, so the platform view must be reused',
      );

      await unmount(tester);
    });

    testWidgets('navigation works on a document opened by unlock', (WidgetTester tester) async {
      final Reported reported = await pumpViewer(tester, filePath: protectedPath);
      expect(await waitFor(tester, () => reported.passwordFailures.isNotEmpty), isTrue);

      final PDFViewController controller = reported.controller!;
      await tester.runAsync(() async {
        expect(await controller.unlock(userPassword), isTrue);
      });
      expect(await waitFor(tester, () => reported.didRender), isTrue);

      await tester.runAsync(() async {
        expect(await controller.setPage(1), isTrue);
      });
      await settleFor(tester, const Duration(seconds: 1));
      expect(await controller.getCurrentPage(), 1);

      await unmount(tester);
    });
  });

  group('documents that are not encrypted', () {
    testWidgets('never ask for a password', (WidgetTester tester) async {
      final Reported reported = await pumpViewer(tester, filePath: plainPath);

      expect(await waitFor(tester, () => reported.didRender), isTrue);
      await settleFor(tester);
      expect(reported.passwordFailures, isEmpty);
      expect(reported.errors, isEmpty);

      await unmount(tester);
    });

    testWidgets('still reload when unlock is called on them', (WidgetTester tester) async {
      final Reported reported = await pumpViewer(tester, filePath: plainPath);
      expect(await waitFor(tester, () => reported.didRender), isTrue);
      final int? pages = reported.renderedPages;
      final PDFViewController controller = reported.controller!;
      reported.clear();

      await tester.runAsync(() async {
        expect(await controller.unlock('ignored'), isTrue);
      });

      expect(await waitFor(tester, () => reported.didRender), isTrue);
      expect(reported.renderedPages, pages);
      expect(reported.passwordFailures, isEmpty);

      await unmount(tester);
    });
  });
}
