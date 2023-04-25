import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/rendering.dart';
import 'dart:typed_data';
import 'package:flutter/material.dart';

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
  })  : assert(filePath != null || pdfData != null),
        super(key: key);

  @override
  _PDFViewState createState() => _PDFViewState();

  /// If not null invoked once the PDFView is created.
  final PDFViewCreatedCallback? onViewCreated;

  /// Return PDF page count as a parameter
  final RenderCallback? onRender;

  /// Return current page and page count as a parameter
  final PageChangedCallback? onPageChanged;

  /// Invokes on error that handled on native code
  final ErrorCallback? onError;

  /// Invokes on page cannot be rendered or something happens
  final PageErrorCallback? onPageError;

  /// Used with preventLinkNavigation=true. It's helpful to customize link navigation
  final LinkHandlerCallback? onLinkHandler;

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

  /// The binary data of a PDF document
  final Uint8List? pdfData;

  /// Indicates whether or not the user can swipe to change pages in the PDF document. If set to true, swiping is enabled.
  final bool enableSwipe;

  /// Indicates whether or not the user can swipe horizontally to change pages in the PDF document. If set to true, horizontal swiping is enabled.
  final bool swipeHorizontal;

  /// Represents the password for a password-protected PDF document. It can be nullable
  final String? password;

  /// Indicates whether or not the PDF viewer is in night mode. If set to true, the viewer is in night mode
  final bool nightMode;

  /// Indicates whether or not the PDF viewer automatically adds spacing between pages. If set to true, spacing is added.
  final bool autoSpacing;

  /// Indicates whether or not the user can "fling" pages in the PDF document. If set to true, page flinging is enabled.
  final bool pageFling;

  /// Indicates whether or not the viewer snaps to a page after the user has scrolled to it. If set to true, snapping is enabled.
  final bool pageSnap;

  /// Represents the default page to display when the PDF document is loaded.
  final int defaultPage;

  /// FitPolicy that determines how the PDF pages are fit to the screen. The FitPolicy enum can take on the following values:
  /// - FitPolicy.WIDTH: The PDF pages are scaled to fit the width of the screen.
  /// - FitPolicy.HEIGHT: The PDF pages are scaled to fit the height of the screen.
  /// - FitPolicy.BOTH: The PDF pages are scaled to fit both the width and height of the screen.
  final FitPolicy fitPolicy;

  /// fitEachPage
  @Deprecated("will be removed next version")
  final bool fitEachPage;

  /// Indicates whether or not clicking on links in the PDF document will open the link in a new page. If set to true, link navigation is prevented.
  final bool preventLinkNavigation;
}

class _PDFViewState extends State<PDFView> {
  final Completer<PDFViewController> _controller =
      Completer<PDFViewController>();

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return PlatformViewLink(
        viewType: 'plugins.endigo.io/pdfview',
        surfaceFactory: (
          BuildContext context,
          PlatformViewController controller,
        ) {
          return AndroidViewSurface(
            controller: controller as AndroidViewController,
            gestureRecognizers: widget.gestureRecognizers ??
                const <Factory<OneSequenceGestureRecognizer>>{},
            hitTestBehavior: PlatformViewHitTestBehavior.opaque,
          );
        },
        onCreatePlatformView: (PlatformViewCreationParams params) {
          return PlatformViewsService.initSurfaceAndroidView(
            id: params.id,
            viewType: 'plugins.endigo.io/pdfview',
            layoutDirection: TextDirection.rtl,
            creationParams: _CreationParams.fromWidget(widget).toMap(),
            creationParamsCodec: const StandardMessageCodec(),
          )
            ..addOnPlatformViewCreatedListener(params.onPlatformViewCreated)
            ..addOnPlatformViewCreatedListener((int id) {
              _onPlatformViewCreated(id);
            })
            ..create();
        },
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
  _PDFViewSettings(
      {this.enableSwipe,
      this.swipeHorizontal,
      this.password,
      this.nightMode,
      this.autoSpacing,
      this.pageFling,
      this.pageSnap,
      this.defaultPage,
      this.fitPolicy,
      // this.fitEachPage,
      this.preventLinkNavigation});

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
        preventLinkNavigation: widget.preventLinkNavigation);
  }

  final bool? enableSwipe;
  final bool? swipeHorizontal;
  final String? password;
  final bool? nightMode;
  final bool? autoSpacing;
  final bool? pageFling;
  final bool? pageSnap;
  final int? defaultPage;
  final FitPolicy? fitPolicy;
  // final bool? fitEachPage;
  final bool? preventLinkNavigation;

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
      // 'fitEachPage': fitEachPage,
      'preventLinkNavigation': preventLinkNavigation
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
