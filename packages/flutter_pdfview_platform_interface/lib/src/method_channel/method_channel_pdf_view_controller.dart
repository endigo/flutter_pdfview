import 'dart:async';

import 'package:flutter/services.dart';

import '../pdf_view_callbacks.dart';
import '../pdf_view_platform_controller.dart';
import '../types.dart';

/// Drives one native PDF view over its per-view method channel.
///
/// The channel name is `plugins.endigo.io/pdfview_<id>`, where `id` is the
/// platform view id. Both bundled implementations register it.
class MethodChannelPdfViewController implements PdfViewPlatformController {
  /// Connects to the view with the given platform view [id] and dispatches its
  /// events to [callbacks].
  MethodChannelPdfViewController(int id, PdfViewCallbacks callbacks)
    : _channel = MethodChannel('plugins.endigo.io/pdfview_$id'),
      _callbacks = callbacks {
    _channel.setMethodCallHandler(_onMethodCall);
  }

  final MethodChannel _channel;

  /// Null once [dispose] has run, which makes in-flight calls no-ops.
  PdfViewCallbacks? _callbacks;

  /// Serializes concurrent [setPosition] calls (and [getPosition] waits) so
  /// platform order matches call order for any number of overlapping callers.
  Future<void> _setPositionQueue = Future<void>.value();

  /// Serializes concurrent [setScale] calls (and [getScale] waits).
  Future<void> _setScaleQueue = Future<void>.value();

  @override
  void updateCallbacks(PdfViewCallbacks callbacks) {
    // Only replace while live; after dispose the controller stays inert.
    if (_callbacks == null) return;
    _callbacks = callbacks;
  }

  @override
  void dispose() {
    _channel.setMethodCallHandler(null);
    _callbacks = null;
  }

  Future<bool?> _onMethodCall(MethodCall call) async {
    final PdfViewCallbacks? callbacks = _callbacks;
    if (callbacks == null) return null;

    switch (call.method) {
      case 'onRender':
        callbacks.onRender?.call(call.arguments['pages']);
        return null;
      case 'onPageChanged':
        callbacks.onPageChanged?.call(call.arguments['page'], call.arguments['total']);
        return null;
      case 'onError':
        callbacks.onError?.call(call.arguments['error']);
        return null;
      case 'onPageError':
        callbacks.onPageError?.call(call.arguments['page'], call.arguments['error']);
        return null;
      case 'onPasswordRequired':
        callbacks.onPasswordRequired?.call(
          call.arguments['incorrect'] == true
              ? PDFPasswordFailure.incorrect
              : PDFPasswordFailure.missing,
        );
        return null;
      case 'onLinkHandler':
        callbacks.onLinkHandler?.call(call.arguments);
        return null;
      case 'onLoadComplete':
        callbacks.onLoadComplete?.call(call.arguments['pages']);
        return null;
      case 'onDraw':
        callbacks.onDraw?.call(
          call.arguments['pdfXOffset'],
          call.arguments['pdfYOffset'],
          call.arguments['pdfScale'],
        );
        return null;
      case 'onTap':
        callbacks.onTap?.call();
        return null;
    }
    throw MissingPluginException('${call.method} was invoked but has no handler');
  }

  @override
  Future<int?> getPageCount() async {
    final int? pageCount = await _channel.invokeMethod('pageCount');
    return pageCount;
  }

  @override
  Future<Size> getCurrentPageSize() async {
    return _channel
        .invokeMethod('currentPageSize')
        .then((pageSize) => Size(pageSize[0] ?? 0, pageSize[1] ?? 0));
  }

  @override
  Future<Offset> getPosition() async {
    await _setPositionQueue;
    final position = await _channel.invokeMethod('getPosition');
    return Offset(position[0] ?? 0, position[1] ?? 0);
  }

  @override
  Future<double> getScale() async {
    await _setScaleQueue;
    final scale = await _channel.invokeMethod('getScale');
    return scale ?? 1;
  }

  @override
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

  @override
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

  @override
  Future<bool> setZoomLimits(double minZoom, double midZoom, double maxZoom) async {
    return await _channel.invokeMethod<bool>('setZoomLimits', <String, dynamic>{
          'minZoom': minZoom,
          'midZoom': midZoom,
          'maxZoom': maxZoom,
        }) ??
        false;
  }

  @override
  Future<String> getScreenshot(String fileName) async {
    final String imageFileName =
        await _channel.invokeMethod<String>('getScreenshot', <String, dynamic>{
          'fileName': fileName,
        }) ??
        '';
    return imageFileName;
  }

  @override
  Future<bool> unlock(String password) async {
    return await _channel.invokeMethod<bool>('unlock', <String, dynamic>{'password': password}) ??
        false;
  }

  @override
  Future<bool> reload() async {
    final bool result = await _channel.invokeMethod<bool>('reload') ?? false;
    return result;
  }

  @override
  Future<int?> getCurrentPage() async {
    final int? currentPage = await _channel.invokeMethod('currentPage');
    return currentPage;
  }

  @override
  Future<bool?> setPage(int page, {bool withAnimation = false}) async {
    final bool? isSet = await _channel.invokeMethod('setPage', <String, dynamic>{
      'page': page,
      'withAnimation': withAnimation,
    });
    return isSet;
  }

  @override
  Future<void> updateSettings(Map<String, dynamic> updates) {
    return _channel.invokeMethod('updateSettings', updates);
  }
}
