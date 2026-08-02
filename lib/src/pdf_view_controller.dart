part of '../flutter_pdfview.dart';

/// Controls a [PDFView] that has been created on the native side.
///
/// An instance is handed to [PDFView.onViewCreated] once the platform view is
/// ready. The controller becomes inert after [dispose] has been called, which
/// happens automatically when the owning [PDFView] leaves the tree or loads a
/// different document.
class PDFViewController {
  PDFViewController._(int id, PDFView widget)
    : _channel = MethodChannel('plugins.endigo.io/pdfview_$id'),
      _widget = widget {
    _settings = _PDFViewSettings.fromWidget(widget);
    _channel.setMethodCallHandler(_onMethodCall);
  }

  /// Test-only constructor so unit tests can exercise the method channel
  /// without a real platform view.
  @visibleForTesting
  factory PDFViewController.test(int id, PDFView widget) => PDFViewController._(id, widget);

  final MethodChannel _channel;

  late _PDFViewSettings _settings;

  PDFView? _widget;

  /// Serializes concurrent [setPosition] calls (and [getPosition] waits) so
  /// platform order matches call order for any number of overlapping callers.
  Future<void> _setPositionQueue = Future<void>.value();

  /// Serializes concurrent [setScale] calls (and [getScale] waits).
  Future<void> _setScaleQueue = Future<void>.value();

  /// Detaches the controller from the native view and stops delivering
  /// callbacks.
  ///
  /// Called automatically by [PDFView]; there is normally no need to call it
  /// directly.
  void dispose() {
    _channel.setMethodCallHandler(null);
    _widget = null;
  }

  Future<bool?> _onMethodCall(MethodCall call) async {
    final PDFView? widget = _widget;
    if (widget == null) return null;

    switch (call.method) {
      case 'onRender':
        widget.onRender?.call(call.arguments['pages']);
        return null;
      case 'onPageChanged':
        widget.onPageChanged?.call(call.arguments['page'], call.arguments['total']);
        return null;
      case 'onError':
        widget.onError?.call(call.arguments['error']);
        return null;
      case 'onPageError':
        widget.onPageError?.call(call.arguments['page'], call.arguments['error']);
        return null;
      case 'onLinkHandler':
        widget.onLinkHandler?.call(call.arguments);
        return null;
      case 'onLoadComplete':
        widget.onLoadComplete?.call(call.arguments['pages']);
        return null;
      case 'onDraw':
        widget.onDraw?.call(
          call.arguments['pdfXOffset'],
          call.arguments['pdfYOffset'],
          call.arguments['pdfScale'],
        );
        return null;
    }
    throw MissingPluginException('${call.method} was invoked but has no handler');
  }

  /// Returns the number of pages in the loaded document.
  Future<int?> getPageCount() async {
    final int? pageCount = await _channel.invokeMethod('pageCount');
    return pageCount;
  }

  /// Returns the size, in points, of the page that is currently displayed.
  Future<Size> getCurrentPageSize() async {
    return _channel
        .invokeMethod('currentPageSize')
        .then((pageSize) => Size(pageSize[0] ?? 0, pageSize[1] ?? 0));
  }

  /// Returns the current scroll offset of the document.
  ///
  /// Waits for any pending [setPosition] calls to settle first, so the returned
  /// value always reflects the latest requested position.
  Future<Offset> getPosition() async {
    await _setPositionQueue;
    final position = await _channel.invokeMethod('getPosition');
    return Offset(position[0] ?? 0, position[1] ?? 0);
  }

  /// Returns the current zoom scale of the document.
  ///
  /// Waits for any pending [setScale] calls to settle first, so the returned
  /// value always reflects the latest requested scale.
  Future<double> getScale() async {
    await _setScaleQueue;
    final scale = await _channel.invokeMethod('getScale');
    return scale ?? 1;
  }

  /// Scrolls the document to [position] and returns whether the native view
  /// accepted the new offset.
  Future<bool> setPosition(Offset position) {
    final Completer<bool> result = Completer<bool>();
    _setPositionQueue = _setPositionQueue.then((_) async {
      try {
        final bool isSet =
            await _channel.invokeMethod<bool>('setPosition', <String, double>{
              'xPos': position.dx,
              'yPos': position.dy,
            }) ??
            false;
        if (!result.isCompleted) {
          result.complete(isSet);
        }
      } catch (error, stackTrace) {
        if (!result.isCompleted) {
          result.completeError(error, stackTrace);
        }
      }
    });
    // Keep the queue alive after a failure so later calls still run.
    _setPositionQueue = _setPositionQueue.catchError((Object _) {});
    return result.future;
  }

  /// Zooms the document to [scale] and returns whether the native view accepted
  /// the new scale.
  Future<bool> setScale(double scale) {
    final Completer<bool> result = Completer<bool>();
    _setScaleQueue = _setScaleQueue.then((_) async {
      try {
        final bool isSet =
            await _channel.invokeMethod<bool>('setScale', <String, double>{'scale': scale}) ??
            false;
        if (!result.isCompleted) {
          result.complete(isSet);
        }
      } catch (error, stackTrace) {
        if (!result.isCompleted) {
          result.completeError(error, stackTrace);
        }
      }
    });
    // Keep the queue alive after a failure so later calls still run.
    _setScaleQueue = _setScaleQueue.catchError((Object _) {});
    return result.future;
  }

  /// Sets the minimum, middle and maximum zoom levels of the native view.
  ///
  /// Returns whether the limits were applied.
  Future<bool> setZoomLimits(double minZoom, double midZoom, double maxZoom) async {
    return await _channel.invokeMethod<bool>('setZoomLimits', <String, dynamic>{
          'minZoom': minZoom,
          'midZoom': midZoom,
          'maxZoom': maxZoom,
        }) ??
        false;
  }

  /// Captures the currently visible page and writes it to [fileName].
  ///
  /// Returns the path of the written image, or an empty string on failure.
  Future<String> getScreenshot(String fileName) async {
    final String imageFileName =
        await _channel.invokeMethod<String>('getScreenshot', <String, dynamic>{
          'fileName': fileName,
        }) ??
        '';
    return imageFileName;
  }

  /// Reloads the current document and returns whether the reload succeeded.
  Future<bool> reload() async {
    final bool result = await _channel.invokeMethod<bool>('reload') ?? false;
    return result;
  }

  /// Returns the zero-based index of the page that is currently displayed.
  Future<int?> getCurrentPage() async {
    final int? currentPage = await _channel.invokeMethod('currentPage');
    return currentPage;
  }

  /// Jumps to the zero-based [page] and returns whether the jump succeeded.
  Future<bool?> setPage(int page) async {
    final bool? isSet = await _channel.invokeMethod('setPage', <String, dynamic>{'page': page});
    return isSet;
  }

  Future<void> _updateWidget(PDFView widget) async {
    _widget = widget;
    await _updateSettings(_PDFViewSettings.fromWidget(widget));
  }

  Future<void> _updateSettings(_PDFViewSettings setting) async {
    final Map<String, dynamic> updateMap = _settings.updatesMap(setting);
    if (updateMap.isEmpty) {
      return;
    }
    _settings = setting;
    return _channel.invokeMethod('updateSettings', updateMap);
  }
}
