import 'dart:async';

import 'package:flutter/services.dart';

import '../platform_interface.dart';

/// A [PDFViewPlatformController] that uses a method channel to control the webview.
class MethodChannelPDFViewPlatform implements PDFViewPlatformController {
  /// Constructs an instance that will listen for webviews broadcasting to the
  /// given [id], using the given [WebViewPlatformCallbacksHandler].
  MethodChannelPDFViewPlatform(int id, this._platformCallbacksHandler)
      : assert(_platformCallbacksHandler != null),
        _channel = MethodChannel('plugins.endigo.io/pdfview_$id') {
    _channel.setMethodCallHandler(_onMethodCall);
  }

  final PDFViewPlatformCallbacksHandler _platformCallbacksHandler;

  final MethodChannel _channel;

  Future<bool> _onMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onRender':
        _platformCallbacksHandler.onRender(call.arguments['pages']);

        return null;
      case 'onPageChanged':
        _platformCallbacksHandler.onPageChanged(
            call.arguments['page'], call.arguments['total']);

        return null;
      case 'onError':
        _platformCallbacksHandler.onError(call.arguments['error']);

        return null;
      case 'onPageError':
        _platformCallbacksHandler.onPageError(
            call.arguments['page'], call.arguments['error']);

        return null;
    }
    throw MissingPluginException(
        '${call.method} was invoked but has no handler');
  }

  Future<int> pageCount() async {
    final int pageCount = await _channel.invokeMethod('pageCount');
    return pageCount;
  }

  Future<int> currentPage() async {
    final int currentPage = await _channel.invokeMethod('currentPage');
    return currentPage;
  }

  Future<bool> setPage(int page) async {
    final bool isSet = await _channel.invokeMethod('setPage', <String, dynamic>{
      'page': page,
    });
    return isSet;
  }

  // Future<void> _updateWidget(PDFView widget) async {
  //   _widget = widget;
  //   await _updateSettings(_PDFViewSettings.fromWidget(widget));
  // }

  Future<void> updateSettings(PDFSettings settings) async {
    final Map<String, dynamic> updatesMap = _pdfSettingsToMap(settings);
    if (updatesMap.isEmpty) {
      return null;
    }
    return _channel.invokeMethod<void>('updateSettings', updatesMap);
  }

  static Map<String, dynamic> _pdfSettingsToMap(PDFSettings settings) {
    final Map<String, dynamic> map = <String, dynamic>{};
    void _addIfNonNull(String key, dynamic value) {
      if (value == null) {
        return;
      }
      map[key] = value;
    }

    // void _addSettingIfPresent<T>(String key, PDFSetting<T> setting) {
    //   if (!setting.isPresent) {
    //     return;
    //   }
    //   map[key] = setting.value;
    // }

    _addIfNonNull('enableSwipe', settings.enableSwipe);
    _addIfNonNull('swipeHorizontal', settings.swipeHorizontal);
    _addIfNonNull('password', settings.password);
    _addIfNonNull('nightMode', settings.nightMode);
    _addIfNonNull('autoSpacing', settings.autoSpacing);
    _addIfNonNull('pageFling', settings.pageFling);
    _addIfNonNull('pageSnap', settings.pageSnap);
    _addIfNonNull('defaultPage', settings.defaultPage);
    _addIfNonNull('fitPolicy', settings.fitPolicy);
    _addIfNonNull('fitEachPage', settings.fitEachPage);
    return map;
  }

  /// Converts a [CreationParams] object to a map as expected by `platform_views` channel.
  ///
  /// This is used for the `creationParams` argument of the platform views created by
  /// [AndroidPDFViewBuilder] and [CupertinoPDFViewBuilder].
  static Map<String, dynamic> creationParamsToMap(
      CreationParams creationParams) {
    return <String, dynamic>{
      'filePath': creationParams.filePath,
      'settings': _pdfSettingsToMap(creationParams.settings)
    };
  }
}
