# flutter_pdfview

Native PDF View for iOS and Android

<p align="center">
<a  href="https://www.buymeacoffee.com/endigo" target="_blank"><img src="https://cdn.buymeacoffee.com/buttons/lato-blue.png" alt="Buy Me A Coffee" height=60 ></a>
</p>


# Use this package as a library

## 1. Depend on it

Add this to your package's pubspec.yaml file:

```yaml
dependencies:
  flutter_pdfview: ^1.4.5
```

#### Trying the 2.0.0 beta

`2.0.0-beta.1` is the Kotlin/Swift rewrite with a new Android engine (Android's own PDF
renderer, no bundled PDFium) and a **text layer** — search, selection and copy control on iOS
and Android ([#137](https://github.com/endigo/flutter_pdfview/issues/137),
[#285](https://github.com/endigo/flutter_pdfview/issues/285),
[#108](https://github.com/endigo/flutter_pdfview/issues/108)) — password unlock
([#274](https://github.com/endigo/flutter_pdfview/issues/274)), luminance-preserving
`PdfColorMode` dark theming ([#215](https://github.com/endigo/flutter_pdfview/issues/215),
[#138](https://github.com/endigo/flutter_pdfview/issues/138)), animated page navigation and
configurable page spacing. It is a new major version: pages now follow the app's theme by
default (pass `colorMode: PdfColorMode.light` for the `1.4.5` look), iOS now applies settings
changed on rebuild, and Android needs Android 9 unless you add the PDFium engine — see
[Android engines](#android-engines). See the [CHANGELOG](CHANGELOG.md) for the full list. Pre-releases are not
picked up by a `^` constraint, so pin it explicitly:

```yaml
dependencies:
  flutter_pdfview: 2.0.0-beta.1
```

Feedback is welcome in [#351](https://github.com/endigo/flutter_pdfview/issues/351).

### Android engines

Since 2.0, Android renders PDFs with **Android's own PDF engine** through
Jetpack [`androidx.pdf`](https://developer.android.com/jetpack/androidx/releases/pdf),
so your app no longer ships PDFium. It also brings the
[text layer](#text-layer) — search, selection and copy control — to Android.

It needs **Android 9 (API 28)** and an app that compiles against SDK extension
19. Set both in `android/app/build.gradle`; without them the build fails with a
`minSdkVersion` / `compileSdkExtension` error that names `androidx.pdf`:

```groovy
android {
    compileSdk 36
    compileSdkExtension 19   // required by androidx.pdf
    defaultConfig {
        minSdkVersion 28
    }
}
```

If your app needs **horizontal paging** (`swipeHorizontal`, `pageFling`,
`pageSnap`) or must run on **Android 5.0–8.1**, add the opt-in PDFium engine,
which is the engine `flutter_pdfview` 1.x used, next to `flutter_pdfview`:

```yaml
dependencies:
  flutter_pdfview: 2.0.0-beta.1
  flutter_pdfview_android_pdfium: 1.0.0-beta.1
```

Nothing else changes in your code; iOS is unaffected.

| | Default (`androidx.pdf`) | `flutter_pdfview_android_pdfium` |
|---|---|---|
| Minimum Android | 9 (API 28) | 5.0 (API 21) |
| Bundled native PDF libraries | None | PDFium, several MB per CPU architecture |
| Text layer (search, selection, copy control) | ✅ | ❌ (`UnsupportedError`) |
| Horizontal paging (`swipeHorizontal`, `pageFling`, `pageSnap`) | ❌ vertical only | ✅ |
| `thumbnailRatio`, `useBestQuality`, `enableAntialiasing`, `enableRenderDuringScale` | Ignored (managed by Android) | ✅ |
| `setPage(withAnimation:)` | Ignored | ✅ |

### 2. Install it

You can install packages from the command line:

with Flutter:

```
$ flutter packages get
```

Alternatively, your editor might support pub get or `flutter packages get`. Check the docs for your editor to learn more.

### 3. Import it

Now in your Dart code, you can use:

```
import 'package:flutter_pdfview/flutter_pdfview.dart';
```

## Options

| Name                  | Android | iOS |      Default      |
|:----------------------| :-----: | :-: |:-----------------:|
| defaultPage           |   ✅    | ✅  |        `0`        |
| onViewCreated         |   ✅    | ✅  |      `null`       |
| onRender              |   ✅    | ✅  |      `null`       |
| onPageChanged         |   ✅    | ✅  |      `null`       |
| onLoadComplete        |   ✅    | ✅  |      `null`       |
| onDraw                |   ✅    | ✅  |      `null`       |
| onTap                 |   ✅    | ✅  |      `null`       |
| onTextSelectionChanged |   ❌    | ✅  |      `null`       |
| onSearchResultChanged |   ❌    | ✅  |      `null`       |
| enableTextSelection   |   ⚠️    | ✅  |      `true`       |
| enableCopy            |   ❌    | ✅  |      `true`       |
| onError               |   ✅    | ✅  |      `null`       |
| onPageError           |   ✅    | ❌  |      `null`       |
| onPasswordRequired    |   ✅    | ✅  |      `null`       |
| onLinkHandle          |   ✅    | ✅  |      `null`       |
| gestureRecognizers    |   ✅    | ✅  |      `null`       |
| filePath              |   ✅    | ✅  |                   |
| pdfData               |   ✅    | ✅  |                   |
| fitPolicy             |   ✅    | ✅  | `FitPolicy.WIDTH` |
| pageAlignment*        |   ✅    | ✅  | `PageAlignment.center` |
| enableSwipe           |   ✅    | ✅  |      `true`       |
| swipeHorizontal       |   ✅    | ✅  |      `false`      |
| password              |   ✅    | ✅  |      `null`       |
| colorMode             |   ✅    | ✅  | `PdfColorMode.system` |
| nightMode*            |   ✅    | ✅  |      `false`      |
| autoSpacing*          |   ✅    | ✅  |      `true`       |
| spacing*              |   ✅    | ✅  |      `null`       |
| pageFling             |   ✅    | ✅  |      `true`       |
| pageSnap              |   ✅    | ❌  |      `true`       |
| preventLinkNavigation |   ✅    | ✅  |      `false`      |
| backgroundColor       |   ✅    | ✅  |      `null`       |
| minZoom               |   ✅    | ✅  |        1.0        |
| maxZoom               |   ✅    | ✅  |        4.0        |
| showScrollIndicators* |   ✅    | ✅  |      `false`      |
| enableAntialiasing   |   ✅    | ❌  |      `true`       |
| useBestQuality        |   ✅    | ❌  |      `true`       |
| enableRenderDuringScale | ✅    | ❌  |      `true`       |
| thumbnailRatio*       |   ✅    | ❌  |        0.8        |

Notes:
- `enableTextSelection` and `enableCopy` work on iOS and on Android's default engine. With `flutter_pdfview_android_pdfium` there is no text layer, so they have no effect — see [Text layer](#text-layer), and always check `isTextLayerSupported()` before offering that UI.
- `swipeHorizontal`, `pageFling` and `pageSnap` need `flutter_pdfview_android_pdfium` on Android: the default engine scrolls vertically only. `enableAntialiasing`, `useBestQuality`, `enableRenderDuringScale` and `thumbnailRatio` are PDFium-engine settings and are ignored by the default engine. See [Android engines](#android-engines).
- `colorMode` themes page content and the gutter on both platforms. Values: `PdfColorMode.light`, `PdfColorMode.dark`, `PdfColorMode.system` (default). `system` follows the app `Theme` brightness (or platform brightness when no `Theme` is present) and is resolved in Dart before being sent to the native view. Dark mode uses a luminance-preserving inversion (hue kept; photos do not become pure negatives). Live updates apply without remounting the platform view.
- `nightMode` is **deprecated**. Prefer `colorMode`. When `colorMode` is left at `system` and `nightMode: true`, the resolved mode is `dark`. An explicit `colorMode` always wins.
- `backgroundColor` can be updated at runtime together with `colorMode`. Setting it back to `null` after a non-null value leaves the previous color on screen.
- `password` can be changed after the first build: the document is reopened in place, so the platform view is not recreated. See [Password-protected documents](#password-protected-documents).
- `spacing` sets the gap between pages when `autoSpacing` is true (dp on Android, points on iOS). `null` keeps each platform's default (Android: the default engine's own gap, or 0 / 8 with top alignment on the PDFium engine; iOS 4 top+bottom / 8 bottom-only with top alignment). Creation-time only — remount the view to change it ([#335](https://github.com/endigo/flutter_pdfview/pull/335)).
- `showScrollIndicators` is ignored on iOS while horizontal page-flipping is active (`pageFling: true` together with `swipeHorizontal: true`).
- `autoSpacing` only adds gaps between pages. It does not change initial zoom or `fitPolicy` (fixed in [#150](https://github.com/endigo/flutter_pdfview/issues/150)).
- `thumbnailRatio` must be in `(0, 1]`. Higher values look sharper while tiles load but use more memory.
- `pageAlignment` controls where a document that is **shorter than the viewport** sits. The default `PageAlignment.center` matches historical AndroidPdfViewer / PDFKit behavior. Use `PageAlignment.top` so free space is below the page (typical for single-page PDFs — [#250](https://github.com/endigo/flutter_pdfview/issues/250), [#272](https://github.com/endigo/flutter_pdfview/issues/272)):

```dart
PDFView(
  filePath: path,
  pageAlignment: PageAlignment.top,
  backgroundColor: Colors.grey.shade200,
)
```

### Render quality ([#158](https://github.com/endigo/flutter_pdfview/issues/158))

**iOS (PDFKit)** draws PDF content as vectors at the screen scale. Text and line art
should stay sharp when zooming. This plugin sets the platform view’s
`contentScaleFactor` / layer `contentsScale` to the native display scale so
Flutter embedding never leaves the layer at 1×.

**Android, default engine (`androidx.pdf`)**: rendering, tiling and caching are
managed by Android's own renderer; the knobs below do not apply.

**Android, `flutter_pdfview_android_pdfium` (AndroidPdfViewer + Pdfium)**
rasterizes each page into bitmap tiles:

| Knob | What it does | Cost |
|:-----|:-------------|:-----|
| `useBestQuality: true` (default) | ARGB_8888 tiles instead of RGB_565 | ~2× bitmap memory vs 565 |
| `enableAntialiasing: true` (default) | `FILTER_BITMAP` / AA when drawing tiles | Negligible |
| `enableRenderDuringScale: true` (default) | Re-render tiles during pinch zoom | More CPU while pinching |
| `thumbnailRatio` (default `0.8`) | Resolution of the full-page preview shown before high-res tiles arrive | Memory ∝ ratio² |

On high-DPI devices the plugin also raises AndroidPdfViewer’s page-part cache
slightly (still capped) so fewer tiles fall out of cache after zoom — the common
“only part of the page is clear” report.

**Hard limits (not a bug in this plugin):**

- Tile spatial resolution matches the **view size in pixels**, not print DPI.
  Small text on a phone-sized view will never look like a desktop PDF reader
  without a different engine (supersampling / MuPDF / Android `PdfRenderer` at
  higher scale). That would multiply memory and is intentionally not enabled by
  default.
- AndroidPdfViewer’s tile size / cache are process-wide statics; `thumbnailRatio`
  from the first (or latest) view construction wins for the process.

For the sharpest Android preview without a huge memory hit:

```dart
PDFView(
  filePath: path,
  useBestQuality: true,          // default
  enableAntialiasing: true,    // default
  enableRenderDuringScale: true, // default
  thumbnailRatio: 1.0,           // full-page preview at 1:1 (more RAM)
)
```

### Detecting taps (`onTap`)

For a reliable single-tap callback, use the first-class `onTap` parameter. It
is delivered from the native PDF control on both platforms:

```dart
PDFView(
  filePath: path,
  onTap: () {
    // e.g. toggle chrome / app bar
  },
)
```

Do **not** rely on `gestureRecognizers` with a `TapGestureRecognizer` for taps.
Flutter’s platform-view gesture arena often never delivers `onTap` for embedded
native views ([#133](https://github.com/endigo/flutter_pdfview/issues/133)).
Keep `gestureRecognizers` for parent-scroll conflicts (below).

### AcroForm / fillable form fields

This plugin is a **viewer**, not a form editor. Platform behavior:

| Platform | Engine | Annotation / form field painting |
|:---------|:-------|:---------------------------------|
| Android  | Android's PDF renderer (default, via `androidx.pdf`) or Pdfium (via [AndroidPdfViewer](https://github.com/barteksc/AndroidPdfViewer) in `flutter_pdfview_android_pdfium`) | Widget appearance streams (`/AP`) are painted. Neither regenerates appearances from `/V` + `/DA` the way Adobe Reader does. |
| iOS      | PDFKit | Uses the system renderer; typically more tolerant of incomplete appearances. |

**Implication:** if a PDF’s form field has a missing, empty, or **broken** `/AP` entry, Android can omit that field even when Adobe shows it. A common producer-side failure mode (seen with PDFBox + incremental saves / digital signing) is an object-number collision where the field’s `/AP` indirect reference is later reused for an XRef stream — the field value is still in the file, but the appearance object is no longer valid. See [#303](https://github.com/endigo/flutter_pdfview/issues/303).

**Producer workarounds** (fix generators such as Apache PDFBox):

1. After setting values, generate valid appearance streams (PDFBox: `setValue` / appearance generation; avoid leaving fields without a usable `/AP`).
2. Prefer a full rewrite save when possible; after incremental updates (especially signing), re-check that each field’s `/AP` still resolves to a Form XObject, not an XRef or other object.
3. Flatten fields when interactivity is not required (`PDAcroForm.flatten()`), so values become normal page content.
4. Optionally set `/NeedAppearances true` on the AcroForm dictionary — some viewers honor it; **Pdfium generally still requires a real appearance stream** for reliable display.

There is no plugin API that can repair malformed form appearances without embedding a full PDF rewrite stack (out of scope for this viewer).

### Password-protected documents

Pass the password up front with `password` when you already know it. When you do
not, `onPasswordRequired` tells you that the document is encrypted — either
because no password was supplied (`PDFPasswordFailure.missing`) or because the
one you supplied did not open it (`PDFPasswordFailure.incorrect`) — so you can
prompt the user and try again ([#274](https://github.com/endigo/flutter_pdfview/issues/274)):

```dart
PDFView(
  filePath: path,
  password: _password,
  onPasswordRequired: (PDFPasswordFailure failure) async {
    final String? entered = await showPasswordDialog(
      context,
      retry: failure == PDFPasswordFailure.incorrect,
    );
    if (entered != null) {
      // Either rebuild with the new password ...
      setState(() => _password = entered);
      // ... or hand it straight to the controller:
      // await controller.unlock(entered);
    }
  },
)
```

Both routes reopen the document inside the existing platform view, so a wrong
password can be retried as often as needed without rebuilding the viewer.
`onError` still fires alongside `onPasswordRequired`, so viewers written before
this callback existed keep working.

### Text layer

Text selection ([#285](https://github.com/endigo/flutter_pdfview/issues/285)),
find-in-document ([#137](https://github.com/endigo/flutter_pdfview/issues/137))
and blocking copy ([#108](https://github.com/endigo/flutter_pdfview/issues/108))
all need the document's text layer.

**Supported on iOS (PDFKit) and on Android's default engine (`androidx.pdf`).**
The opt-in `flutter_pdfview_android_pdfium` engine has no text layer:
AndroidPdfViewer's `PdfiumCore` binds none of Pdfium's `FPDFText_*` API in Java.
On Android, a search is case-insensitive in the renderer; `caseSensitive: true`
filters those hits against the page text.

**Always branch on `isTextLayerSupported()`.** The query methods throw
`UnsupportedError` where there is no text layer, deliberately: returning an empty
list would be indistinguishable from "this document contains no matches", and
apps would ship broken search without noticing. `clearSearch` and
`clearSelection` stay no-ops everywhere, because clearing nothing is truthful.

```dart
late PDFViewController controller;

if (await controller.isTextLayerSupported()) {
  final List<PdfTextMatch> matches = await controller.searchText('invoice');
  // The first match is already highlighted and scrolled into view.
  for (final PdfTextMatch match in matches) {
    debugPrint('match ${match.matchIndex} on page ${match.pageIndex}: ${match.text}');
  }
  await controller.nextMatch();     // wraps at the end
  await controller.clearSearch();
} else {
  // Hide the search UI rather than calling and catching.
}
```

Track the active match with `onSearchResultChanged`, and the user's selection
with `onTextSelectionChanged`:

```dart
PDFView(
  filePath: path,
  onSearchResultChanged: (int index, int total) => ..., // index is -1 when cleared
  onTextSelectionChanged: (String? text) => ...,        // null when cleared
)
```

#### Stopping text from leaving the document (#108)

```dart
PDFView(
  filePath: path,
  enableTextSelection: false, // no long-press selection
  enableCopy: false,          // no copy / share / look-up in the edit menu
)
```

Both update at runtime without remounting the view. `enableCopy` needs a
selection to suppress, so `enableTextSelection: false` disables copying too.
On Android's default engine, `enableCopy: false` removes Copy, Copy link and the
smart actions from the selection menu. With `flutter_pdfview_android_pdfium`
both settings have no effect. Note that neither prevents screenshots, nor a user
extracting text from a copy of the file obtained elsewhere.

### Using PDFView inside a scrollable widget

When a `PDFView` is embedded in a scrollable parent (`SingleChildScrollView`,
`ListView`, `PageView`, ...), the parent can claim drag gestures before they
reach the native view, so swiping inside the PDF does not work — most notably
on iOS ([#265](https://github.com/endigo/flutter_pdfview/issues/265)). Pass an
`EagerGestureRecognizer` to let the PDF view consume gestures within its bounds:

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';

PDFView(
  filePath: path,
  gestureRecognizers: {
    Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer()),
  },
)
```

### BackdropFilter / ColorFiltered over PDFView (iOS)

`PDFView` is a **platform view** (`UiKitView` on iOS, hybrid composition on
Android). Flutter composites native views outside the normal Flutter layer
tree, so some widgets that sample or recolor the scene **do not apply to the
PDF pixels** — especially on iOS.

| Widget | iOS platform view | Notes |
|:-------|:-----------------:|:------|
| `ColorFiltered` / `ShaderMask` | ❌ not supported | Official Flutter limitation |
| `BackdropFilter` | ⚠️ partial | Supported with restrictions; needs a recent Flutter |

This is **not a bug in flutter_pdfview**. Flutter documents it under
[iOS platform view composition limitations](https://docs.flutter.dev/platform-integration/ios/platform-views#composition-limitations):
`ShaderMask` and `ColorFiltered` are unsupported; `BackdropFilter` works only
within the constraints of the
[iOS Platform View Backdrop Filter design](https://flutter.dev/go/ios-platformview-backdrop-filter-blur).

**Workarounds**

1. **Color inversion / dark pages** — Prefer the plugin API instead of wrapping
   the view in `ColorFiltered`:
   - Both platforms: `colorMode: PdfColorMode.dark` (or `PdfColorMode.system` to
     follow the app `Theme`). Luminance-preserving invert keeps photos recognizable.
   - Legacy: `nightMode: true` still maps to dark when `colorMode` is left at
     `system` (deprecated).

2. **Blur / glass under a sheet** — Place the `BackdropFilter` so it samples
   Flutter-drawn content (not only the hole where the native PDF sits), use a
   semi-transparent `barrierColor` / scrim, or capture a static preview with
   `PDFViewController.getScreenshot` and blur that `Image` with Flutter widgets.

3. **Static filtered preview** — For a one-shot recolor (e.g. thumbnail), take a
   screenshot and wrap the resulting image:

```dart
final path = await controller.getScreenshot('preview.png');
// Then:
ColorFiltered(
  colorFilter: const ColorFilter.mode(Colors.grey, BlendMode.saturation),
  child: Image.file(File(path)),
);
```

Wrapping `PDFView` itself in `ColorFiltered` will keep painting a solid tint
*under* the native view on iOS while leaving the PDF contents unchanged
([#213](https://github.com/endigo/flutter_pdfview/issues/213)).

## Controller Options

| Name               |                                         Description                                          |                    Parameters                    |      Return      |
|:-------------------|:--------------------------------------------------------------------------------------------:|:------------------------------------------------:|:----------------:|
| getPageCount       |                                     Get total page count                                     |                        -                         |  `Future<int>`   |
| getCurrentPage     |                                       Get current page                                       |                        -                         |  `Future<int>`   |
| setPage            |                                        Go to/Set page                                        | `int page`, `withAnimation` (optional, **Android only**, default `false`) |  `Future<bool>`  |
| getCurrentPageSize |                        Return the width and height of the loaded page                        |                        -                         |  `Future<Size>`  |
| getScreenshot      |               Create a PNG of the contents of the PDFView and save to fileName               |                `String fileName`                 | `Future<String>` |
| getPosition        | Get the position of the top left of the PDF with respect to the origin (top left of PDFView) |                        -                         | `Future<Offset>` |
| getScale           |                             Get the PDF zoom value, for zooming                              |                        -                         | `Future<double>` |
| setPosition        | Set the position of the top left of the PDF with respect to the origin (top left of PDFView) |                `Offset position`                 |  `Future<bool>`  |
| setScale           |                             Set the PDF zoom value, for zooming                              |                  `double scale`                  |  `Future<bool>`  |
| setZoomLimits      |                  Set the minimum, maximum and mid bounds of the zoom limits                  | `double minZoom, double midZoom, double maxZoom` |        -         |
| unlock             |            Reopen the document with a password, for encrypted PDFs ([#274](https://github.com/endigo/flutter_pdfview/issues/274))            |                `String password`                 |  `Future<bool>`  |
| reload             |                            Reload the PDF document in the PDFView                            |                        -                         |  `Future<bool>`  |
| isTextLayerSupported | Whether this platform can search/select text — see [Text layer](#text-layer) | - | `Future<bool>` |
| searchText         | Find every occurrence of a string; activates the first match | `String query, {bool caseSensitive}` | `Future<List<PdfTextMatch>>` |
| nextMatch          | Activate the next match, wrapping at the end | - | `Future<PdfTextMatch?>` |
| previousMatch      | Activate the previous match, wrapping at the start | - | `Future<PdfTextMatch?>` |
| setCurrentMatch    | Activate a match by index | `int index` | `Future<PdfTextMatch?>` |
| clearSearch        | Clear highlights and forget the last search | - | `Future<void>` |
| getSelectedText    | The currently selected text, or null | - | `Future<String?>` |
| clearSelection     | Clear the current text selection | - | `Future<void>` |

## Example

Basic viewer (password, color mode, layout). For **search / selection / copy**, see
[Text layer](#text-layer) and the example app’s `TextSearchScreen`
(`packages/flutter_pdfview/example` → **Search Text in PDF**).

```dart
PDFView(
  filePath: path,
  enableSwipe: true,
  swipeHorizontal: true,
  autoSpacing: false,
  pageFling: false,
  showScrollIndicators: true,
  colorMode: PdfColorMode.system, // follows Theme brightness
  backgroundColor: Theme.of(context).colorScheme.surface,
  // Optional: inter-page gap when autoSpacing is true (dp / points).
  // spacing: 12,
  onRender: (_pages) {
    setState(() {
      pages = _pages;
      isReady = true;
    });
  },
  onError: (error) {
    print(error.toString());
  },
  onPageError: (page, error) {
    print('$page: ${error.toString()}');
  },
  onViewCreated: (PDFViewController pdfViewController) async {
    _controller.complete(pdfViewController);
    // Android can animate; iOS ignores withAnimation.
    // await pdfViewController.setPage(2, withAnimation: true);
  },
  onPageChanged: (int page, int total) {
    print('page change: $page/$total');
  },
  onLoadComplete: (int? pages) {
    print('# of pages: $pages');
  },
  onDraw: (double xOffset, double yOffset, double scale) {
    print('onDraw');
  },
),
```

Text-layer sketch (always gate on support):

```dart
onViewCreated: (PDFViewController c) async {
  if (!await c.isTextLayerSupported()) return;
  final matches = await c.searchText('invoice');
  // nextMatch / previousMatch / clearSearch …
},
onSearchResultChanged: (index, total) { /* highlight chrome */ },
onTextSelectionChanged: (text) { /* selection chrome */ },
enableTextSelection: true,
enableCopy: false, // hide copy/share/look-up in the iOS edit menu
```

# Dependencies

### Android (9.0+)

Jetpack [`androidx.pdf`](https://developer.android.com/jetpack/androidx/releases/pdf)
(`pdf-viewer`, `pdf-document-service`) on Android's own PDF renderer. The opt-in
`flutter_pdfview_android_pdfium` package uses
[AndroidPdfViewer](https://github.com/barteksc/AndroidPdfViewer) (via
`com.github.marain87:AndroidPdfViewer`) and supports Android 5.0+.

### iOS (13.0+)

[PDFKit](https://developer.apple.com/documentation/pdfkit)

# Future plans

- Horizontal paging on the default Android engine, once `androidx.pdf` supports it
- Text layer for `flutter_pdfview_android_pdfium` (JNI shim over Pdfium `FPDFText_*`)
- Support other platforms (macOS, Windows, Linux, Web) via the federated interface
- Improve performance on zooming and page changes
- More integration tests and device coverage

# Support

<p align="center">
<a  href="https://www.buymeacoffee.com/endigo" target="_blank"><img src="https://cdn.buymeacoffee.com/buttons/lato-blue.png" alt="Buy Me A Coffee" height=60 ></a>
</p>

<p align="center">
    <a href="https://www.paypal.com/cgi-bin/webscr?cmd=_s-xclick&hosted_button_id=98DC9WJ8782WW&source=url" target="_blank">
   <img height=60 src="https://www.paypalobjects.com/en_US/i/btn/btn_donateCC_LG.gif" border="0" name="submit" title="PayPal - The safer, easier way to pay online!" alt="Donate with PayPal button" >
    </a>
</p>

## Star History

<a href="https://www.star-history.com/?repos=endigo%2Fflutter_pdfview&type=date&legend=top-left">
 <picture>
   <source media="(prefers-color-scheme: dark)" srcset="https://api.star-history.com/chart?repos=endigo/flutter_pdfview&type=date&theme=dark&legend=top-left&sealed_token=S1XP4ji8L4z53VPV5FGMdzk3yCvYUaH9uBFonXTPmBmtYYHnT56eK11PoHhF4Ddyag11KmOKj1fhkCWcr2mvTkUn8hWeAmfCm2Ecnow8IYstEsirfXUII2Uu2iETsve4HVUUfJMaJli_Vcd4-T8qTUvm_lYlfNkaTLd5GIvMh3As1CBaGN3o-fHAtKof" />
   <source media="(prefers-color-scheme: light)" srcset="https://api.star-history.com/chart?repos=endigo/flutter_pdfview&type=date&legend=top-left&sealed_token=S1XP4ji8L4z53VPV5FGMdzk3yCvYUaH9uBFonXTPmBmtYYHnT56eK11PoHhF4Ddyag11KmOKj1fhkCWcr2mvTkUn8hWeAmfCm2Ecnow8IYstEsirfXUII2Uu2iETsve4HVUUfJMaJli_Vcd4-T8qTUvm_lYlfNkaTLd5GIvMh3As1CBaGN3o-fHAtKof" />
   <img alt="Star History Chart" src="https://api.star-history.com/chart?repos=endigo/flutter_pdfview&type=date&legend=top-left&sealed_token=S1XP4ji8L4z53VPV5FGMdzk3yCvYUaH9uBFonXTPmBmtYYHnT56eK11PoHhF4Ddyag11KmOKj1fhkCWcr2mvTkUn8hWeAmfCm2Ecnow8IYstEsirfXUII2Uu2iETsve4HVUUfJMaJli_Vcd4-T8qTUvm_lYlfNkaTLd5GIvMh3As1CBaGN3o-fHAtKof" />
 </picture>
</a>

### Developer

- [endigo](https://github.com/endigo)
