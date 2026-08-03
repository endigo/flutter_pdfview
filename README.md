# flutter_pdfview

Native PDF View for iOS and Android

<p align="center">
<a  href="https://www.buymeacoffee.com/endigo" target="_blank"><img src="https://cdn.buymeacoffee.com/buttons/lato-blue.png" alt="Buy Me A Coffee" height=60 ></a>
</p>


# Use this package as a library

## 1. Depend on it

Add this to your package's pubspec.yaml file:

```
dependencies:
  flutter_pdfview: ^1.4.5
```

#### Trying the 1.5.0 beta

`1.5.0-beta.9` continues the Kotlin/Swift line with luminance-preserving `PdfColorMode`
dark theming ([#215](https://github.com/endigo/flutter_pdfview/issues/215),
[#138](https://github.com/endigo/flutter_pdfview/issues/138)). Pre-releases are not
picked up by a `^` constraint, so pin it explicitly:

```
dependencies:
  flutter_pdfview: 1.5.0-beta.9
```

Feedback is welcome in [#351](https://github.com/endigo/flutter_pdfview/issues/351).

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
| onError               |   ✅    | ✅  |      `null`       |
| onPageError           |   ✅    | ❌  |      `null`       |
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
- `colorMode` themes page content and the gutter on both platforms. Values: `PdfColorMode.light`, `PdfColorMode.dark`, `PdfColorMode.system` (default). `system` follows the app `Theme` brightness (or platform brightness when no `Theme` is present) and is resolved in Dart before being sent to the native view. Dark mode uses a luminance-preserving inversion (hue kept; photos do not become pure negatives). Live updates apply without remounting the platform view.
- `nightMode` is **deprecated**. Prefer `colorMode`. When `colorMode` is left at `system` and `nightMode: true`, the resolved mode is `dark`. An explicit `colorMode` always wins.
- `backgroundColor` can be updated at runtime together with `colorMode`. Setting it back to `null` after a non-null value leaves the previous color on screen.
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

**Android (AndroidPdfViewer + Pdfium)** rasterizes each page into bitmap tiles:

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
| Android  | Pdfium (via [AndroidPdfViewer](https://github.com/barteksc/AndroidPdfViewer)) | Widget appearance streams (`/AP`) are painted when `enableAnnotationRendering` is on (always enabled by this plugin). Pdfium does **not** regenerate appearances from `/V` + `/DA` the way Adobe Reader does. |
| iOS      | PDFKit | Uses the system renderer; typically more tolerant of incomplete appearances. |

**Implication:** if a PDF’s form field has a missing, empty, or **broken** `/AP` entry, Android can omit that field even when Adobe shows it. A common producer-side failure mode (seen with PDFBox + incremental saves / digital signing) is an object-number collision where the field’s `/AP` indirect reference is later reused for an XRef stream — the field value is still in the file, but the appearance object is no longer valid. See [#303](https://github.com/endigo/flutter_pdfview/issues/303).

**Producer workarounds** (fix generators such as Apache PDFBox):

1. After setting values, generate valid appearance streams (PDFBox: `setValue` / appearance generation; avoid leaving fields without a usable `/AP`).
2. Prefer a full rewrite save when possible; after incremental updates (especially signing), re-check that each field’s `/AP` still resolves to a Form XObject, not an XRef or other object.
3. Flatten fields when interactivity is not required (`PDAcroForm.flatten()`), so values become normal page content.
4. Optionally set `/NeedAppearances true` on the AcroForm dictionary — some viewers honor it; **Pdfium generally still requires a real appearance stream** for reliable display.

There is no plugin API that can repair malformed form appearances without embedding a full PDF rewrite stack (out of scope for this viewer).

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
| setPage            |                                        Go to/Set page                                        |                    `int page`                    |  `Future<bool>`  |
| getCurrentPageSize |                        Return the width and height of the loaded page                        |                        -                         |  `Future<Size>`  |
| getScreenshot      |               Create a PNG of the contents of the PDFView and save to fileName               |                `String fileName`                 | `Future<String>` |
| getPosition        | Get the position of the top left of the PDF with respect to the origin (top left of PDFView) |                        -                         | `Future<Offset>` |
| getScale           |                             Get the PDF zoom value, for zooming                              |                        -                         | `Future<double>` |
| setPosition        | Set the position of the top left of the PDF with respect to the origin (top left of PDFView) |                `Offset position`                 |  `Future<bool>`  |
| setScale           |                             Set the PDF zoom value, for zooming                              |                  `double scale`                  |  `Future<bool>`  |
| setZoomLimits      |                  Set the minimum, maximum and mid bounds of the zoom limits                  | `double minZoom, double midZoom, double maxZoom` |        -         |
| reload             |                            Reload the PDF document in the PDFView                            |                        -                         |  `Future<bool>`  |

## Example

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
  onViewCreated: (PDFViewController pdfViewController) {
    _controller.complete(pdfViewController);
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

# Dependencies

### Android

[AndroidPdfViewer](https://github.com/barteksc/AndroidPdfViewer)

### iOS (only support> 12.0)

[PDFKit](https://developer.apple.com/documentation/pdfkit)

# Future plans

- Replace barteksc/AndroidPdfViewer with MuPDF or Android Native PDF Renderer.
- Improve documentation
- Support other platforms such as MacOS, Windows, Linux and Web
- Add search functionality
- Improve performance on zooming, page changing
- Improve image quality
- Write more test

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
