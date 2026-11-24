# flutter_pdfview example

Demonstrates [`flutter_pdfview`](https://pub.dev/packages/flutter_pdfview) on a real device / simulator.

## Run

From the repository root (workspace):

```bash
cd packages/flutter_pdfview/example
flutter pub get
flutter run
```

## What the app covers

| Home button | What it exercises |
| --- | --- |
| Open PDF | Asset load (`demo.pdf`), navigation, `setPage(withAnimation: true)` |
| Open Landscape PDF | Landscape page size / fit |
| Open from URL | Network download → temp file → `PDFView` |
| Open with iPad-safe scroll | Conservative swipe / spacing config for iPad |
| Open password-protected PDF | `onPasswordRequired` + `unlock()` (`demo-protected.pdf`) |
| **Search Text in PDF** | **Text layer** — find, next/prev match, selection, allow-copy chips (`demo-text.pdf`, `TextSearchScreen`) |
| Open Corrupted PDF | `onError` path |

### Text search demo

`TextSearchScreen` is the reference shape for apps:

1. After `onViewCreated`, call `controller.isTextLayerSupported()`.
2. Only enable search UI when that returns `true`.
3. Use `searchText` / `nextMatch` / `previousMatch`, and listen to
   `onSearchResultChanged` / `onTextSelectionChanged`.
4. Toggle `enableTextSelection` / `enableCopy` at runtime (no remount).

On Android the banner explains that there is no text layer yet and methods would
throw `UnsupportedError` if called anyway.

## Integration tests

Drive the real native viewers:

```bash
cd packages/flutter_pdfview/example

# Password unlock (Android / iOS)
flutter test integration_test/password_test.dart

# Text layer — iOS has a layer; Android asserts unsupported honestly
flutter test integration_test/text_layer_test.dart
```

Fixtures:

- `assets/demo-protected.pdf` — built via `scripts/make_protected_pdf.py`
- `assets/demo-text.pdf` — built via `scripts/make_text_pdf.py` (known pages/terms)

## Notes

- Plugin dependency is `path: ../` (workspace member).
- Min Flutter / Dart follow the package `pubspec.yaml`.
