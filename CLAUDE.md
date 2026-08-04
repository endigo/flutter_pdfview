# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Flutter plugin that provides native PDF viewing capabilities for iOS and Android platforms. The plugin wraps platform-specific PDF rendering libraries:
- **iOS**: Uses native PDFKit (iOS 13.0+), implemented in Swift
- **Android**: Uses AndroidPdfViewer library (com.github.marain87:AndroidPdfViewer:3.2.8), implemented in Kotlin

## Repository Layout

This is a **Dart pub workspace monorepo** driven by [Melos](https://melos.invertase.dev). The
repository root is not a publishable package — it only declares the workspace.

```
melos.yaml is inlined into the root pubspec.yaml (`melos:` key)
pubspec.yaml              workspace root: `workspace:` members + melos scripts
pubspec.lock              the single lockfile; member packages must not have one
scripts/                  repo-wide helper scripts
packages/
  flutter_pdfview/        THE PUBLISHED PACKAGE — all paths below are relative to here
    lib/
    android/
    ios/
    test/
    example/
```

Paths in the rest of this file are relative to `packages/flutter_pdfview/` unless they start
with `packages/`. Run `melos bootstrap` (or `flutter pub get` at the root) after changing any
`pubspec.yaml`; do not run `flutter pub get` inside a member package expecting an isolated
resolve.

Platform implementations currently live inside the app-facing package. The workspace exists so
they can be split into `flutter_pdfview_android` / `flutter_pdfview_ios` / `flutter_pdfview_web`
packages later without another repository move.

## Key Commands

### Development & Testing

Prefer the melos scripts from the repository root — they run across every package:

```bash
melos bootstrap        # resolve the workspace (needed after any pubspec change)
melos run analyze
melos run test         # Dart unit tests
melos run test:android # Robolectric/JUnit suite for the Android module
melos run format
melos run format-check
```

Working inside the package directly:

```bash
cd packages/flutter_pdfview

flutter test
flutter test test/flutter_pdfview_test.dart   # a single file
flutter analyze
dart format .
```

### Example App
```bash
cd packages/flutter_pdfview/example
flutter run

# Build example for specific platform
flutter build ios
flutter build apk
```

### Publishing
```bash
cd packages/flutter_pdfview
flutter pub publish --dry-run
flutter pub publish
```

`flutter pub publish` must be run from the package directory, not the workspace root — the root
is `publish_to: none`. The `Publish to pub.dev` GitHub workflow already sets
`working-directory: packages/flutter_pdfview`.

## Architecture

### Plugin Structure

1. **Core Dart API** (`lib/flutter_pdfview.dart`):
   - A single library; everything under `lib/src/` is a `part` of it, not an importable library.
     Adding a file there means adding a matching `part` directive to `lib/flutter_pdfview.dart`.
   - `lib/src/pdf_view.dart` — the `PDFView` widget; creates platform views via `UiKitView` (iOS)
     and `PlatformViewLink` + `initExpensiveAndroidView` (Android hybrid composition)
   - `lib/src/pdf_view_controller.dart` — `PDFViewController` plus the incoming method-call
     handler that dispatches native callbacks
   - `lib/src/pdf_view_settings.dart` — `PdfViewSettings`, creation-param serialization, and the
     runtime diffing that pushes only changed settings without remounting
   - `lib/src/types.dart` — enums and callback typedefs (`FitPolicy`, `PageAlignment`,
     `PdfColorMode`, ...)

2. **Android Implementation** (`android/src/main/kotlin/io/endigo/plugins/pdfviewflutter/`):
   - `PDFViewFlutterPlugin.kt` - Plugin registration
   - `FlutterPDFView.kt` - Android view implementation wrapping AndroidPdfViewer
   - `PDFViewFactory.kt` - Factory for creating platform views
   - `PDFLinkHandler.kt` - Handles PDF link navigation
   - `PdfColorMatrix.kt` - Luminance-preserving inversion for dark mode

3. **iOS Implementation** (`ios/flutter_pdfview/Sources/flutter_pdfview/`):
   - `FlutterPDFView.swift` - iOS view implementation using PDFKit
   - Plugin registration keeps the `FLTPDFViewFlutterPlugin` class name for compatibility
   - A small Objective-C shim target retains `NSException` guards around PDFKit

### Communication Flow

1. Flutter app creates `PDFView` widget with configuration
2. Platform view is created via `plugins.endigo.io/pdfview` channel
3. Native implementation renders PDF and sends callbacks via method channel
4. Events flow back to Flutter: `onRender`, `onPageChanged`, `onError`, `onTap`,
   `onPasswordRequired`, etc.

### Key Features

- **File Loading**: From file path or binary data (Uint8List)
- **Navigation**: Page navigation, swipe gestures, horizontal/vertical scrolling, page alignment
- **Rendering Options**: Color mode (light/dark/system), auto-spacing, page snap, fit policies
- **Security**: Password-protected PDF support with `onPasswordRequired` / `unlock()`
- **Callbacks**: Page change, render complete, error handling, link handling, tap
- **Controller Methods**: `getPageCount()`, `getCurrentPage()`, `setPage()`, `setZoomLimits()`,
  `getScreenshot()`, `unlock()`

## Platform-Specific Considerations

### iOS
- Minimum iOS version: 13.0 (as of v1.4.5)
- Swift 5.9; verified against both Swift Package Manager and CocoaPods
- Platform-view compositing limits apply: `ColorFiltered` / `ShaderMask` / `BackdropFilter`
  ancestors do not affect the native view (see #213)

### Android
- Minimum SDK: 21, Compile SDK: 36
- Kotlin, KGP 2.0.0, JVM target 17
- True hybrid composition (`initExpensiveAndroidView`)
- Uses AndroidX libraries; ProGuard rules included for release builds

## Testing Approach

Dart tests live in `test/` and cover creation params, settings diffing, fit/scale math, page
alignment, password handling, and the controller. Run with `melos run test`.

Android has a Robolectric/JUnit suite run via `melos run test:android` (wraps
`scripts/run_android_unit_tests.sh`). Keep it green.

`example/integration_test/` drives the real native viewers end to end.

The example app (`example/lib/main.dart`) provides comprehensive testing scenarios:
- Loading from assets and from URL
- Corrupted PDF handling
- Landscape PDF rendering
- PDF with links
- Password-protected documents

## Common Development Tasks

### Adding a New Feature
1. Define the feature in the Dart API under `lib/src/` (add a `part` directive if you add a file)
2. Implement in Android (`android/src/main/kotlin/`)
3. Implement in iOS (`ios/flutter_pdfview/Sources/`)
4. Add tests in `test/`, and Android unit tests alongside the existing suite
5. Update example app to demonstrate the feature
6. Update `packages/flutter_pdfview/README.md` and `CHANGELOG.md`

### Debugging Platform Code
- **Android**: Open `packages/flutter_pdfview/android/` in Android Studio, attach debugger
- **iOS**: Open `packages/flutter_pdfview/example/ios/Runner.xcworkspace` in Xcode, use breakpoints

### Version Updates
1. Update version in `packages/flutter_pdfview/pubspec.yaml`
2. Update `packages/flutter_pdfview/CHANGELOG.md` with changes
3. Run tests and example app
4. Publish from the package directory
