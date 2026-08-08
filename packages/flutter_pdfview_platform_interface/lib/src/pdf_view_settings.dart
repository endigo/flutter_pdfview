import 'dart:ui' show Color;

import 'types.dart';

/// A snapshot of the mutable settings of a PDF view.
///
/// Used both to build the creation parameters for the native view and to compute
/// the delta that has to be pushed to it when the owning widget is rebuilt with
/// different settings. The key names produced by [toMap] and [updatesMap] are the
/// wire format shared by every platform implementation.
///
/// [colorMode] is always the **resolved** mode ([PdfColorMode.light] or
/// [PdfColorMode.dark]); [PdfColorMode.system] is resolved by the app-facing
/// package from the ambient theme before a settings snapshot is taken.
class PdfViewSettings {
  /// Creates a settings snapshot.
  PdfViewSettings({
    this.enableSwipe,
    this.swipeHorizontal,
    this.showScrollIndicators,
    this.password,
    this.nightMode,
    this.colorMode = PdfColorMode.light,
    this.autoSpacing,
    this.pageFling,
    this.pageSnap,
    this.enableAntialiasing,
    this.useBestQuality,
    this.enableRenderDuringScale,
    this.thumbnailRatio,
    this.defaultPage,
    this.fitPolicy,
    this.pageAlignment,
    this.preventLinkNavigation,
    this.backgroundColor,
    this.maxZoom,
    this.minZoom,
  }) : assert(
         colorMode != PdfColorMode.system,
         'system must be resolved to light or dark before building settings',
       );

  /// Whether the user can swipe to change pages.
  final bool? enableSwipe;

  /// Whether swiping changes pages horizontally rather than vertically.
  final bool? swipeHorizontal;

  /// Whether the native viewer shows scroll indicators.
  final bool? showScrollIndicators;

  /// The password used to open an encrypted document.
  final String? password;

  /// Legacy night-mode flag, kept for native builds that predate [colorMode].
  final bool? nightMode;

  /// Resolved color mode ([PdfColorMode.light] or [PdfColorMode.dark]).
  final PdfColorMode colorMode;

  /// Whether the viewer adds spacing (page breaks) between pages.
  final bool? autoSpacing;

  /// Whether pages can be flung.
  final bool? pageFling;

  /// Whether the viewer snaps to a page after scrolling.
  final bool? pageSnap;

  /// Whether page bitmaps are composited with anti-aliasing (Android only).
  final bool? enableAntialiasing;

  /// Whether full-color ARGB_8888 page bitmaps are used (Android only).
  final bool? useBestQuality;

  /// Whether page tiles are re-rasterized during a pinch (Android only).
  final bool? enableRenderDuringScale;

  /// Full-page preview scale used while high-res tiles load (Android only).
  final double? thumbnailRatio;

  /// The zero-based page displayed when the document is loaded.
  final int? defaultPage;

  /// How each page is scaled to the viewport.
  final FitPolicy? fitPolicy;

  /// How a document shorter than the viewport is placed inside it.
  final PageAlignment? pageAlignment;

  /// Whether tapping a link reports it instead of opening it.
  final bool? preventLinkNavigation;

  /// The background color drawn behind the document.
  final Color? backgroundColor;

  /// Maximum zoom level.
  final double? maxZoom;

  /// Minimum zoom level.
  final double? minZoom;

  /// Serializes every setting into the creation-parameter wire format.
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'enableSwipe': enableSwipe,
      'swipeHorizontal': swipeHorizontal,
      'showScrollIndicators': showScrollIndicators,
      'password': password,
      // Kept for older native builds that only understand nightMode.
      'nightMode': nightMode,
      'colorMode': colorMode.name,
      'autoSpacing': autoSpacing,
      'pageFling': pageFling,
      'pageSnap': pageSnap,
      'enableAntialiasing': enableAntialiasing,
      'useBestQuality': useBestQuality,
      'enableRenderDuringScale': enableRenderDuringScale,
      'thumbnailRatio': thumbnailRatio,
      'defaultPage': defaultPage,
      'fitPolicy': fitPolicy.toString(),
      'pageAlignment': pageAlignment.toString(),
      'preventLinkNavigation': preventLinkNavigation,
      'backgroundColor': backgroundColor?.toARGB32(),
      'maxZoom': maxZoom,
      'minZoom': minZoom,
    };
  }

  /// Returns only the settings that differ between `this` and [newSettings].
  ///
  /// Settings that the native side cannot update in place are deliberately left
  /// out of the diff.
  ///
  /// [backgroundColor] is omitted from the map when the new value is `null`
  /// (clearing back to null at runtime leaves the last color on screen).
  Map<String, dynamic> updatesMap(PdfViewSettings newSettings) {
    final Map<String, dynamic> updates = <String, dynamic>{};
    if (enableSwipe != newSettings.enableSwipe) {
      updates['enableSwipe'] = newSettings.enableSwipe;
    }
    if (colorMode != newSettings.colorMode) {
      updates['colorMode'] = newSettings.colorMode.name;
    }
    if (pageFling != newSettings.pageFling) {
      updates['pageFling'] = newSettings.pageFling;
    }
    if (pageSnap != newSettings.pageSnap) {
      updates['pageSnap'] = newSettings.pageSnap;
    }
    if (preventLinkNavigation != newSettings.preventLinkNavigation) {
      updates['preventLinkNavigation'] = newSettings.preventLinkNavigation;
    }
    if (pageAlignment != newSettings.pageAlignment) {
      updates['pageAlignment'] = newSettings.pageAlignment.toString();
    }
    if (password != newSettings.password) {
      updates['password'] = newSettings.password;
    }
    if (maxZoom != newSettings.maxZoom) {
      updates['maxZoom'] = newSettings.maxZoom;
    }
    if (minZoom != newSettings.minZoom) {
      updates['minZoom'] = newSettings.minZoom;
    }
    if (backgroundColor != newSettings.backgroundColor) {
      final Color? bg = newSettings.backgroundColor;
      if (bg != null) {
        updates['backgroundColor'] = bg.toARGB32();
      }
      // Present-with-null is omitted; natives keep the previous color.
    }
    return updates;
  }
}
