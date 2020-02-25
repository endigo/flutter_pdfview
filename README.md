# flutter_pdfview

Native PDF View for iOS and Android

# Use this package as a library

## 1. Depend on it

Add this to your package's pubspec.yaml file:

```
dependencies:
  flutter_pdfview: ^1.0.0+10
```

### 2. Install it

You can install packages from the command line:

with Flutter:

```
$ flutter packages get
```

Alternatively, your editor might support pub get or `flutter packages get`. Check the docs for your editor to learn more.

### 3. Setup

#### iOS

Opt-in to the embedded views preview by adding a boolean property to the app's `Info.plist` file
with the key `io.flutter.embedded_views_preview` and the value `YES`.

### 4. Import it

Now in your Dart code, you can use:

```
import 'package:flutter_pdfview/flutter_pdfview.dart';
```

## Options

| Name               | Android | iOS |      Default      |
| :----------------- | :-----: | :-: | :---------------: |
| defaultPage        |   ✅    | ✅  |        `0`        |
| onViewCreated      |   ✅    | ✅  |      `null`       |
| onRender           |   ✅    | ✅  |      `null`       |
| onPageChanged      |   ✅    | ✅  |      `null`       |
| onError            |   ✅    | ✅  |      `null`       |
| onPageError        |   ✅    | ❌  |      `null`       |
| gestureRecognizers |   ✅    | ✅  |      `null`       |
| filePath           |   ✅    | ✅  |                   |
| fitPolicy          |   ✅    | ❌  | `FitPolicy.WIDTH` |
| enableSwipe        |   ✅    | ✅  |      `true`       |
| swipeHorizontal    |   ✅    | ✅  |      `false`      |
| password           |   ✅    | ✅  |      `null`       |
| nightMode          |   ✅    | ❌  |      `false`      |
| password           |   ✅    | ✅  |      `null`       |
| autoSpacing        |   ✅    | ✅  |      `true`       |
| pageFling          |   ✅    | ✅  |      `true`       |
| pageSnap           |   ✅    | ❌  |      `true`       |

## Controller Options

| Name           |     Description      | Parameters |     Return     |
| :------------- | :------------------: | :--------: | :------------: |
| getPageCount   | Get total page count |     -      | `Future<int>`  |
| getCurrentPage |   Get current page   |     -      | `Future<int>`  |
| setPage        |    Go to/Set page    | `int page` | `Future<bool>` |

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

# For production usage

If you use proguard, you should include this line.

```
-keep class com.shockwave.**
```

# Dependencies

### Android

[AndroidPdfViewer](https://github.com/barteksc/AndroidPdfViewer)

### iOS (only support> 11.0)

[PDFKit](https://developer.apple.com/documentation/pdfkit)
