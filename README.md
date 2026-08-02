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
  flutter_pdfview: 1.4.5-beta.5
```

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
| onError               |   ✅    | ✅  |      `null`       |
| onPageError           |   ✅    | ❌  |      `null`       |
| onLinkHandle          |   ✅    | ✅  |      `null`       |
| gestureRecognizers    |   ✅    | ✅  |      `null`       |
| filePath              |   ✅    | ✅  |                   |
| pdfData               |   ✅    | ✅  |                   |
| fitPolicy             |   ✅    | ✅  | `FitPolicy.WIDTH` |
| enableSwipe           |   ✅    | ✅  |      `true`       |
| swipeHorizontal       |   ✅    | ✅  |      `false`      |
| password              |   ✅    | ✅  |      `null`       |
| nightMode             |   ✅    | ❌  |      `false`      |
| autoSpacing*          |   ✅    | ✅  |      `true`       |
| pageFling             |   ✅    | ✅  |      `true`       |
| pageSnap              |   ✅    | ❌  |      `true`       |
| preventLinkNavigation |   ✅    | ✅  |      `false`      |
| backgroundColor       |   ✅    | ✅  |      `null`       |
| minZoom               |   ✅    | ✅  |        1.0        |
| maxZoom               |   ✅    | ✅  |        4.0        |
| showScrollIndicators* |   ✅    | ✅  |      `false`      |

Notes:
- `showScrollIndicators` is ignored on iOS while horizontal page-flipping is active (`pageFling: true` together with `swipeHorizontal: true`).
- `autoSpacing` only adds gaps between pages. It does not change initial zoom or `fitPolicy` (fixed in [#150](https://github.com/endigo/flutter_pdfview/issues/150)).

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
  backgroundColor: Colors.grey,
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
