## 1.5.0-beta.1

Native language migration on both platforms. Includes everything in `1.4.5`.

- **Android**: migrate the plugin implementation from Java to Kotlin (KGP 2.0.0, JVM target 17).
  Behavior verified by the existing 64-test native suite running against the Kotlin sources unchanged
- **iOS**: migrate the plugin implementation from Objective-C to Swift 5.9. The registered
  `FLTPDFViewFlutterPlugin` class name is preserved, `NSException` guards around PDFKit are kept via a
  small Objective-C shim target, and scroll observation moved to block-based KVO. Verified on both
  Swift Package Manager and CocoaPods (`pod lib lint`, dynamic + static)
- Fix a platform-view remount race: late creation callbacks from a disposed or remounted view can no
  longer complete the new controller with a stale instance
- Harden iOS `setZoomLimits` and align the podspec `swift_version`
- Fix [#175](https://github.com/endigo/flutter_pdfview/issues/175): `getScreenshot` no longer returns a
  white image under hybrid composition. Android captures via `PixelCopy` (with a software-layer
  `View.draw` fallback); iOS rasterizes the PDFKit layer and falls back to drawing the current
  `PDFPage` (drawing-cache / hierarchy snapshots are avoided on both platforms)
- No public Dart API changes

## 1.4.5

Stable release of the `1.4.5-beta.1` → `1.4.5-beta.5` line; no code changes since `1.4.5-beta.5`.

Highlights since `1.4.4` (see the beta sections below for the full list):

- **BREAKING**: minimum Flutter 3.32.0 / Dart 3.8.0
- **BREAKING**: Android platform views now use true hybrid composition (`initExpensiveAndroidView`) — fixes surface lock [#263](https://github.com/endigo/flutter_pdfview/issues/263), `EGL_NO_DISPLAY` crash [#280](https://github.com/endigo/flutter_pdfview/issues/280), blanking on rotation [#9](https://github.com/endigo/flutter_pdfview/issues/9) / dialogs [#182](https://github.com/endigo/flutter_pdfview/issues/182) / load [#298](https://github.com/endigo/flutter_pdfview/issues/298), and GPU glitches [#306](https://github.com/endigo/flutter_pdfview/issues/306)
- **BREAKING**: Android external PDF links only auto-launch `http`/`https`; other schemes are reported through `onLinkHandler` instead
- iOS: `fitPolicy` (WIDTH / HEIGHT / BOTH) implemented for Android parity, page fit decoupled from `autoSpacing` [#150](https://github.com/endigo/flutter_pdfview/issues/150), `onError` on bad passwords/documents [#211](https://github.com/endigo/flutter_pdfview/issues/211), white background and continuous scrolling [#204](https://github.com/endigo/flutter_pdfview/issues/204), Privacy Manifest [#271](https://github.com/endigo/flutter_pdfview/issues/271)
- Android: Java 17 toolchain [#334](https://github.com/endigo/flutter_pdfview/issues/334), dispose/memory-leak fixes [#261](https://github.com/endigo/flutter_pdfview/issues/261), absolute-path loading [#266](https://github.com/endigo/flutter_pdfview/issues/266), `libc++_shared.so` packaging [#287](https://github.com/endigo/flutter_pdfview/issues/287)
- New API: `minZoom` / `maxZoom` [#296](https://github.com/endigo/flutter_pdfview/issues/296), `showScrollIndicators` [#337](https://github.com/endigo/flutter_pdfview/issues/337), `onLoadComplete` / `onDraw`, `getCurrentPageSize()`, `getScreenshot()`, `getPosition()` / `setPosition()`, `getScale()` / `setScale()`, `reload()`, `setZoomLimits()` [#333](https://github.com/endigo/flutter_pdfview/pull/333)
- Document remount when `filePath` / `pdfData` changes [#181](https://github.com/endigo/flutter_pdfview/issues/181)

### Migration from 1.4.4

1. Raise your app to Flutter ≥ 3.32 and Dart ≥ 3.8.
2. Android PDF views now use expensive hybrid composition (true platform views); re-check layout and gesture behavior if you embed `PDFView` in complex widget trees.
3. Non-`http(s)` PDF links no longer auto-open — handle them yourself in `onLinkHandler`.

## 1.4.5-beta.5

- Fix [#150](https://github.com/endigo/flutter_pdfview/issues/150): iOS initial page fit no longer depends on `autoSpacing` (spacing vs zoom decoupled); re-fit after placeholder→real bounds and on rotation while preserving user zoom
- Implement `fitPolicy` (WIDTH / HEIGHT / BOTH) on iOS for parity with Android (iOS previously ignored the flag and always auto-fit the full page; default `FitPolicy.WIDTH` now matches Android)
- Add regression tests for [#150](https://github.com/endigo/flutter_pdfview/issues/150) creation-param independence (Dart iOS/Android + Android Robolectric) and iOS fit-scale formula oracle
- Make standalone Android unit tests runnable: `compileOnly` Flutter embedding jar, fix `android/settings.gradle`, add `scripts/run_android_unit_tests.sh`

## 1.4.5-beta.4

- **BREAKING**: Raise minimum Flutter version to 3.32.0 and Dart SDK to 3.8.0 (aligns with `flutter_lints` 6 and `formatter.page_width`)
- **Android**: switch platform views from texture hybrid composition (`initSurfaceAndroidView`) to true hybrid composition (`initExpensiveAndroidView`) — fixes `Surface was already locked!` [#263](https://github.com/endigo/flutter_pdfview/issues/263), `EGL_NO_DISPLAY` quick-open crash [#280](https://github.com/endigo/flutter_pdfview/issues/280), blank on rotation [#9](https://github.com/endigo/flutter_pdfview/issues/9), blank after dialogs [#182](https://github.com/endigo/flutter_pdfview/issues/182), blank on load [#298](https://github.com/endigo/flutter_pdfview/issues/298), and GPU glitches [#306](https://github.com/endigo/flutter_pdfview/issues/306)
- Fix Android layout direction to follow ambient `Directionality` (was hardcoded RTL)
- Fix #181: remount platform view when `filePath` / `pdfData` changes so a new PDF can load
- Fix #261: release Pdfium/PDFKit resources on dispose (Android recycle race + iOS observers/document/channel)
- Restrict Android external PDF link auto-launch to `http`/`https` (avoids `file://` crashes and unsafe schemes); still reports all schemes via `onLinkHandler`
- Serialize concurrent `setPosition`/`setScale` through a queue for any number of overlapping callers; null platform replies return `false`
- Compare `pdfData` via cached digests instead of a full per-byte scan on every rebuild
- Fix #268: avoid NaN CoreGraphics errors by initializing iOS `PDFView` with a non-zero frame
- Fix #204: iOS white background (not grey) and continuous vertical page scroll parity with Android
- Fix #266: load absolute filesystem paths via `fromFile` on Android (No content provider)
- Fix #287: `pickFirst` packaging for `libc++_shared.so` native merge conflicts
- Defer Android PDF load until the view has non-zero size; safer dispose before surface draw races
- Propagate `nightMode` setting updates to native Android view
- Document `EagerGestureRecognizer` for PDFView inside scrollables [#265](https://github.com/endigo/flutter_pdfview/issues/265)
- Fix Android external PDF links silently failing on API 30+ package visibility (`resolveActivity` pre-check)
- Fix controller deadlock: a failed `setPosition`/`setScale` call permanently hung all later position/scale calls
- Fix iOS silently showing a blank view for wrong/missing passwords — now fires `onError` (parity with Android)
- Fix iOS `getCurrentPage`/`onPageChanged` reporting a garbage index (`NSNotFound`) before a page is loaded
- Validate `thumbnailRatio` to (0, 1] (Dart assert + Android clamp) — out-of-range values crashed rendering
- Restructure Dart library into `lib/src/` part files; public API unchanged
- Adopt `flutter_lints` 6.0 with zero analyzer issues; dartdoc for the entire public API
- Expand unit tests: controller method channel, native→Dart callbacks, document remount, creation settings
- Add 64 Android native unit tests (Robolectric/JUnit): URI handling, param parsing, link handler, thumbnail clamp
- Replace broken example widget test with home-screen / PDFScreen chrome coverage
- Fix Android `setPage` resolving before the jump executes; reload pages when `nightMode` changes; handle unescaped `file:` URIs on iOS

## 1.4.5-beta.3

- Fixed issue #337: Added showScrollIndicators option to control native scroll indicator visibility.

## 1.4.5-beta.2

- Fix iOS PDF view reporting not ready when it is on initial load
- Add `minZoom` and `maxZoom` to the README.md
- Fix Android memory leak by recycling `PDFView` on dispose

## 1.4.5-beta.1

- Upgrade Java source/target compatibility from 1.8 to 17 [#334](https://github.com/endigo/flutter_pdfview/issues/334)
- Add iOS Privacy Manifest (PrivacyInfo.xcprivacy) [#271](https://github.com/endigo/flutter_pdfview/issues/271)
- Fix iOS `onError` callback not firing for invalid documents [#211](https://github.com/endigo/flutter_pdfview/issues/211)
- Fix iOS `onPageChanged` not triggered on first load [#66](https://github.com/endigo/flutter_pdfview/issues/66)
- Fix iOS landscape PDF wrong initial zoom by preserving user-configured max scale factor [#247](https://github.com/endigo/flutter_pdfview/issues/247)
- Add configurable `maxZoom` and `minZoom` parameters [#296](https://github.com/endigo/flutter_pdfview/issues/296)
- **BREAKING**: Raise minimum Flutter version to 3.27.0 and Dart SDK to 3.6.0
- Migrate `backgroundColor` serialization from deprecated `Color.value` to `Color.toARGB32()`
- Update iOS deployment target to 13.0 in podspec and Package.swift (aligns with Flutter's own iOS 13.0+ requirement)
- Fix example app build error with undefined `nightModeBackgroundColor` parameter
- Add `onLoadComplete` callback triggered when the PDFView has loaded its document [#333](https://github.com/endigo/flutter_pdfview/pull/333) @JaseElder
- Add `onDraw` callback triggered on each draw within the PDFView [#333](https://github.com/endigo/flutter_pdfview/pull/333) @JaseElder
- Add `getCurrentPageSize()` controller method returning width and height of the loaded page [#333](https://github.com/endigo/flutter_pdfview/pull/333) @JaseElder
- Add `getScreenshot(String fileName)` controller method to save a PNG of the PDFView contents [#333](https://github.com/endigo/flutter_pdfview/pull/333) @JaseElder
- Add `getPosition()` and `setPosition(Offset position)` controller methods for the PDF top-left offset [#333](https://github.com/endigo/flutter_pdfview/pull/333) @JaseElder
- Add `getScale()` and `setScale(double scale)` controller methods for PDF zoom [#333](https://github.com/endigo/flutter_pdfview/pull/333) @JaseElder
- Add `reload()` controller method to reload the PDF document [#333](https://github.com/endigo/flutter_pdfview/pull/333) @JaseElder
- Add `setZoomLimits(double minZoom, double midZoom, double maxZoom)` controller method [#333](https://github.com/endigo/flutter_pdfview/pull/333) @JaseElder
- Add safe unboxing and completers for get/set viewport position to avoid contention and race conditions [#333](https://github.com/endigo/flutter_pdfview/pull/333) @JaseElder
- Upgrade AndroidPdfViewer to 3.2.8 [#333](https://github.com/endigo/flutter_pdfview/pull/333) @JaseElder
- Fix deprecated color `.value` usage [#333](https://github.com/endigo/flutter_pdfview/pull/333) @JaseElder

## 1.4.4

- Fixes an Android rendering [#330](https://github.com/endigo/flutter_pdfview/pull/330) @TimelessLin

## 1.4.3

- Stable Android 16KB page size support
- Fix iPad scroll direction crash issue [#325](https://github.com/endigo/flutter_pdfview/issues/325)
  - Add defensive scroll view configuration for iPad devices
  - Implement gesture conflict resolution to prevent "Failed to determine navigation direction for scroll" errors
  - Add safe layout updates during scrolling animations
  - Use more conservative scroll settings on iPad to improve compatibility
- Add iPad Safe Mode example in demo app for recommended PDF configurations on iPad

## 1.4.2-beta.1

- Add Android 16KB page size support [#321](https://github.com/endigo/flutter_pdfview/pull/321) @opsenes
- Update Android PDF viewer library to `io.github.oothp:android-pdf-viewer:3.2.0-beta05`
- Upgrade Android Gradle Plugin to 8.11.1
- Upgrade Gradle wrapper to 8.14.3
- Enable AndroidX support

## 1.4.1+1

- Revert `.toARGB32()` to depricated `.value`

## 1.4.1

- Fixed memory leak on iOS [#315](https://github.com/endigo/flutter_pdfview/pull/315) @flbaue

## 1.4.0+1

- Add error handling on background color in iOS

## 1.4.0

- Add support for Swift Package Manager

## 1.3.4

- Add support for background color [278](https://github.com/endigo/flutter_pdfview/pull/278) @bobbybun

## 1.3.3

- hotfix: Crash on iOS 18

## 1.3.2

- build.gradle namespace [#253](https://github.com/endigo/flutter_pdfview/pull/253) @DrBu7cher
-

## 1.3.1

- Upgrade compileSdkVersion to 33
- Upgrade sdk

## 1.3.0

- Upgrade android-pdf-viewer to beta.3

## 1.2.9

- Deprecate `fitEachPage`

## 1.2.8

- Add documentation on properties

## 1.2.7

- Downgrade android-pdf-viewer from beta.3 to beta.2
- Upgrade Gradle to 7.3.0

## 1.2.6

- Fixed defaultPage not working on iOS [#227](https://github.com/endigo/flutter_pdfview/pull/227) @wmatusiak

## 1.2.5

- Fixed invalid frame of PDFView on IOS [#201](https://github.com/endigo/flutter_pdfview/pull/201) @wmatusiak

## 1.2.4

- Change dependency for AndroidPdfViewer [#202](https://github.com/endigo/flutter_pdfview/pull/202) @oorfalimak

## 1.2.3

- Fixed the Initial Zoom bug in IOS [#192](https://github.com/endigo/flutter_pdfview/pull/192) @moazelsawaf

## 1.2.2

- Updated onDoubleTap on ios [#174](https://github.com/endigo/flutter_pdfview/pull/174) @The-Redhat

## 1.2.1

- Updated dependencies to be newest with latest flutter version.
- Update minimal version of flutter to 2.2.0
- Updated compileSdkVersion in Android gradle to 30 because in future new apps on Google Play will have to set at least compile version to 30
- Updated README [#148](https://github.com/endigo/flutter_pdfview/pull/148) @PcolBP

## 1.2.0

- Migration Android V2 Embedding & jCenter to mavenCentral [#147](https://github.com/endigo/flutter_pdfview/pull/147) @PcolBP

## 1.1.0

- Migrate to nullsafety, add compatible to Flutter 2.0 [#130](https://github.com/endigo/flutter_pdfview/pull/130) @stijnie2210

## 1.0.4

- Add support for reading PDF from byte data [#122](https://github.com/endigo/flutter_pdfview/pull/120) @tvh, @deakjahn

## 1.0.3+8

- Fixed setPage return value from int to bool on iOS [#120](https://github.com/endigo/flutter_pdfview/pull/120) @daisuke310vvv

## 1.0.3+7

- Fixed setPage return value from int to bool on iOS [#118](https://github.com/endigo/flutter_pdfview/pull/118) @daisuke310vvv

## 1.0.3+6

- Upgrade Android SDK version to 29 [#114](https://github.com/endigo/flutter_pdfview/pull/114) @miguelslemos

## 1.0.3+5

- iOS proper scaling for PDF with pages on landscape-orientation [#104](https://github.com/endigo/flutter_pdfview/pull/104) @andresath

## 1.0.3+4

- Enable annotation on android [#103](https://github.com/endigo/flutter_pdfview/pull/103) @soul

## 1.0.3+3

- Remove print statement [#95](https://github.com/endigo/flutter_pdfview/pull/95) @krispypen
- Close [#94](https://github.com/endigo/flutter_pdfview/issues/94) @macitkaraca

## 1.0.3+2

- Add default proguard-rules.
- Closes [#87](https://github.com/endigo/flutter_pdfview/issues/87)

## 1.0.3+1

- Format lib/flutter_pdfview.dart

## 1.0.3

- [#81](https://github.com/endigo/flutter_pdfview/pull/81) add support for handle url navigation on flutter.

## 1.0.2+4

- [#78](https://github.com/endigo/flutter_pdfview/pull/78) fix unlimited zoom out in iOS. @daanporon

## 1.0.2+3

- Close [#72](https://github.com/endigo/flutter_pdfview/issues/72)
- Fix internal page links

## 1.0.2+2

- Close [#20](https://github.com/endigo/flutter_pdfview/issues/20)
- Add support tap on link inside the pdf

## 1.0.2+1

- Close [#67](https://github.com/endigo/flutter_pdfview/issues/67)

## 1.0.2

- pod_target_xcconfig suggested by @zhenpeng0hou

## 1.0.1

- Add support on FitPolicy on android

## 1.0.0+12

- FIX: plugin class name

## 1.0.0+11

- add defaultPage option

## 1.0.0+10

- [#36](https://github.com/endigo/flutter_pdfview/pull/36) support onError handlers
- update example with onError handler

## 1.0.0+9

- Avoid Android Native crash when file is not valid

## 1.0.0+8

- FIX: [#21](https://github.com/endigo/flutter_pdfview/issues/21)

## 1.0.0+7

- upgrade path_provider version

## 1.0.0+6

- FIX: onRender not works in iOS

## 1.0.0+5

- onRender handlers added
- onError, onPageError handlers added (Android only)
- Add example snippet in readme

## 1.0.0+4

- Add controller functions description in document

## 1.0.0+3

- Support `enableSwipe` in iOS

## 1.0.0+2

- Set correct scale in iOS

## 1.0.0+1

- Update pub description

## 1.0.0

- Initial Release
- Works better
