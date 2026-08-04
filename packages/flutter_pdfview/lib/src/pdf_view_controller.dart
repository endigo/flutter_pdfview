part of '../flutter_pdfview.dart';

/// Controls a [PDFView] that has been created on the native side.
///
/// An instance is handed to [PDFView.onViewCreated] once the platform view is
/// ready. The controller becomes inert after [dispose] has been called, which
/// happens automatically when the owning [PDFView] leaves the tree or loads a
/// different document.
///
/// Every method forwards to the [PdfViewPlatformController] created by the
/// active [FlutterPdfViewPlatform].
class PDFViewController {
  PDFViewController._(
    this._platform,
    PDFView widget, {
    PdfColorMode resolvedColorMode = PdfColorMode.light,
  }) {
    _settings = _settingsFromWidget(widget, resolvedColorMode: resolvedColorMode);
    // The platform controller may have been built with callbacks captured on an
    // earlier build; re-point it at the widget this controller is created for.
    _platform.updateCallbacks(_callbacksFromWidget(widget));
  }

  /// Test-only constructor so unit tests can exercise the method channel
  /// without a real platform view.
  @visibleForTesting
  factory PDFViewController.test(
    int id,
    PDFView widget, {
    PdfColorMode resolvedColorMode = PdfColorMode.light,
  }) => PDFViewController._(
    MethodChannelPdfViewController(id, _callbacksFromWidget(widget)),
    widget,
    resolvedColorMode: resolvedColorMode,
  );

  final PdfViewPlatformController _platform;

  late PdfViewSettings _settings;

  /// Detaches the controller from the native view and stops delivering
  /// callbacks.
  ///
  /// Called automatically by [PDFView]; there is normally no need to call it
  /// directly.
  void dispose() => _platform.dispose();

  /// Returns the number of pages in the loaded document.
  Future<int?> getPageCount() => _platform.getPageCount();

  /// Returns the size, in points, of the page that is currently displayed.
  Future<Size> getCurrentPageSize() => _platform.getCurrentPageSize();

  /// Returns the current scroll offset of the document.
  ///
  /// Waits for any pending [setPosition] calls to settle first, so the returned
  /// value always reflects the latest requested position.
  Future<Offset> getPosition() => _platform.getPosition();

  /// Returns the current zoom scale of the document.
  ///
  /// Waits for any pending [setScale] calls to settle first, so the returned
  /// value always reflects the latest requested scale.
  Future<double> getScale() => _platform.getScale();

  /// Scrolls the document to [position] and returns whether the native view
  /// accepted the new offset.
  Future<bool> setPosition(Offset position) => _platform.setPosition(position);

  /// Zooms the document to [scale] and returns whether the native view accepted
  /// the new scale.
  Future<bool> setScale(double scale) => _platform.setScale(scale);

  /// Sets the minimum, middle and maximum zoom levels of the native view.
  ///
  /// Returns whether the limits were applied.
  Future<bool> setZoomLimits(double minZoom, double midZoom, double maxZoom) =>
      _platform.setZoomLimits(minZoom, midZoom, maxZoom);

  /// Captures the currently visible page and writes it to [fileName].
  ///
  /// Returns the path of the written image, or an empty string on failure.
  Future<String> getScreenshot(String fileName) => _platform.getScreenshot(fileName);

  /// Reopens the current document with [password] and returns whether it is now
  /// unlocked.
  ///
  /// The document is reloaded in place, so a wrong password can be retried
  /// without recreating the platform view; each failure reports
  /// [PDFPasswordFailure.incorrect] through [PDFView.onPasswordRequired].
  /// Resolves once the native viewer has finished reloading. An unencrypted
  /// document simply reloads and returns `true`.
  Future<bool> unlock(String password) => _platform.unlock(password);

  /// Reloads the current document and returns whether the reload succeeded.
  Future<bool> reload() => _platform.reload();

  /// Returns the zero-based index of the page that is currently displayed.
  Future<int?> getCurrentPage() => _platform.getCurrentPage();

  /// Jumps to the zero-based [page] and returns whether the jump succeeded.
  Future<bool?> setPage(int page) => _platform.setPage(page);

  Future<void> _updateWidget(PDFView widget, {required PdfColorMode resolvedColorMode}) async {
    // Refresh callbacks even when no setting changed, so the native view never
    // dispatches into closures from a previous build.
    _platform.updateCallbacks(_callbacksFromWidget(widget));
    await _updateSettings(_settingsFromWidget(widget, resolvedColorMode: resolvedColorMode));
  }

  Future<void> _updateSettings(PdfViewSettings setting) async {
    final Map<String, dynamic> updateMap = _settings.updatesMap(setting);
    if (updateMap.isEmpty) {
      return;
    }
    _settings = setting;
    return _platform.updateSettings(updateMap);
  }
}
