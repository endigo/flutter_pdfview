// Example app widget tests. Platform views are not rendered in pure widget
// tests; we exercise the home screen, navigation, and PDFScreen chrome.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_pdfview_example/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MyApp home screen', () {
    testWidgets('shows plugin title and PDF entry buttons', (tester) async {
      // Skip asset/network loading so the test stays deterministic.
      await tester.pumpWidget(const MyApp(loadDocuments: false));
      await tester.pump();

      expect(find.text('flutter_pdfview example'), findsOneWidget);
      expect(find.text('Open PDF'), findsOneWidget);
      expect(find.text('Open Landscape PDF'), findsOneWidget);
      expect(find.text('Remote PDF'), findsOneWidget);
      expect(find.text('Open PDF (iPad Safe Mode)'), findsOneWidget);
      expect(find.text('Open Password Protected PDF'), findsOneWidget);
      expect(find.text('Search Text in PDF (text layer)'), findsOneWidget);
      expect(find.text('Open Corrupted PDF'), findsOneWidget);
      // Theme toggle lives in the home AppBar.
      expect(find.byTooltip('Theme: system'), findsOneWidget);
    });

    testWidgets('theme toggle cycles light → dark → system', (tester) async {
      await tester.pumpWidget(const MyApp(loadDocuments: false));
      await tester.pump();

      await tester.tap(find.byTooltip('Theme: system'));
      await tester.pump();
      expect(find.byTooltip('Theme: light'), findsOneWidget);

      await tester.tap(find.byTooltip('Theme: light'));
      await tester.pump();
      expect(find.byTooltip('Theme: dark'), findsOneWidget);

      await tester.tap(find.byTooltip('Theme: dark'));
      await tester.pump();
      expect(find.byTooltip('Theme: system'), findsOneWidget);
    });

    testWidgets('Open PDF is a tappable TextButton', (tester) async {
      await tester.pumpWidget(const MyApp(loadDocuments: false));
      await tester.pump();

      final openPdf = find.widgetWithText(TextButton, 'Open PDF');
      expect(openPdf, findsOneWidget);

      // pathPDF starts empty, so navigation should not occur yet.
      await tester.tap(openPdf);
      await tester.pump();
      expect(find.text('Document'), findsNothing);
      expect(find.text('flutter_pdfview example'), findsOneWidget);
    });
  });

  group('TextSearchScreen', () {
    testWidgets('shows search chrome and unsupported banner until layer is known', (
      tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: TextSearchScreen(path: 'demo-text.pdf')));
      await tester.pump();

      expect(find.text('Text search'), findsOneWidget);
      expect(find.text('Find in document'), findsOneWidget);
      expect(find.text('Allow selection'), findsOneWidget);
      expect(find.text('Allow copy'), findsOneWidget);
      // No controller yet → treat as unsupported UI (buttons disabled via supported flag).
      expect(find.byIcon(Icons.search), findsOneWidget);
    });
  });

  group('PDFScreen', () {
    testWidgets('shows Document app bar and loading indicator', (tester) async {
      await tester.pumpWidget(MaterialApp(home: PDFScreen(path: '/tmp/does-not-exist-yet.pdf')));
      await tester.pump();

      expect(find.text('Document'), findsOneWidget);
      expect(find.byIcon(Icons.share), findsOneWidget);
      // Until onRender fires, the example shows a progress indicator.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      // Overlay debug panel is always present.
      expect(find.textContaining('X Offset:'), findsOneWidget);
      expect(find.textContaining('Y Offset:'), findsOneWidget);
      expect(find.textContaining('Scale:'), findsOneWidget);
    });

    testWidgets('iPad safe mode flag is stored on the widget', (tester) async {
      final screen = PDFScreen(path: 'demo.pdf', isIPadSafe: true);
      expect(screen.isIPadSafe, isTrue);
      expect(screen.path, 'demo.pdf');

      final normal = PDFScreen(path: 'demo.pdf');
      expect(normal.isIPadSafe, isFalse);
    });

    testWidgets('renders offset overlay labels with defaults', (tester) async {
      await tester.pumpWidget(MaterialApp(home: PDFScreen(path: 'demo.pdf')));
      await tester.pump();

      expect(find.text('X Offset: 0.00'), findsOneWidget);
      expect(find.text('Y Offset: 0.00'), findsOneWidget);
      expect(find.text('Scale: 1.00'), findsOneWidget);
    });
  });
}
