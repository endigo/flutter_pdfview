import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import 'pdfview_flutter.dart';

/// Interface for callbacks made by [PDFViewPlatformController].
///
/// The webview plugin implements this class, and passes an instance to the [PDFViewPlatformController].
/// [PDFViewPlatformController] is notifying this handler on events that happened on the platform's webview.
abstract class PDFViewPlatformCallbacksHandler {
  void onRender(int pages);
  void onPageChanged(int page, int total);
  void onError(dynamic error);
  void onPageError(int page, dynamic error);
}

/// Interface for talking to the webview's platform implementation.
///
/// An instance implementing this interface is passed to the `onPDFViewPlatformCreated` callback that is
/// passed to [PDFViewPlatformBuilder#onPDFViewPlatformCreated].
///
/// Platform implementations that live in a separate package should extend this class rather than
/// implement it as pdfview_flutter does not consider newly added methods to be breaking changes.
/// Extending this class (using `extends`) ensures that the subclass will get the default
/// implementation, while platform implementations that `implements` this interface will be broken
/// by newly added [WebViewPlatformController] methods.
abstract class PDFViewPlatformController {
  PDFViewPlatformController(PDFViewPlatformCallbacksHandler handler);

  Future<int> pageCount() async {
    throw UnimplementedError(
        "PDFView pageCount is not implemented on the current platform");
  }

  Future<int> currentPage() async {
    throw UnimplementedError(
        "PDFView currentPage is not implemented on the current platform");
  }

  Future<bool> setPage(int page) async {
    throw UnimplementedError(
        "PDFView setPage is not implemented on the current platform");
  }

  /// Updates the webview settings.
  ///
  /// Any non null field in `settings` will be set as the new setting value.
  /// All null fields in `settings` are ignored.
  Future<void> updateSettings(PDFSettings setting) {
    throw UnimplementedError(
        "WebView updateSettings is not implemented on the current platform");
  }
}

/// A single setting for configuring a PDFViewPlatform which may be absent.
class PDFSetting<T> {
  /// Constructs an absent setting instance.
  ///
  /// The [isPresent] field for the instance will be false.
  ///
  /// Accessing [value] for an absent instance will throw.
  PDFSetting.absent()
      : _value = null,
        isPresent = false;

  /// Constructs a setting of the given `value`.
  ///
  /// The [isPresent] field for the instance will be true.
  PDFSetting.of(T value)
      : _value = value,
        isPresent = true;

  final T _value;

  /// The setting's value.
  ///
  /// Throws if [WebSetting.isPresent] is false.
  T get value {
    if (!isPresent) {
      throw StateError('Cannot access a value of an absent WebSetting');
    }
    assert(isPresent);
    return _value;
  }

  /// True when this web setting instance contains a value.
  ///
  /// When false the [WebSetting.value] getter throws.
  final bool isPresent;

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) return false;
    final PDFSetting<T> typedOther = other;
    return typedOther.isPresent == isPresent && typedOther._value == _value;
  }

  @override
  int get hashCode => hashValues(_value, isPresent);
}

/// Settings for configuring a WebViewPlatform.
///
/// Initial settings are passed as part of [CreationParams], settings updates are sent with
/// [WebViewPlatform#updateSettings].
///
/// The `userAgent` parameter must not be null.
class PDFSettings {
  /// Construct an instance with initial settings. Future setting changes can be
  /// sent with [PDFViewPlatform#updateSettings].
  PDFSettings({
    this.enableSwipe,
    this.swipeHorizontal,
    this.password,
    this.nightMode,
    this.autoSpacing,
    this.pageFling,
    this.pageSnap,
    this.defaultPage,
    this.fitPolicy,
    this.fitEachPage,
  });

  final bool enableSwipe;
  final bool swipeHorizontal;
  final String password;
  final bool nightMode;
  final bool autoSpacing;
  final bool pageFling;
  final bool pageSnap;
  final int defaultPage;
  final FitPolicy fitPolicy;
  final bool fitEachPage;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'enableSwipe': enableSwipe,
      'swipeHorizontal': swipeHorizontal,
      'password': password,
      'nightMode': nightMode,
      'autoSpacing': autoSpacing,
      'pageFling': pageFling,
      'pageSnap': pageSnap,
      'defaultPage': defaultPage,
      'fitPolicy': fitPolicy.toString(),
      'fitEachPage': fitEachPage,
    };
  }

  Map<String, dynamic> updatesMap(PDFSettings newSettings) {
    final Map<String, dynamic> updates = <String, dynamic>{};
    if (enableSwipe != newSettings.enableSwipe) {
      updates['enableSwipe'] = newSettings.enableSwipe;
    }
    if (pageFling != newSettings.pageFling) {
      updates['pageFling'] = newSettings.pageFling;
    }
    if (pageSnap != newSettings.pageSnap) {
      updates['pageSnap'] = newSettings.pageSnap;
    }

    return updates;
  }

  @override
  String toString() {
    return 'PDFSettings(enableSwipe: $enableSwipe, swipeHorizontal: $swipeHorizontal, password: $password, nightMode: $nightMode, autoSpacing: $autoSpacing, pageFling: $pageFling, pageSnap: $pageSnap, defaultPage: $defaultPage, fitPolicy: $fitPolicy, fitEachPage: $fitEachPage)';
  }
}

/// Configuration to use when creating a new [PDFViewPlatformController].
///
/// The `autoMediaPlaybackPolicy` parameter must not be null.
class CreationParams {
  /// Constructs an instance to use when creating a new
  /// [WebViewPlatformController].
  ///
  /// The `autoMediaPlaybackPolicy` parameter must not be null.
  CreationParams({
    this.filePath,
    this.settings,
  });

  final String filePath;

  /// The initial [PDFSettings] for the new webview.
  ///
  /// This can later be updated with [PDFViewPlatformController.updateSettings].
  final PDFSettings settings;

  /// Which restrictions apply on automatic media playback.
  @override
  String toString() {
    return '$runtimeType(initialUrl: $filePath, settings: $settings)';
  }
}

typedef PDFViewPlatformCreatedCallback = void Function(
    PDFViewPlatformController pdfViewPlatformController);

/// Interface for a platform implementation of a WebView.
///
/// [PDFView.platform] controls the builder that is used by [PDFView].
/// [AndroidPDFViewPlatform] and [CupertinoPDFbViewPlatform] are the default implementations
/// for Android and iOS respectively.
abstract class PDFViewPlatform {
  /// Builds a new PDFView.
  ///
  /// Returns a Widget tree that embeds the created webview.
  ///
  /// `creationParams` are the initial parameters used to setup the webview.
  ///
  /// `pdfViewPlatformHandler` will be used for handling callbacks that are made by the created
  /// [PDFViewPlatformController].
  ///
  /// `onPDFViewPlatformCreated` will be invoked after the platform specific [PDFViewPlatformController]
  /// implementation is created with the [PDFViewPlatformController] instance as a parameter.
  ///
  /// `gestureRecognizers` specifies which gestures should be consumed by the pdf view.
  /// It is possible for other gesture recognizers to be competing with the pdf view on pointer
  /// events, e.g if the pdf view is inside a [ListView] the [ListView] will want to handle
  /// vertical drags. The pdf view will claim gestures that are recognized by any of the
  /// recognizers on this list.
  /// When `gestureRecognizers` is empty or null, the pdf view will only handle pointer events for gestures that
  /// were not claimed by any other gesture recognizer.
  ///
  /// `pdfViewPlatformHandler` must not be null.
  Widget build({
    BuildContext context,
    CreationParams creationParams,
    @required PDFViewPlatformCallbacksHandler pdfViewPlatformCallbacksHandler,
    PDFViewPlatformCreatedCallback onPDFViewPlatformCreated,
    Set<Factory<OneSequenceGestureRecognizer>> gestureRecognizers,
  });
}
