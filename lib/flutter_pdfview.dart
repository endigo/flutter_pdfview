import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
// import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

typedef PDFViewCreatedCallback = void Function(PDFViewController controller);
typedef RenderCallback = void Function(int? pages);
typedef PageChangedCallback = void Function(int? page, int? total);
typedef ErrorCallback = void Function(dynamic error);
typedef PageErrorCallback = void Function(int? page, dynamic error);
typedef LinkHandlerCallback = void Function(String? uri);

enum FitPolicy { WIDTH, HEIGHT, BOTH }

class PDFView extends StatefulWidget {
  const PDFView({
    Key? key,
    this.filePath,
    this.pdfData,
    this.onViewCreated,
    this.onRender,
    this.onPageChanged,
    this.onError,
    this.onPageError,
    this.onLinkHandler,
    this.gestureRecognizers,
    this.enableSwipe = true,
    this.swipeHorizontal = false,
    this.password,
    this.nightMode = false,
    this.autoSpacing = true,
    this.pageFling = true,
    this.pageSnap = true,
    this.fitEachPage = true,
    this.defaultPage = 0,
    this.fitPolicy = FitPolicy.WIDTH,
    this.preventLinkNavigation = false,
    this.onTap,
    this.spacing = 0,
    this.enableDoubleTap = true,
    this.setBackgroundColor = Colors.white,
    this.setMaxZoom = 3.0,
    this.setMidZoom = 1.75,
    this.setMinZoom = 1.0,
  })  : assert(filePath != null || pdfData != null),
        super(key: key);

  @override
  _PDFViewState createState() => _PDFViewState();

  /// If not null invoked once the web view is created.
  final PDFViewCreatedCallback? onViewCreated;

  final RenderCallback? onRender;

  final PageChangedCallback? onPageChanged;

  final ErrorCallback? onError;

  /// Works on [Android]
  final PageErrorCallback? onPageError;

  final LinkHandlerCallback? onLinkHandler;

  /// Works on [Android]
  final VoidCallback? onTap;

  /// Which gestures should be consumed by the pdf view.
  ///
  /// It is possible for other gesture recognizers to be competing with the pdf view on pointer
  /// events, e.g if the pdf view is inside a [ListView] the [ListView] will want to handle
  /// vertical drags. The pdf view will claim gestures that are recognized by any of the
  /// recognizers on this list.
  ///
  /// When this set is empty or null, the pdf view will only handle pointer events for gestures that
  /// were not claimed by any other gesture recognizer.
  final Set<Factory<OneSequenceGestureRecognizer>>? gestureRecognizers;

  /// The initial URL to load.
  final String? filePath;
  final Uint8List? pdfData;

  final bool enableSwipe;
  final bool swipeHorizontal;
  final String? password;

  /// Works on [Android]
  final bool nightMode;
  final bool autoSpacing;

  /// minimum swipe to change the page
  final bool pageFling;

  /// Works on [Android]
  ///
  /// if [true] automatic center the page
  ///
  /// if [false] you can stop betwen two pages
  final bool pageSnap;

  /// initial page to show
  final int defaultPage;

  /// Works on [Android]
  final FitPolicy fitPolicy;
  final bool fitEachPage;
  final bool preventLinkNavigation;

  /// Works on [Android]
  ///
  /// space betwen the pages (arround each page)
  final int spacing;

  /// Works on [Android]
  ///
  /// for zoom-in-out
  final bool enableDoubleTap;

  /// Works on [Android]
  final Color setBackgroundColor;

  /// Works on [Android]
  final double setMaxZoom;

  /// Works on [Android]
  ///
  /// for double tap (middle step)
  final double setMidZoom;

  /// Works on [Android]
  final double setMinZoom;
}

class _PDFViewState extends State<PDFView> {
  final Completer<PDFViewController> _controller =
      Completer<PDFViewController>();
  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform == TargetPlatform.android) {
      // // aded by lcyper

      // return PlatformViewLink(
      //   surfaceFactory: (context, controller) {
      //     return AndroidViewSurface(
      //       controller: controller as AndroidViewController,
      //       gestureRecognizers: widget.gestureRecognizers ??
      //           <Factory<OneSequenceGestureRecognizer>>{},
      //       hitTestBehavior: PlatformViewHitTestBehavior.opaque,
      //     );
      //   },
      //   viewType: 'plugins.endigo.io/pdfview',
      //   onCreatePlatformView: (PlatformViewCreationParams params) {
      //     // final PDFViewController controller = PDFViewController._(id, widget);
      //     // _controller.complete(controller);
      //     // if (widget.onViewCreated != null) {
      //     //   widget.onViewCreated!(controller);
      //     // }
      //     return PlatformViewsService.initSurfaceAndroidView(
      //       id: params.id,
      //       viewType: 'plugins.endigo.io/pdfview',
      //       layoutDirection: TextDirection.ltr,
      //       creationParams: _CreationParams.fromWidget(widget).toMap(),
      //       creationParamsCodec: const StandardMessageCodec(),
      //       onFocus: () {
      //         params.onFocusChanged(true);
      //       },
      //     )
      //       ..addOnPlatformViewCreatedListener(params.onPlatformViewCreated)
      //       ..create();
      //   },
      // );
      // // until here

      return AndroidView(
        viewType: 'plugins.endigo.io/pdfview',
        onPlatformViewCreated: _onPlatformViewCreated,
        gestureRecognizers: widget.gestureRecognizers,
        creationParams: _CreationParams.fromWidget(widget).toMap(),
        creationParamsCodec: const StandardMessageCodec(),
      );
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      return UiKitView(
        viewType: 'plugins.endigo.io/pdfview',
        onPlatformViewCreated: _onPlatformViewCreated,
        gestureRecognizers: widget.gestureRecognizers,
        creationParams: _CreationParams.fromWidget(widget).toMap(),
        creationParamsCodec: const StandardMessageCodec(),
      );
    }
    return Text(
        '$defaultTargetPlatform is not yet supported by the pdfview_flutter plugin');
  }

  void _onPlatformViewCreated(int id) {
    final PDFViewController controller = PDFViewController._(id, widget);
    _controller.complete(controller);
    if (widget.onViewCreated != null) {
      widget.onViewCreated!(controller);
    }
  }

  @override
  void didUpdateWidget(PDFView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _controller.future.then(
        (PDFViewController controller) => controller._updateWidget(widget));
  }
}

class _CreationParams {
  _CreationParams({
    this.filePath,
    this.pdfData,
    this.settings,
  });

  static _CreationParams fromWidget(PDFView widget) {
    return _CreationParams(
      filePath: widget.filePath,
      pdfData: widget.pdfData,
      settings: _PDFViewSettings.fromWidget(widget),
    );
  }

  final String? filePath;
  final Uint8List? pdfData;

  final _PDFViewSettings? settings;

  Map<String, dynamic> toMap() {
    Map<String, dynamic> params = {
      'filePath': filePath,
      'pdfData': pdfData,
    };

    params.addAll(settings!.toMap());

    return params;
  }
}

class _PDFViewSettings {
  _PDFViewSettings({
    required this.enableSwipe,
    required this.swipeHorizontal,
    this.password,
    required this.nightMode,
    required this.autoSpacing,
    required this.pageFling,
    required this.pageSnap,
    required this.defaultPage,
    required this.fitPolicy,
    required this.fitEachPage,
    required this.preventLinkNavigation,
    required this.spacing,
    required this.enableDoubleTap,
    required this.setBackgroundColor,
    required this.setMaxZoom,
    required this.setMidZoom,
    required this.setMinZoom,
  });

  static _PDFViewSettings fromWidget(PDFView widget) {
    return _PDFViewSettings(
      enableSwipe: widget.enableSwipe,
      swipeHorizontal: widget.swipeHorizontal,
      password: widget.password,
      nightMode: widget.nightMode,
      autoSpacing: widget.autoSpacing,
      pageFling: widget.pageFling,
      pageSnap: widget.pageSnap,
      defaultPage: widget.defaultPage,
      fitPolicy: widget.fitPolicy,
      fitEachPage: widget.fitEachPage,
      preventLinkNavigation: widget.preventLinkNavigation,
      spacing: widget.spacing,
      enableDoubleTap: widget.enableDoubleTap,
      setBackgroundColor: widget.setBackgroundColor,
      setMaxZoom: widget.setMaxZoom,
      setMidZoom: widget.setMidZoom,
      setMinZoom: widget.setMinZoom,
    );
  }

  final bool enableSwipe;
  final bool swipeHorizontal;
  final String? password;
  final bool nightMode;
  final bool autoSpacing;
  final bool pageFling;
  final bool pageSnap;
  final int defaultPage;
  final FitPolicy fitPolicy;
  final bool fitEachPage;
  final bool preventLinkNavigation;
  final int spacing;
  final bool enableDoubleTap;
  final Color setBackgroundColor;
  final double setMaxZoom;
  final double setMidZoom;
  final double setMinZoom;

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
      'preventLinkNavigation': preventLinkNavigation,
      'spacing': spacing,
      'enableDoubleTap': enableDoubleTap,
      // convert Color to hex string
      'setBackgroundColor': setBackgroundColor.value.toRadixString(16),
      'setMaxZoom': setMaxZoom,
      'setMidZoom': setMidZoom,
      'setMinZoom': setMinZoom,
    };
  }

  Map<String, dynamic> updatesMap(_PDFViewSettings newSettings) {
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
    if (preventLinkNavigation != newSettings.preventLinkNavigation) {
      updates['preventLinkNavigation'] = newSettings.preventLinkNavigation;
    }
    return updates;
  }
}

class PDFViewController {
  PDFViewController._(
    int id,
    this._widget,
  ) : _channel = MethodChannel('plugins.endigo.io/pdfview_$id') {
    _settings = _PDFViewSettings.fromWidget(_widget);
    _channel.setMethodCallHandler(_onMethodCall);
  }

  final MethodChannel _channel;

  late _PDFViewSettings _settings;

  PDFView _widget;

  Future<bool?> _onMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onRender':
        if (_widget.onRender != null) {
          _widget.onRender!(call.arguments['pages']);
        }

        return null;
      case 'onPageChanged':
        if (_widget.onPageChanged != null) {
          _widget.onPageChanged!(
              call.arguments['page'], call.arguments['total']);
        }

        return null;
      case 'onError':
        if (_widget.onError != null) {
          _widget.onError!(call.arguments['error']);
        }

        return null;
      case 'onPageError':
        if (_widget.onPageError != null) {
          _widget.onPageError!(call.arguments['page'], call.arguments['error']);
        }

        return null;
      case 'onLinkHandler':
        if (_widget.onLinkHandler != null) {
          _widget.onLinkHandler!(call.arguments);
        }

        return null;

      case 'onTap':
        if (_widget.onTap != null) {
          _widget.onTap!();
        }

        return null;
    }
    throw MissingPluginException(
        '${call.method} was invoked but has no handler');
  }

  Future<int?> getPageCount() async {
    final int? pageCount = await _channel.invokeMethod('pageCount');
    return pageCount;
  }

  Future<int?> getCurrentPage() async {
    final int? currentPage = await _channel.invokeMethod('currentPage');
    return currentPage;
  }

  Future<bool?> setPage(int page) async {
    final bool? isSet =
        await _channel.invokeMethod('setPage', <String, dynamic>{
      'page': page,
    });
    return isSet;
  }

  Future<void> _updateWidget(PDFView widget) async {
    _widget = widget;
    await _updateSettings(_PDFViewSettings.fromWidget(widget));
  }

  Future<void> _updateSettings(_PDFViewSettings setting) async {
    final Map<String, dynamic> updateMap = _settings.updatesMap(setting);
    if (updateMap.isEmpty) {
      return null;
    }
    _settings = setting;
    return _channel.invokeMethod('updateSettings', updateMap);
  }
}
