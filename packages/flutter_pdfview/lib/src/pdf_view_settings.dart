part of '../flutter_pdfview.dart';

/// Builds the settings snapshot the platform interface consumes from [widget].
///
/// [resolvedColorMode] must already be [PdfColorMode.light] or
/// [PdfColorMode.dark] (never [PdfColorMode.system]); see
/// [_PDFViewState._resolveColorMode].
PdfViewSettings _settingsFromWidget(PDFView widget, {required PdfColorMode resolvedColorMode}) {
  assert(
    resolvedColorMode != PdfColorMode.system,
    'system must be resolved before building settings',
  );
  return PdfViewSettings(
    enableSwipe: widget.enableSwipe,
    swipeHorizontal: widget.swipeHorizontal,
    showScrollIndicators: widget.showScrollIndicators,
    password: widget.password,
    // ignore: deprecated_member_use_from_same_package
    nightMode: widget.nightMode,
    colorMode: resolvedColorMode,
    autoSpacing: widget.autoSpacing,
    spacing: widget.spacing,
    pageFling: widget.pageFling,
    pageSnap: widget.pageSnap,
    enableAntialiasing: widget.enableAntialiasing,
    useBestQuality: widget.useBestQuality,
    enableRenderDuringScale: widget.enableRenderDuringScale,
    thumbnailRatio: widget.thumbnailRatio,
    defaultPage: widget.defaultPage,
    fitPolicy: widget.fitPolicy,
    pageAlignment: widget.pageAlignment,
    preventLinkNavigation: widget.preventLinkNavigation,
    backgroundColor: widget.backgroundColor,
    maxZoom: widget.maxZoom,
    minZoom: widget.minZoom,
  );
}

/// Bundles the event callbacks declared on [widget] for the platform interface.
///
/// Rebuilt whenever the widget changes so a platform controller never dispatches
/// to a stale closure.
PdfViewCallbacks _callbacksFromWidget(PDFView widget) {
  return PdfViewCallbacks(
    onRender: widget.onRender,
    onPageChanged: widget.onPageChanged,
    onError: widget.onError,
    onPageError: widget.onPageError,
    onPasswordRequired: widget.onPasswordRequired,
    onLinkHandler: widget.onLinkHandler,
    onLoadComplete: widget.onLoadComplete,
    onDraw: widget.onDraw,
    onTap: widget.onTap,
  );
}
