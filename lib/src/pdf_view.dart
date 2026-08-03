part of '../flutter_pdfview.dart';

/// The view type registered by the native plugins on both platforms.
const String _viewType = 'plugins.endigo.io/pdfview';

/// A widget that renders a PDF document using the platform's native viewer.
///
/// Exactly one document source must be supplied: either [filePath], pointing at
/// a file on disk, or [pdfData], holding the raw bytes of the document.
///
/// Changing [filePath] or [pdfData] recreates the underlying platform view so
/// that the new document is loaded. Changing any other setting is forwarded to
/// the native view over the method channel without recreating it.
class PDFView extends StatefulWidget {
  /// Creates a widget that displays a PDF document.
  ///
  /// Either [filePath] or [pdfData] must be non-null.
  const PDFView({
    super.key,
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
    this.pageAlignment = PageAlignment.center,
    this.preventLinkNavigation = false,
    this.backgroundColor,
    this.maxZoom = 4.0,
    this.minZoom = 1.0,
  }) : assert(filePath != null || pdfData != null),
       assert(maxZoom > 0, 'maxZoom must be greater than 0'),
       assert(minZoom > 0, 'minZoom must be greater than 0'),
       assert(maxZoom >= minZoom, 'maxZoom must be >= minZoom'),
       assert(
         thumbnailRatio == null || (thumbnailRatio > 0 && thumbnailRatio <= 1),
         'thumbnailRatio must be within (0, 1]',
       );

  /// If not null invoked once the PDFView is created.
  final PDFViewCreatedCallback? onViewCreated;

  /// Returns the PDF page count as a parameter.
  final RenderCallback? onRender;

  /// Returns the current page and the page count as parameters.
  final PageChangedCallback? onPageChanged;

  /// Invoked on an error that was handled in native code.
  final ErrorCallback? onError;

  /// Invoked when a page cannot be rendered or something else goes wrong.
  final PageErrorCallback? onPageError;

  /// Used with `preventLinkNavigation: true`. Helpful to customize link
  /// navigation.
  final LinkHandlerCallback? onLinkHandler;

  /// Invoked once the document has finished loading, with its page count.
  final LoadCompleteCallback? onLoadComplete;

  /// Invoked while the document is drawn, with the current offsets and scale.
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

  /// The path of the document to load from disk.
  final String? filePath;

  /// The binary data of a PDF document.
  final Uint8List? pdfData;

  /// Indicates whether or not the user can swipe to change pages in the PDF document. If set to
  /// true, swiping is enabled.
  final bool enableSwipe;

  /// Indicates whether or not the user can swipe horizontally to change pages in the PDF document.
  /// If set to true, horizontal swiping is enabled.
  final bool swipeHorizontal;

  /// Indicates whether or not the PDF viewer should show scroll indicators - scroll handles on
  /// Android and scrollbars on iOS.
  ///
  /// NB: on iOS, if [pageFling] is set to true, scroll indicators will not show.
  final bool showScrollIndicators;

  /// The password for a password-protected PDF document. It can be nullable.
  final String? password;

  /// Indicates whether or not the PDF viewer is in night mode. If set to true, the viewer is in
  /// night mode.
  final bool nightMode;

  /// Whether the viewer adds spacing (page breaks) between pages.
  ///
  /// On both platforms this only controls gaps between pages. It does **not**
  /// change initial zoom or [fitPolicy] — that was a historical iOS bug (#150).
  final bool autoSpacing;

  /// Indicates whether or not the user can "fling" pages in the PDF document. If set to true, page
  /// flinging is enabled.
  final bool pageFling;

  /// Indicates whether or not the viewer snaps to a page after the user has scrolled to it.
  ///
  /// If set to true, snapping is enabled. No effect on iOS.
  final bool pageSnap;

  /// Controls whether the PDF renderer uses anti-aliasing (Android only).
  final bool enableAntialiasing;

  /// Improves render quality at the cost of performance (Android only).
  final bool useBestQuality;

  /// Renders during scale gestures for smoother zooming (Android only).
  final bool enableRenderDuringScale;

  /// Thumbnail ratio used by AndroidPdfViewer (Android only).
  ///
  /// Must be within `(0, 1]` when it is not null.
  final double? thumbnailRatio;

  /// The page to display when the PDF document is loaded.
  final int defaultPage;

  /// How each page is scaled to the viewport on load and when the view resizes.
  ///
  /// - [FitPolicy.WIDTH]: scale so the page width fills the viewport width.
  /// - [FitPolicy.HEIGHT]: scale so the page height fills the viewport height.
  /// - [FitPolicy.BOTH]: scale so the entire page is visible (letterbox if needed).
  ///
  /// Supported on Android and iOS.
  final FitPolicy fitPolicy;

  /// How a document that is shorter than the viewport is placed inside it.
  ///
  /// Defaults to [PageAlignment.center] (historical behavior of AndroidPdfViewer
  /// and PDFKit). Use [PageAlignment.top] so free space sits below the page —
  /// typical for single-page PDFs ([#250](https://github.com/endigo/flutter_pdfview/issues/250),
  /// [#272](https://github.com/endigo/flutter_pdfview/issues/272)).
  ///
  /// Supported on Android and iOS.
  final PageAlignment pageAlignment;

  /// Whether each page is fitted individually.
  @Deprecated('will be removed next version')
  final bool fitEachPage;

  /// Indicates whether or not clicking on links in the PDF document will open the link in a new
  /// page. If set to true, link navigation is prevented and [onLinkHandler] is called instead.
  final bool preventLinkNavigation;

  /// The background color drawn behind the document.
  final Color? backgroundColor;

  /// Maximum zoom level. Defaults to 4.0.
  final double maxZoom;

  /// Minimum zoom level. Defaults to 1.0 (fit to page).
  final double minZoom;

  @override
  State<PDFView> createState() => _PDFViewState();
}

class _PDFViewState extends State<PDFView> {
  Completer<PDFViewController> _controller = Completer<PDFViewController>();

  /// Bumped when the native platform view must be recreated (new document).
  int _viewGeneration = 0;

  /// Identity / FNV-1a digest of the last accepted [PDFView.pdfData], so rebuilds
  /// with a new [Uint8List] of equal content avoid a full per-byte scan after the
  /// first hash of each instance.
  Object? _pdfDataIdentity;
  int? _pdfDataDigest;

  @override
  void initState() {
    super.initState();
    _cachePdfData(widget.pdfData);
  }

  /// FNV-1a 32-bit content digest used as a constant-time document identity key
  /// once computed for a given [Uint8List] instance.
  static int _digestPdfData(Uint8List data) {
    int hash = 0x811c9dc5;
    for (int i = 0; i < data.length; i++) {
      hash ^= data[i];
      // Keep within 32 bits without depending on platform int width.
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash;
  }

  int _digestFor(Uint8List data) {
    if (identical(data, _pdfDataIdentity) && _pdfDataDigest != null) {
      return _pdfDataDigest!;
    }
    return _digestPdfData(data);
  }

  void _cachePdfData(Uint8List? data) {
    if (data == null) {
      _pdfDataIdentity = null;
      _pdfDataDigest = null;
      return;
    }
    if (identical(data, _pdfDataIdentity) && _pdfDataDigest != null) {
      return;
    }
    _pdfDataIdentity = data;
    _pdfDataDigest = _digestPdfData(data);
  }

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
    // Same length, different instances: compare cached digests (O(1) when the
    // previous list is still the cached identity; O(n) once to hash a new list).
    return _digestFor(a) != _digestFor(b);
  }

  void _remountPlatformView() {
    if (!mounted) {
      return;
    }
    // Dispose the previous controller so native resources are released (#261).
    // Bump generation first so any late creation callback from the old platform
    // view is ignored and disposes its controller instead of completing the
    // new Completer (stale onPlatformViewCreated race).
    final Completer<PDFViewController> previous = _controller;
    _viewGeneration++;
    if (previous.isCompleted) {
      previous.future.then((PDFViewController c) => c.dispose());
    }
    setState(() {
      _controller = Completer<PDFViewController>();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Capture generation at build time so platform-view creation callbacks
    // from a previous mount cannot complete the current Completer.
    final int generation = _viewGeneration;
    final Key viewKey = ValueKey<int>(generation);
    if (defaultTargetPlatform == TargetPlatform.android) {
      return PlatformViewLink(
        key: viewKey,
        viewType: _viewType,
        surfaceFactory: (BuildContext context, PlatformViewController controller) {
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
              viewType: _viewType,
              layoutDirection: Directionality.maybeOf(context) ?? TextDirection.ltr,
              creationParams: _CreationParams.fromWidget(widget).toMap(),
              creationParamsCodec: const StandardMessageCodec(),
            )
            ..addOnPlatformViewCreatedListener(params.onPlatformViewCreated)
            ..addOnPlatformViewCreatedListener((int id) {
              _onPlatformViewCreated(id, generation: generation);
            })
            ..create();
        },
      );
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      return UiKitView(
        key: viewKey,
        viewType: _viewType,
        onPlatformViewCreated: (int id) {
          _onPlatformViewCreated(id, generation: generation);
        },
        gestureRecognizers: widget.gestureRecognizers,
        creationParams: _CreationParams.fromWidget(widget).toMap(),
        creationParamsCodec: const StandardMessageCodec(),
      );
    }
    return Text('$defaultTargetPlatform is not yet supported by the pdfview_flutter plugin');
  }

  void _onPlatformViewCreated(int id, {required int generation}) {
    final PDFViewController controller = PDFViewController._(id, widget);
    // Ignore late callbacks from a remounted/disposed platform view so they
    // cannot complete the new Completer with a stale controller.
    if (!mounted || generation != _viewGeneration) {
      controller.dispose();
      return;
    }
    if (_controller.isCompleted) {
      controller.dispose();
      return;
    }
    _controller.complete(controller);
    widget.onViewCreated?.call(controller);
  }

  @override
  void didUpdateWidget(PDFView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // #181: filePath / pdfData changes must load a new document. Settings-only
    // updates go through the method channel; document changes remount the view.
    final bool documentChanged = _documentChanged(oldWidget);
    _cachePdfData(widget.pdfData);
    if (documentChanged) {
      _remountPlatformView();
      return;
    }
    _controller.future.then((PDFViewController controller) => controller._updateWidget(widget));
  }

  @override
  void dispose() {
    // Invalidate in-flight creation callbacks before tearing down the controller.
    _viewGeneration++;
    if (_controller.isCompleted) {
      _controller.future.then((PDFViewController controller) => controller.dispose());
    }
    super.dispose();
  }
}

/// The parameters handed to the native view when it is first created.
class _CreationParams {
  _CreationParams({this.filePath, this.pdfData, this.settings});

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
    final Map<String, dynamic> params = <String, dynamic>{'filePath': filePath, 'pdfData': pdfData};

    params.addAll(settings!.toMap());

    return params;
  }
}
