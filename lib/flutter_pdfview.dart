import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

typedef PDFViewCreatedCallback = void Function(PDFViewController controller);
typedef RenderCallback = void Function(int? pages);
typedef PageChangedCallback = void Function(int? page, int? total);
typedef ErrorCallback = void Function(dynamic error);
typedef PageErrorCallback = void Function(int? page, dynamic error);
typedef LinkHandlerCallback = void Function(String? uri);
typedef LoadCompleteCallback = void Function(int? pages);
typedef DrawCallback = void Function(double pdfXOffset, double pdfYOffset, double pdfScale);

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
    this.onLoadComplete,
    this.onDraw,
    this.gestureRecognizers,
    this.enableSwipe = true,
    this.swipeHorizontal = false,
    this.showScrollIndicators = false,
    this.password,
    this.nightMode = false,
    this.autoSpacing = true,
    this.pageFling = true,
    this.pageSnap = true,
    this.enableAntialiasing = true,
    this.useBestQuality = true,
    this.enableRenderDuringScale = true,
    this.thumbnailRatio = 0.8,
    this.fitEachPage = true,
    this.defaultPage = 0,
    this.fitPolicy = FitPolicy.WIDTH,
    this.preventLinkNavigation = false,
    this.backgroundColor,
    this.maxZoom = 4.0,
    this.minZoom = 1.0,
  })  : assert(filePath != null || pdfData != null),
        assert(maxZoom > 0, 'maxZoom must be greater than 0'),
        assert(minZoom > 0, 'minZoom must be greater than 0'),
        assert(maxZoom >= minZoom, 'maxZoom must be >= minZoom'),
        assert(thumbnailRatio == null || (thumbnailRatio > 0 && thumbnailRatio <= 1),
            'thumbnailRatio must be within (0, 1]'),
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
  final LoadCompleteCallback? onLoadComplete;
  final DrawCallback? onDraw;

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

  /// Indicates whether or not the PDF Viewer should show scroll indicators - scroll handles on Android and scrollbars on iOS
  /// NB: on iOS, if pageFling is set to true, scroll indicators will not show
  final bool showScrollIndicators;

  /// Represents the password for a password-protected PDF document. It can be nullable
  final String? password;

  /// Indicates whether or not the PDF viewer is in night mode. If set to true, the viewer is in night mode
  final bool nightMode;

  /// Indicates whether or not the PDF viewer automatically adds spacing between pages. If set to true, spacing is added.
  final bool autoSpacing;

  /// Indicates whether or not the user can "fling" pages in the PDF document. If set to true, page flinging is enabled.
  final bool pageFling;

  /// Indicates whether or not the viewer snaps to a page after the user has scrolled to it.
  /// If set to true, snapping is enabled. No effect in iOS
  final bool pageSnap;

  /// Controls whether the PDF renderer uses anti-aliasing (Android only).
  final bool enableAntialiasing;

  /// Improves render quality at the cost of performance (Android only).
  final bool useBestQuality;

  /// Renders during scale gestures for smoother zooming (Android only).
  final bool enableRenderDuringScale;

  /// Thumbnail ratio used by AndroidPdfViewer (Android only).
  final double? thumbnailRatio;

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

  /// Use to change the background color. ex : "#FF0000" => red
  final Color? backgroundColor;

  /// Maximum zoom level. Defaults to 4.0.
  final double maxZoom;

  /// Minimum zoom level. Defaults to 1.0 (fit to page).
  final double minZoom;
}

class _PDFViewState extends State<PDFView> {
  Completer<PDFViewController> _controller = Completer<PDFViewController>();

  /// Bumped when the native platform view must be recreated (new document).
  int _viewGeneration = 0;

  bool _documentChanged(PDFView oldWidget) {
    if (widget.filePath != oldWidget.filePath) {
      return true;
    }
    final Uint8List? a = widget.pdfData;
    final Uint8List? b = oldWidget.pdfData;
    if (identical(a, b)) {
      return false;
    }
    if (a == null || b == null || a.length != b.length) {
      return true;
    }
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) {
        return true;
      }
    }
    return false;
  }

  void _remountPlatformView() {
    if (!mounted) {
      return;
    }
    // Dispose the previous controller so native resources are released (#261).
    if (_controller.isCompleted) {
      _controller.future.then((PDFViewController c) => c.dispose());
    }
    setState(() {
      _viewGeneration++;
      _controller = Completer<PDFViewController>();
    });
  }

  @override
  Widget build(BuildContext context) {
    final Key viewKey = ValueKey<int>(_viewGeneration);
    if (defaultTargetPlatform == TargetPlatform.android) {
      return PlatformViewLink(
        key: viewKey,
        viewType: 'plugins.endigo.io/pdfview',
        surfaceFactory: (
          BuildContext context,
          PlatformViewController controller,
        ) {
          return AndroidViewSurface(
            controller: controller as AndroidViewController,
            gestureRecognizers:
                widget.gestureRecognizers ?? const <Factory<OneSequenceGestureRecognizer>>{},
            hitTestBehavior: PlatformViewHitTestBehavior.opaque,
          );
        },
        onCreatePlatformView: (PlatformViewCreationParams params) {
          // True hybrid composition embeds the real android.view.View instead of
          // mirroring via SurfaceTexture. Texture mode (initSurfaceAndroidView)
          // crashes under load ("Surface was already locked!", EGL_NO_DISPLAY)
          // and blanks/glitches on rotation, dialogs, and some GPUs
          // (#9, #182, #263, #280, #298, #306).
          return PlatformViewsService.initExpensiveAndroidView(
            id: params.id,
            viewType: 'plugins.endigo.io/pdfview',
            layoutDirection: Directionality.maybeOf(context) ?? TextDirection.ltr,
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
        key: viewKey,
        viewType: 'plugins.endigo.io/pdfview',
        onPlatformViewCreated: _onPlatformViewCreated,
        gestureRecognizers: widget.gestureRecognizers,
        creationParams: _CreationParams.fromWidget(widget).toMap(),
        creationParamsCodec: const StandardMessageCodec(),
      );
    }
    return Text('$defaultTargetPlatform is not yet supported by the pdfview_flutter plugin');
  }

  void _onPlatformViewCreated(int id) {
    final PDFViewController controller = PDFViewController._(id, widget);
    if (!_controller.isCompleted) {
      _controller.complete(controller);
    }
    widget.onViewCreated?.call(controller);
  }

  @override
  void didUpdateWidget(PDFView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // #181: filePath / pdfData changes must load a new document. Settings-only
    // updates go through the method channel; document changes remount the view.
    if (_documentChanged(oldWidget)) {
      _remountPlatformView();
      return;
    }
    _controller.future.then((PDFViewController controller) => controller._updateWidget(widget));
  }

  @override
  void dispose() {
    if (_controller.isCompleted) {
      _controller.future.then((PDFViewController controller) => controller.dispose());
    }
    super.dispose();
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
    this.enableSwipe,
    this.swipeHorizontal,
    this.showScrollIndicators,
    this.password,
    this.nightMode,
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

  static _PDFViewSettings fromWidget(PDFView widget) {
    return _PDFViewSettings(
      enableSwipe: widget.enableSwipe,
      swipeHorizontal: widget.swipeHorizontal,
      showScrollIndicators: widget.showScrollIndicators,
      password: widget.password,
      nightMode: widget.nightMode,
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
      'nightMode': nightMode,
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

  Map<String, dynamic> updatesMap(_PDFViewSettings newSettings) {
    final Map<String, dynamic> updates = <String, dynamic>{};
    if (enableSwipe != newSettings.enableSwipe) {
      updates['enableSwipe'] = newSettings.enableSwipe;
    }
    if (nightMode != newSettings.nightMode) {
      updates['nightMode'] = newSettings.nightMode;
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
    return updates;
  }
}

class PDFViewController {
  PDFViewController._(
    int id,
    PDFView widget,
  )   : _channel = MethodChannel('plugins.endigo.io/pdfview_$id'),
        _widget = widget {
    _settings = _PDFViewSettings.fromWidget(widget);
    _channel.setMethodCallHandler(_onMethodCall);
  }

  void dispose() {
    _channel.setMethodCallHandler(null);
    _widget = null;
  }

  MethodChannel _channel;

  late _PDFViewSettings _settings;

  PDFView? _widget;

  Completer<void>? _setPositionCompleter;
  Completer<void>? _setScaleCompleter;

  Future<bool?> _onMethodCall(MethodCall call) async {
    final widget = _widget;
    if (widget == null) return null;

    switch (call.method) {
      case 'onRender':
        widget.onRender?.call(call.arguments['pages']);
        return null;
      case 'onPageChanged':
        widget.onPageChanged?.call(
          call.arguments['page'],
          call.arguments['total'],
        );
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
            call.arguments['pdfXOffset'], call.arguments['pdfYOffset'], call.arguments['pdfScale']);
        return null;
    }
    throw MissingPluginException('${call.method} was invoked but has no handler');
  }

  Future<int?> getPageCount() async {
    final int? pageCount = await _channel.invokeMethod('pageCount');
    return pageCount;
  }

  Future<Size> getCurrentPageSize() async {
    return _channel
        .invokeMethod('currentPageSize')
        .then((pageSize) => Size(pageSize[0] ?? 0, pageSize[1] ?? 0));
  }

  Future<Offset> getPosition() async {
    if (_setPositionCompleter != null && !_setPositionCompleter!.isCompleted) {
      await _setPositionCompleter!.future;
    }

    final position = await _channel.invokeMethod('getPosition');
    return Offset(position[0] ?? 0, position[1] ?? 0);
  }

  Future<double> getScale() async {
    if (_setScaleCompleter != null && !_setScaleCompleter!.isCompleted) {
      await _setScaleCompleter!.future;
    }

    final scale = await _channel.invokeMethod('getScale');
    return scale ?? 1;
  }

  Future<bool> setPosition(Offset position) async {
    if (_setPositionCompleter != null && !_setPositionCompleter!.isCompleted) {
      await _setPositionCompleter!.future;
    }
    final Completer<void> completer = _setPositionCompleter = Completer<void>();
    try {
      final bool isSet = await _channel.invokeMethod('setPosition', <String, double>{
        'xPos': position.dx,
        'yPos': position.dy,
      });
      return isSet;
    } finally {
      if (!completer.isCompleted) {
        completer.complete();
      }
    }
  }

  Future<bool> setScale(double scale) async {
    if (_setScaleCompleter != null && !_setScaleCompleter!.isCompleted) {
      await _setScaleCompleter!.future;
    }
    final Completer<void> completer = _setScaleCompleter = Completer<void>();
    try {
      final bool isSet = await _channel.invokeMethod('setScale', <String, double>{
        'scale': scale,
      });
      return isSet;
    } finally {
      if (!completer.isCompleted) {
        completer.complete();
      }
    }
  }

  Future<bool> setZoomLimits(double minZoom, double midZoom, double maxZoom) async {
    return await _channel.invokeMethod<bool>('setZoomLimits', <String, dynamic>{
          'minZoom': minZoom,
          'midZoom': midZoom,
          'maxZoom': maxZoom,
        }) ??
        false;
  }

  Future<String> getScreenshot(String fileName) async {
    final String imageFileName =
        await _channel.invokeMethod<String>('getScreenshot', <String, dynamic>{
              'fileName': fileName,
            }) ??
            '';
    return imageFileName;
  }

  Future<bool> reload() async {
    final bool result = await _channel.invokeMethod<bool>('reload') ?? false;
    return result;
  }

  Future<int?> getCurrentPage() async {
    final int? currentPage = await _channel.invokeMethod('currentPage');
    return currentPage;
  }

  Future<bool?> setPage(int page) async {
    final bool? isSet = await _channel.invokeMethod('setPage', <String, dynamic>{
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
