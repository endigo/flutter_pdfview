part of '../flutter_pdfview.dart';

/// A snapshot of the mutable [PDFView] settings.
///
/// Used both to build the creation parameters for the native view and to compute
/// the delta that has to be pushed over the method channel when the widget is
/// rebuilt with different settings.
///
/// [colorMode] is always the **resolved** mode (`light` or `dark`); [PdfColorMode.system]
/// is resolved in Dart from the ambient [Theme] before a settings snapshot is taken.
class _PDFViewSettings {
  _PDFViewSettings({
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
    this.preventLinkNavigation,
    this.backgroundColor,
    this.maxZoom,
    this.minZoom,
  });

  /// Builds a settings snapshot from [widget].
  ///
  /// [resolvedColorMode] must already be [PdfColorMode.light] or
  /// [PdfColorMode.dark] (never [PdfColorMode.system]).
  static _PDFViewSettings fromWidget(PDFView widget, {required PdfColorMode resolvedColorMode}) {
    assert(
      resolvedColorMode != PdfColorMode.system,
      'system must be resolved before building settings',
    );
    return _PDFViewSettings(
      enableSwipe: widget.enableSwipe,
      swipeHorizontal: widget.swipeHorizontal,
      showScrollIndicators: widget.showScrollIndicators,
      password: widget.password,
      nightMode: widget.nightMode,
      colorMode: resolvedColorMode,
      autoSpacing: widget.autoSpacing,
      pageFling: widget.pageFling,
      pageSnap: widget.pageSnap,
      enableAntialiasing: widget.enableAntialiasing,
      useBestQuality: widget.useBestQuality,
      enableRenderDuringScale: widget.enableRenderDuringScale,
      thumbnailRatio: widget.thumbnailRatio,
      defaultPage: widget.defaultPage,
      fitPolicy: widget.fitPolicy,
      preventLinkNavigation: widget.preventLinkNavigation,
      backgroundColor: widget.backgroundColor,
      maxZoom: widget.maxZoom,
      minZoom: widget.minZoom,
    );
  }

  final bool? enableSwipe;
  final bool? swipeHorizontal;
  final bool? showScrollIndicators;
  final String? password;
  final bool? nightMode;

  /// Resolved color mode (`light` or `dark`) sent to the native view.
  final PdfColorMode colorMode;

  final bool? autoSpacing;
  final bool? pageFling;
  final bool? pageSnap;
  final bool? enableAntialiasing;
  final bool? useBestQuality;
  final bool? enableRenderDuringScale;
  final double? thumbnailRatio;
  final int? defaultPage;
  final FitPolicy? fitPolicy;
  final bool? preventLinkNavigation;

  final Color? backgroundColor;

  final double? maxZoom;
  final double? minZoom;

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
  Map<String, dynamic> updatesMap(_PDFViewSettings newSettings) {
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
