# flutter_pdfview_android_pdfium

The opt-in **PDFium** Android engine for [`flutter_pdfview`](https://pub.dev/packages/flutter_pdfview).

Since `flutter_pdfview` 2.0, Android renders PDFs with Android's own PDF
engine through Jetpack [`androidx.pdf`](https://developer.android.com/jetpack/androidx/releases/pdf),
so apps no longer ship PDFium. That engine scrolls vertically only, needs
Android 9 (API 28), and requires the app to compile against SDK extension 19.
Add this package if your app needs either of:

- **Horizontal paging**: `swipeHorizontal`, `pageFling`, `pageSnap`
- **Android 5.0–8.1** (API 21–27)

It is the engine `flutter_pdfview` 1.x used (AndroidPdfViewer on PDFium), with
the same behaviour.

## Usage

Add it **next to** `flutter_pdfview` — it must be a direct dependency of your
app to replace the default Android engine:

```yaml
dependencies:
  flutter_pdfview: 2.0.0-beta.1
  flutter_pdfview_android_pdfium: 1.0.0-beta.1
```

Keep importing `package:flutter_pdfview/flutter_pdfview.dart`; this package
has no Dart API of its own. iOS is unaffected. With this package the default
engine is left out of your build entirely, so its `minSdk 28` and
`compileSdkExtension 19` requirements do not apply.

## Limitations

- No text layer: `searchText` and the other text-layer methods throw
  `UnsupportedError`, and `isTextLayerSupported()` returns `false`
- Adds the PDFium native libraries (several MB per CPU architecture) to your app
