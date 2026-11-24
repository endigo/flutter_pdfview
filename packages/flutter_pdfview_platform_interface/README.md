# flutter_pdfview_platform_interface

The common platform interface for the [`flutter_pdfview`][pub] plugin.

This package declares the interface that platform-specific implementations of
`flutter_pdfview` implement. **App authors should depend on
[`flutter_pdfview`][pub] instead** — this package on its own renders nothing.

## What is in here

| Type | Purpose |
| --- | --- |
| `FlutterPdfViewPlatform` | The interface an implementation extends; `buildView` returns the widget hosting the native view. |
| `PdfViewPlatformController` | Drives one created view — page navigation, zoom, scroll, screenshot, unlock. |
| `PdfViewCreationParams` | Document source plus initial settings, serialized for the native view factory. |
| `PdfViewSettings` | The settings snapshot and the runtime diff (`updatesMap`) pushed on rebuild. |
| `PdfViewCallbacks` | The viewer events an implementation reports back. |
| `FitPolicy`, `PageAlignment`, `PdfColorMode`, `PDFPasswordFailure` | Shared value types, re-exported by `flutter_pdfview`. |
| `MethodChannelFlutterPdfView` | The default implementation, backed by the `plugins.endigo.io/pdfview` platform view and per-view `plugins.endigo.io/pdfview_<id>` method channels. |

## Implementing a platform

Extend `FlutterPdfViewPlatform` — do not implement it. New members are added as
non-breaking changes with a default implementation, which only works for
subclasses:

```dart
class FlutterPdfViewWeb extends FlutterPdfViewPlatform {
  static void registerWith(Registrar registrar) {
    FlutterPdfViewPlatform.instance = FlutterPdfViewWeb();
  }

  @override
  Widget buildView({...}) => ...;
}
```

`PdfColorMode.system` is resolved to `light` or `dark` by the app-facing package
before it reaches an implementation, so implementations never observe `system`.

## Breaking changes

Adding a new method with a default implementation, or a new optional parameter,
is non-breaking. Removing or renaming anything, or adding a required parameter,
is breaking and needs a major version bump.

[pub]: https://pub.dev/packages/flutter_pdfview
