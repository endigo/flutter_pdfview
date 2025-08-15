# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Flutter plugin that provides native PDF viewing capabilities for iOS and Android platforms. The plugin wraps platform-specific PDF rendering libraries:
- **iOS**: Uses native PDFKit (iOS 11.0+)
- **Android**: Uses AndroidPdfViewer library (com.github.mhiew:android-pdf-viewer:3.2.0-beta.3)

## Key Commands

### Development & Testing
```bash
# Install dependencies
flutter pub get

# Run tests
flutter test

# Run tests for a specific file
flutter test test/flutter_pdfview_test.dart

# Analyze code
flutter analyze

# Format code
dart format .
```

### Example App
```bash
# Run the example app
cd example
flutter pub get
flutter run

# Build example for specific platform
flutter build ios
flutter build apk
```

### Publishing
```bash
# Dry run before publishing
flutter pub publish --dry-run

# Publish to pub.dev
flutter pub publish
```

## Architecture

### Plugin Structure

The plugin follows Flutter's federated plugin architecture with platform-specific implementations:

1. **Core Dart Interface** (`lib/flutter_pdfview.dart`):
   - `PDFView` widget - Main widget that creates platform views
   - `PDFViewController` - Controller for interacting with the PDF (page navigation, etc.)
   - Platform view creation using `UiKitView` (iOS) and `PlatformViewLink` (Android)

2. **Android Implementation** (`android/src/main/java/io/endigo/plugins/pdfviewflutter/`):
   - `PDFViewFlutterPlugin.java` - Plugin registration
   - `FlutterPDFView.java` - Android view implementation wrapping AndroidPdfViewer
   - `PDFViewFactory.java` - Factory for creating platform views
   - `PDFLinkHandler.java` - Handles PDF link navigation

3. **iOS Implementation** (`ios/flutter_pdfview/Sources/flutter_pdfview/`):
   - `PDFViewFlutterPlugin.m` - Plugin registration
   - `FlutterPDFView.m` - iOS view implementation using PDFKit
   - Uses PDFView from PDFKit framework for rendering

### Communication Flow

1. Flutter app creates `PDFView` widget with configuration
2. Platform view is created via `plugins.endigo.io/pdfview` channel
3. Native implementation renders PDF and sends callbacks via method channel
4. Events flow back to Flutter: `onRender`, `onPageChanged`, `onError`, etc.

### Key Features

- **File Loading**: From file path or binary data (Uint8List)
- **Navigation**: Page navigation, swipe gestures, horizontal/vertical scrolling
- **Rendering Options**: Night mode, auto-spacing, page snap, fit policies
- **Security**: Password-protected PDF support
- **Callbacks**: Page change, render complete, error handling, link handling
- **Controller Methods**: `getPageCount()`, `getCurrentPage()`, `setPage()`

## Platform-Specific Considerations

### iOS
- Minimum iOS version: 11.0 (PDFKit requirement)
- Uses Swift Package Manager for dependency management
- Background color handling uses deprecated `.value` method (as of v1.4.1+1)

### Android
- Minimum SDK: 21
- Compile SDK: 35
- Uses AndroidX libraries
- ProGuard rules included for release builds
- Gradle 8.1.0 build tools

## Testing Approach

Tests are located in `test/flutter_pdfview_test.dart` and include:
- Widget creation and configuration tests
- Settings validation tests
- Error handling tests
- Mock method channel for platform communication

The example app (`example/lib/main.dart`) provides comprehensive testing scenarios:
- Loading from assets
- Loading from URL
- Corrupted PDF handling
- Landscape PDF rendering
- PDF with links

## Common Development Tasks

### Adding a New Feature
1. Define the feature in the Dart interface (`lib/flutter_pdfview.dart`)
2. Implement in Android (`android/src/main/java/`)
3. Implement in iOS (`ios/flutter_pdfview/Sources/`)
4. Add tests in `test/flutter_pdfview_test.dart`
5. Update example app to demonstrate the feature
6. Update README.md with feature documentation

### Debugging Platform Code
- **Android**: Open `android/` in Android Studio, attach debugger
- **iOS**: Open `example/ios/Runner.xcworkspace` in Xcode, use breakpoints

### Version Updates
1. Update version in `pubspec.yaml`
2. Update CHANGELOG.md with changes
3. Run tests and example app
4. Publish using `flutter pub publish`