## 1.1.0

- Add the text layer to the interface: `PdfTextMatch`, the
  `TextSelectionChangedCallback` / `SearchResultChangedCallback` signatures, the
  `enableTextSelection` / `enableCopy` settings, and the search and selection
  methods on `PdfViewPlatformController`
- Add `PdfViewPlatformController.isTextLayerSupported`, and
  `kPdfTextLayerUnsupportedCode` — the `PlatformException.code` an implementation
  must use when it has no text layer. `MethodChannelPdfViewController` turns it
  into an `UnsupportedError`, so an empty search result always means "searched,
  found nothing" and never "not supported here"
- Non-breaking for existing implementations that extend `FlutterPdfViewPlatform`

## 1.0.1

- `PdfViewPlatformController.setPage` accepts optional `withAnimation` (default `false`; Android
  only — iOS ignores it)
- `PdfViewSettings.spacing` — optional inter-page gap (creation-time; not in `updatesMap`)

## 1.0.0

- Initial release, extracted from `flutter_pdfview` 1.5.0.
- Adds `FlutterPdfViewPlatform`, `PdfViewPlatformController`,
  `PdfViewCreationParams`, `PdfViewSettings` and `PdfViewCallbacks`.
- Ships `MethodChannelFlutterPdfView`, the default implementation backed by the
  `plugins.endigo.io/pdfview` platform view and the per-view
  `plugins.endigo.io/pdfview_<id>` method channels. The wire format is unchanged
  from `flutter_pdfview` 1.5.0, so existing native implementations keep working.
- Moves the shared value types (`FitPolicy`, `PageAlignment`, `PdfColorMode`,
  `PDFPasswordFailure`, and the callback signatures) here; `flutter_pdfview`
  re-exports them, so app code needs no changes.
