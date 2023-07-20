# flutter_pdfview

Native PDF View for iOS and Android

[![xscode](https://img.shields.io/badge/Available%20on-xs%3Acode-blue?style=?style=plastic&logo=appveyor&logo=data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAEAAAABACAMAAACdt4HsAAAAGXRFWHRTb2Z0d2FyZQBBZG9iZSBJbWFnZVJlYWR5ccllPAAAAAZQTFRF////////VXz1bAAAAAJ0Uk5T/wDltzBKAAAAlUlEQVR42uzXSwqAMAwE0Mn9L+3Ggtgkk35QwcnSJo9S+yGwM9DCooCbgn4YrJ4CIPUcQF7/XSBbx2TEz4sAZ2q1RAECBAiYBlCtvwN+KiYAlG7UDGj59MViT9hOwEqAhYCtAsUZvL6I6W8c2wcbd+LIWSCHSTeSAAECngN4xxIDSK9f4B9t377Wd7H5Nt7/Xz8eAgwAvesLRjYYPuUAAAAASUVORK5CYII=)](https://xscode.com/endigo/flutter_pdfview)
[![Latest compatibility result for Stable channel](https://img.shields.io/endpoint?url=https://pub.green/packages/flutter_pdfview/badge?channel=stable)](https://pub.green/packages/flutter_pdfview)
[![Latest compatibility result for Beta channel](https://img.shields.io/endpoint?url=https://pub.green/packages/flutter_pdfview/badge?channel=beta)](https://pub.green/packages/flutter_pdfview)
[![Latest compatibility result for Dev channel](https://img.shields.io/endpoint?url=https://pub.green/packages/flutter_pdfview/badge?channel=dev)](https://pub.green/packages/flutter_pdfview)

# Use this package as a library

## 1. Depend on it

Add this to your package's pubspec.yaml file:

```
dependencies:
  flutter_pdfview: ^1.2.7
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
| :-------------------- | :-----: | :-: | :---------------: |
| defaultPage           |   ✅    | ✅  |        `0`        |
| onViewCreated         |   ✅    | ✅  |      `null`       |
| onRender              |   ✅    | ✅  |      `null`       |
| onPageChanged         |   ✅    | ✅  |      `null`       |
| onError               |   ✅    | ✅  |      `null`       |
| onPageError           |   ✅    | ❌  |      `null`       |
| onLinkHandle          |   ✅    | ✅  |      `null`       |
| gestureRecognizers    |   ✅    | ✅  |      `null`       |
| filePath              |   ✅    | ✅  |                   |
| pdfData               |   ✅    | ✅  |                   |
| fitPolicy             |   ✅    | ❌  | `FitPolicy.WIDTH` |
| enableSwipe           |   ✅    | ✅  |      `true`       |
| swipeHorizontal       |   ✅    | ✅  |      `false`      |
| password              |   ✅    | ✅  |      `null`       |
| nightMode             |   ✅    | ❌  |      `false`      |
| password              |   ✅    | ✅  |      `null`       |
| autoSpacing           |   ✅    | ✅  |      `true`       |
| pageFling             |   ✅    | ✅  |      `true`       |
| pageSnap              |   ✅    | ❌  |      `true`       |
| preventLinkNavigation |   ✅    | ✅  |      `false`      |

## Controller Options

| Name           |     Description      | Parameters |     Return     |
| :------------- | :------------------: | :--------: | :------------: |
| getPageCount   | Get total page count |     -      | `Future<int>`  |
| getCurrentPage |   Get current page   |     -      | `Future<int>`  |
| setPage        |    Go to/Set page    | `int page`<br>`withAnimation` (**Optional**, only works for **Android**, defaults to `false`) | `Future<bool>` |

## Example

```dart
PDFView(
  filePath: path,
  enableSwipe: true,
  swipeHorizontal: true,
  autoSpacing: false,
  pageFling: false,
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
),
```

# Dependencies

### Android

[AndroidPdfViewer](https://github.com/barteksc/AndroidPdfViewer)

### iOS (only support> 11.0)

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

### Developer

- [endigo](https://github.com/endigo)
