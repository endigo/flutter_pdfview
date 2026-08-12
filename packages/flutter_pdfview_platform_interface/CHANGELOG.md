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
