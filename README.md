# flutter_pdfview

Native PDF View for iOS and Android

# Use this package as a library

## 1. Depend on it

Add this to your package's pubspec.yaml file:

```
dependencies:
  flutter_pdfview: ^1.0.0+4
```


### 2. Install it

You can install packages from the command line:

with Flutter:

```
$ flutter packages get
```

Alternatively, your editor might support pub get or ```flutter packages get```. Check the docs for your editor to learn more.

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

| Name                    | Android  | iOS  |
| :---------------------- | :------: | :--: |
| onViewCreated           |    ✅    |  ✅ |
| onPageChanged           |    ✅    |  ✅ |
| gestureRecognizers      |    ✅    |  ✅ |
| filePath                |    ✅    |  ✅ |
| enableSwipe             |    ✅    |  ✅ |
| swipeHorizontal         |    ✅    |  ✅ |
| password                |    ✅    |  ✅ |
| nightMode               |    ✅    |  ❌ |
| password                |    ✅    |  ✅ |
| autoSpacing             |    ✅    |  ✅ |
| pageFling               |    ✅    |  ✅ |
| pageSnap                |    ✅    |  ❌ |

## Controller Options

| Name                    |    Description       | Parameters | Return         |
| :---------------------- | :------------------: | :--------: |:-------------: |
| getPageCount            | Get total page count | -          | `Future<int>`  |
| getCurrentPage          | Get current page     | -          | `Future<int>`  |
| setPage                 | Go to/Set page       | `int page` | `Future<bool>` |

# Dependencies
### Android
[AndroidPdfViewer](https://github.com/barteksc/AndroidPdfViewer)
### iOS (only support> 11.0)
[PDFKit](https://developer.apple.com/documentation/pdfkit)