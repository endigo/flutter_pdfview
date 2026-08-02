import Flutter
import PDFKit
import UIKit

#if canImport(flutter_pdfview_objc)
// SwiftPM forbids mixed-language targets, so the `@try`/`@catch` shim lives in
// its own target and has to be imported. Under CocoaPods the shim is compiled
// into the same pod and reaches Swift through the underlying module, where this
// import does not exist.
import flutter_pdfview_objc
#endif

// MARK: - NSException bridging

/// Runs `body`, reporting any raised `NSException` instead of letting it unwind
/// through Swift frames (which would trap).
///
/// Swift has no `@try`/`@catch`; every call site below mirrors one that the
/// Objective-C implementation guarded the same way.
private func catchingNSException(_ body: () -> Void, onException: (NSError) -> Void) {
    do {
        try FPVExceptionCatcher.catchException(body)
    } catch {
        onException(error as NSError)
    }
}

private extension NSError {
    /// Equivalent of `exception.reason`, including the `"(null)"` that
    /// `NSLog(@"%@", exception.reason)` printed when there was none.
    var pdfExceptionReason: String {
        userInfo[FPVExceptionReasonKey] as? String ?? "(null)"
    }

    /// Equivalent of `NSLog(@"%@", exception)`.
    var pdfExceptionDescription: String {
        userInfo[FPVExceptionDescriptionKey] as? String ?? localizedDescription
    }
}

// MARK: - Argument decoding

private extension Dictionary where Key == String, Value == Any {
    func number(_ key: String) -> NSNumber? {
        self[key] as? NSNumber
    }

    /// Matches Objective-C's `[args[key] boolValue]`: a missing key is `NO`.
    func bool(_ key: String) -> Bool {
        number(key)?.boolValue ?? false
    }

    /// Matches Objective-C's `[args[key] doubleValue]`: a missing key is `0`.
    func double(_ key: String) -> Double {
        number(key)?.doubleValue ?? 0
    }

    /// Matches Objective-C's `[args[key] integerValue]`: a missing key is `0`.
    func integer(_ key: String) -> Int {
        number(key)?.intValue ?? 0
    }

    /// Matches Objective-C's `[args[key] floatValue]`: a missing key is `0`.
    func float(_ key: String) -> Float {
        number(key)?.floatValue ?? 0
    }

    /// Decodes the ARGB integer that Flutter's `Color.value` produces.
    func color(_ key: String) -> UIColor? {
        guard let argb = number(key)?.uint32Value else { return nil }
        let a = CGFloat((argb & 0xFF00_0000) >> 24) / 255.0
        let r = CGFloat((argb & 0x00FF_0000) >> 16) / 255.0
        let g = CGFloat((argb & 0x0000_FF00) >> 8) / 255.0
        let b = CGFloat(argb & 0x0000_00FF) / 255.0
        return UIColor(red: r, green: g, blue: b, alpha: a)
    }
}

// MARK: - Factory

@objc(FLTPDFViewFactory)
final class PDFViewFactory: NSObject, FlutterPlatformViewFactory {
    private let messenger: FlutterBinaryMessenger

    init(messenger: FlutterBinaryMessenger) {
        self.messenger = messenger
        super.init()
    }

    func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        FlutterStandardMessageCodec.sharedInstance()
    }

    func create(
        withFrame frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?
    ) -> FlutterPlatformView {
        PDFViewController(
            frame: frame,
            viewIdentifier: viewId,
            arguments: args,
            binaryMessenger: messenger
        )
    }
}

// MARK: - Platform view / method channel

@objc(FLTPDFViewController)
final class PDFViewController: NSObject, FlutterPlatformView, PDFViewDelegate {
    private var pdfView: FlutterPDFView!
    private let viewId: Int64
    private let channel: FlutterMethodChannel

    init(
        frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?,
        binaryMessenger messenger: FlutterBinaryMessenger
    ) {
        self.viewId = viewId
        channel = FlutterMethodChannel(
            name: "plugins.endigo.io/pdfview_\(viewId)",
            binaryMessenger: messenger
        )
        super.init()

        pdfView = FlutterPDFView(frame: frame, arguments: args, controller: self)

        catchingNSException {
            if let backgroundColor = (args as? [String: Any])?.color("backgroundColor") {
                pdfView.view().backgroundColor = backgroundColor
            }
        } onException: { error in
            NSLog("Exception while setting background color: %@", error.pdfExceptionDescription)
        }

        channel.setMethodCallHandler { [weak self] call, result in
            self?.onMethodCall(call, result: result)
        }
    }

    private func onMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "pageCount":
            pdfView.getPageCount(call, result: result)
        case "currentPageSize":
            pdfView.getCurrentPageSize(call, result: result)
        case "getPosition":
            pdfView.getPosition(call, result: result)
        case "getScale":
            pdfView.getScale(call, result: result)
        case "setPosition":
            pdfView.setPosition(call, result: result)
        case "setScale":
            pdfView.setScale(call, result: result)
        case "currentPage":
            pdfView.getCurrentPage(call, result: result)
        case "setPage":
            pdfView.setPage(call, result: result)
        case "updateSettings":
            pdfView.onUpdateSettings(call, result: result)
        case "setZoomLimits":
            pdfView.setZoomLimits(call, result: result)
        case "reload":
            pdfView.reload(call, result: result)
        case "getScreenshot":
            result(
                FlutterError(
                    code: "UNSUPPORTED",
                    message: "getScreenshot is not implemented on iOS",
                    details: nil
                )
            )
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    func invokeChannelMethod(_ name: String, arguments args: Any?) {
        channel.invokeMethod(name, arguments: args)
    }

    func view() -> UIView {
        pdfView
    }

    deinit {
        // Unregister from the messenger; otherwise the engine keeps one dead
        // handler per created platform view for the app's lifetime (#261).
        channel.setMethodCallHandler(nil)
    }
}

// MARK: - The view itself

@objc(FLTPDFView)
final class FlutterPDFView: UIView, FlutterPlatformView, PDFViewDelegate,
    UIGestureRecognizerDelegate, UIScrollViewDelegate
{
    private weak var controller: PDFViewController?

    private let pdfView: PDFView
    private var document: PDFDocument?
    private var scrollView: UIScrollView?
    private var pageCount: NSNumber?
    private var currentPageIndex: NSNumber?
    private var preventLinkNavigation = false
    private var autoSpacing = false
    private var defaultPage: PDFPage?
    private var currentPage: PDFPage?
    private var pageNo: Int32 = 0
    private var defaultPageSet = false
    private var isIPad = false
    private var isScrolling = false
    private var didLoadComplete = false
    private var contentOffsetObservation: NSKeyValueObservation?
    private var maxScaleFactor: CGFloat = 0
    private var minScaleFactor: CGFloat = 0
    private var hasSentInitialPage = false

    init(frame: CGRect, arguments args: Any?, controller: PDFViewController) {
        self.controller = controller

        // #268: PDFKit emits NaN CoreGraphics errors when PDFView is created with a
        // zero / empty frame (common for Flutter platform views before first layout).
        // Use a temporary non-zero frame; layoutSubviews will size it correctly.
        var pdfFrame = frame
        if pdfFrame.isEmpty || pdfFrame.size.width <= 0 || pdfFrame.size.height <= 0 {
            pdfFrame = CGRect(x: 0, y: 0, width: 100, height: 100)
        }
        pdfView = PDFView(frame: pdfFrame)

        super.init(frame: frame)

        // Detect if device is iPad
        isIPad = UIDevice.current.userInterfaceIdiom == .pad
        isScrolling = false

        pdfView.delegate = self

        loadDocument(arguments: args as? [String: Any])
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func loadDocument(arguments args: [String: Any]?) {
        autoSpacing = args?.bool("autoSpacing") ?? false
        let pageFling = args?.bool("pageFling") ?? false
        let enableSwipe = args?.bool("enableSwipe") ?? false
        preventLinkNavigation = args?.bool("preventLinkNavigation") ?? false

        var defaultPageIndex = args?.integer("defaultPage") ?? 0

        if let filePath = args?["filePath"] as? String {
            // Support plain paths and file:// URIs (#266 parity with Android).
            var sourcePDFUrl: URL?
            if filePath.hasPrefix("file:") {
                sourcePDFUrl = URL(string: filePath)
            }
            if sourcePDFUrl == nil {
                sourcePDFUrl = URL(fileURLWithPath: filePath)
            }
            if let sourcePDFUrl {
                document = PDFDocument(url: sourcePDFUrl)
            }
        } else if let pdfData = args?["pdfData"] as? FlutterStandardTypedData {
            document = PDFDocument(data: pdfData.data)
        }

        guard let document else {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                controller?.invokeChannelMethod(
                    "onError",
                    arguments: [
                        "error": "cannot create document: File not in PDF format or corrupted.",
                    ]
                )
            }
            return
        }

        pdfView.autoresizesSubviews = true
        pdfView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        // #204: Prefer explicit backgroundColor from Flutter; otherwise white
        // (grey 0.95 made continuous pages look non-continuous vs Android).
        let background = args?.color("backgroundColor") ?? .white
        pdfView.backgroundColor = background
        backgroundColor = background

        let swipeHorizontal = args?.bool("swipeHorizontal") ?? false
        pdfView.displayDirection = swipeHorizontal ? .horizontal : .vertical

        let showScrollIndicators = args?.bool("showScrollIndicators") ?? false

        pdfView.autoScales = true

        // UIPageViewController flips one page at a time — only match the API
        // for horizontal book-style paging. Vertical layouts scroll
        // continuously so iOS behaves like Android (#204).
        let useHorizontalPaging = pageFling && swipeHorizontal && enableSwipe
        pdfView.usePageViewController(useHorizontalPaging, withViewOptions: nil)
        pdfView.displayMode = (enableSwipe && !useHorizontalPaging)
            ? .singlePageContinuous
            : .singlePage
        pdfView.displaysPageBreaks = autoSpacing
        if autoSpacing {
            pdfView.pageBreakMargins = UIEdgeInsets(top: 4, left: 0, bottom: 4, right: 0)
        }
        pdfView.document = document

        var maxZoomArg = args?.double("maxZoom") ?? 0
        var minZoomArg = args?.double("minZoom") ?? 0
        if maxZoomArg <= 0 {
            maxZoomArg = 4.0
        }
        if minZoomArg <= 0 {
            minZoomArg = 1.0
        }
        maxScaleFactor = maxZoomArg
        minScaleFactor = minZoomArg

        if let loadedDocument = pdfView.document, loadedDocument.isEncrypted {
            if let password = args?["password"] as? String {
                loadedDocument.unlock(withPassword: password)
            }
            if loadedDocument.isLocked {
                // Android reports a PdfPasswordException through onError;
                // without this the iOS view just stays blank.
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    controller?.invokeChannelMethod(
                        "onError",
                        arguments: ["error": "Password required or incorrect password."]
                    )
                }
            }
        }

        let tapGestureRecognizer = UITapGestureRecognizer(
            target: self,
            action: #selector(onDoubleTap(_:))
        )
        tapGestureRecognizer.numberOfTapsRequired = 2
        tapGestureRecognizer.numberOfTouchesRequired = 1
        tapGestureRecognizer.delegate = self
        tapGestureRecognizer.delaysTouchesBegan = false
        tapGestureRecognizer.delaysTouchesEnded = false
        pdfView.addGestureRecognizer(tapGestureRecognizer)

        let pageCount = document.pageCount
        if pageCount == 0 {
            // Defer like the nil-document path: the Dart handler is only
            // attached after the platform view is created.
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                controller?.invokeChannelMethod(
                    "onError",
                    arguments: ["error": "PDF has no pages."]
                )
            }
            return
        }
        // Objective-C compared an NSUInteger page count against an NSInteger
        // index, so a negative index wrapped around and also clamped to the
        // last page.
        if defaultPageIndex < 0 || defaultPageIndex >= pageCount {
            defaultPageIndex = pageCount - 1
        }

        defaultPage = document.page(at: defaultPageIndex)

        // Delay scroll view configuration to avoid conflicts during
        // initialization. Capture weakly so a disposed view is not
        // reconfigured (#261).
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let strongSelf = self else { return }
            catchingNSException {
                if let scrollView = strongSelf.findScrollView(strongSelf.pdfView) {
                    if strongSelf.isIPad {
                        scrollView.contentInsetAdjustmentBehavior = .automatic
                        if scrollView.delegate == nil {
                            scrollView.delegate = strongSelf
                        }
                    } else {
                        scrollView.contentInsetAdjustmentBehavior = .never
                        scrollView.automaticallyAdjustsScrollIndicatorInsets = false
                    }

                    scrollView.delaysContentTouches = true
                    scrollView.canCancelContentTouches = true
                    // Indicators cannot be shown while the page-view
                    // controller manages paging (swaps scroll views).
                    let shouldShow = showScrollIndicators && !useHorizontalPaging
                    scrollView.showsHorizontalScrollIndicator = shouldShow
                    scrollView.showsVerticalScrollIndicator = shouldShow
                    strongSelf.scrollView = scrollView
                }
                DispatchQueue.main.async { [weak strongSelf] in
                    guard let innerSelf = strongSelf, let document = innerSelf.document else {
                        return
                    }
                    innerSelf.handleRenderCompleted(NSNumber(value: document.pageCount))
                }
            } onException: { error in
                NSLog(
                    "Warning: Failed to configure PDF scroll  view: %@",
                    error.pdfExceptionReason
                )
            }
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePageChanged(_:)),
            name: .PDFViewPageChanged,
            object: pdfView
        )
        addSubview(pdfView)
    }

    deinit {
        // #261: Tear down observers/document so PdfKit resources are released when
        // the Flutter platform view is disposed (e.g. user presses back).
        stopObserving()
        NotificationCenter.default.removeObserver(self)
        if let scrollView, scrollView.delegate === self {
            scrollView.delegate = nil
        }
        pdfView.delegate = nil
        pdfView.document = nil
        pdfView.removeFromSuperview()
        document = nil
        scrollView = nil
        defaultPage = nil
        currentPage = nil
    }

    private func findScrollView(_ view: UIView) -> UIScrollView? {
        if let scrollView = view as? UIScrollView {
            return scrollView
        }
        for subview in view.subviews {
            if let scrollView = findScrollView(subview) {
                return scrollView
            }
        }
        return nil
    }

    /// Block-based replacement for the old manual `addObserver(forKeyPath:)`.
    /// Keeping at most one live observation mirrors the old `_isObserving` flag.
    private func startObserving() {
        guard let scrollView, contentOffsetObservation == nil else { return }
        contentOffsetObservation = scrollView.observe(
            \.contentOffset,
            options: [.new, .old]
        ) { [weak self] _, change in
            let newOffset = change.newValue ?? .zero
            let oldOffset = change.oldValue ?? .zero
            guard newOffset != oldOffset else { return }
            DispatchQueue.main.async { [weak self] in
                self?.handleOnDraw()
            }
        }
    }

    private func stopObserving() {
        contentOffsetObservation?.invalidate()
        contentOffsetObservation = nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        // Skip layout updates during scrolling to prevent conflicts
        if isScrolling {
            return
        }

        // Guard against zero bounds — PDFKit NaN paths (#268).
        if bounds.size.width <= 0 || bounds.size.height <= 0 {
            return
        }

        // Wrap layout updates in try-catch for safety
        var shouldUpdateCachedState = true
        catchingNSException {
            shouldUpdateCachedState = applyLayoutUpdates()
        } onException: { error in
            NSLog("Warning: Layout update failed: %@", error.pdfExceptionReason)
        }
        // An early return inside the old `@try` block returned from
        // `layoutSubviews` outright; a caught exception fell through to the
        // cached-state update below.
        guard shouldUpdateCachedState else { return }

        currentPage = pdfView.currentPage
        pageCount = NSNumber(value: pdfView.document?.pageCount ?? 0)
        if let document = pdfView.document, let currentPage {
            pageNo = Int32(truncatingIfNeeded: document.index(for: currentPage) + 1)
        } else {
            pageNo = 1
        }
    }

    /// Body of the old `@try` block in `layoutSubviews`.
    ///
    /// - Returns: `false` where the Objective-C code returned from
    ///   `layoutSubviews` early, `true` when it fell through.
    private func applyLayoutUpdates() -> Bool {
        pdfView.frame = bounds
        let fitScale = pdfView.scaleFactorForSizeToFit
        // scaleFactorForSizeToFit can be 0/NaN before the document lays out.
        guard fitScale.isFinite, fitScale > 0 else { return false }
        let minScale = fitScale * minScaleFactor
        let maxScale = fitScale * maxScaleFactor
        guard minScale.isFinite, maxScale.isFinite else { return false }
        pdfView.minScaleFactor = minScale
        pdfView.maxScaleFactor = max(maxScale, minScale)

        if autoSpacing || !defaultPageSet {
            let clampedScale = min(max(fitScale, pdfView.minScaleFactor), pdfView.maxScaleFactor)
            if clampedScale.isFinite, clampedScale > 0 {
                pdfView.scaleFactor = clampedScale
            }
        }

        if !defaultPageSet, let defaultPage {
            pdfView.go(to: defaultPage)
            defaultPageSet = true
        }

        if !hasSentInitialPage, defaultPageSet,
           let document = pdfView.document, let currentPage = pdfView.currentPage
        {
            hasSentInitialPage = true
            let currentPageIndex = document.index(for: currentPage)
            let pageCount = document.pageCount
            controller?.invokeChannelMethod(
                "onPageChanged",
                arguments: [
                    "page": NSNumber(value: currentPageIndex),
                    "total": NSNumber(value: pageCount),
                ]
            )
        }
        return true
    }

    func view() -> UIView {
        pdfView
    }

    // MARK: - Method channel handlers

    func getPageCount(_: FlutterMethodCall, result: FlutterResult) {
        result(pageCount)
    }

    func getCurrentPageSize(_: FlutterMethodCall, result: FlutterResult) {
        guard let currentPage = pdfView.currentPage else {
            result(FlutterError(code: "INVALID_STATE", message: "No page loaded", details: nil))
            return
        }
        let bounds = currentPage.bounds(for: .mediaBox)
        result([
            NSNumber(value: Float(bounds.size.width)),
            NSNumber(value: Float(bounds.size.height)),
        ])
    }

    private func calculatePosition() -> [NSNumber] {
        var x: Float = 0.0
        var y: Float = 0.0

        if let scrollView {
            x = Float(-(scrollView.contentOffset.x + scrollView.adjustedContentInset.left))
            y = Float(-(scrollView.contentOffset.y + scrollView.adjustedContentInset.top))
        }

        return [NSNumber(value: x), NSNumber(value: y)]
    }

    func getPosition(_: FlutterMethodCall, result: FlutterResult) {
        guard scrollView != nil else {
            result(FlutterError(code: "INVALID_STATE", message: "PDFView not ready", details: nil))
            return
        }
        result(calculatePosition())
    }

    func getScale(_: FlutterMethodCall, result: FlutterResult) {
        result(NSNumber(value: Float(pdfView.scaleFactor)))
    }

    func setPosition(_ call: FlutterMethodCall, result: FlutterResult) {
        guard let scrollView else {
            result(FlutterError(code: "INVALID_STATE", message: "PDFView not ready", details: nil))
            return
        }

        let arguments = call.arguments as? [String: Any]

        let targetX = -(arguments?.float("xPos") ?? 0)
        let targetY = -(arguments?.float("yPos") ?? 0)

        var targetOffset = CGPoint(x: CGFloat(targetX), y: CGFloat(targetY))

        targetOffset.x -= scrollView.adjustedContentInset.left
        targetOffset.y -= scrollView.adjustedContentInset.top
        let minOffsetY = -scrollView.adjustedContentInset.top
        let maxOffsetY = max(
            minOffsetY,
            scrollView.contentSize.height - scrollView.bounds.size.height
                + scrollView.adjustedContentInset.bottom
        )

        if targetOffset.y < minOffsetY {
            targetOffset.y = minOffsetY
        } else if targetOffset.y > maxOffsetY {
            targetOffset.y = maxOffsetY
        }

        scrollView.setContentOffset(targetOffset, animated: false)

        result(NSNumber(value: true))
    }

    func setScale(_ call: FlutterMethodCall, result: FlutterResult) {
        guard let scale = (call.arguments as? [String: Any])?.number("scale"),
              scale.doubleValue > 0.0
        else {
            result(FlutterError(code: "INVALID_ARGS", message: "scale must be > 0", details: nil))
            return
        }
        pdfView.scaleFactor = CGFloat(scale.doubleValue)
        result(NSNumber(value: true))
    }

    func getCurrentPage(_: FlutterMethodCall, result: FlutterResult) {
        guard let document = pdfView.document, let currentPage = pdfView.currentPage else {
            result(nil)
            return
        }
        let pageIndex = document.index(for: currentPage)
        if pageIndex == NSNotFound {
            result(nil)
            return
        }
        currentPageIndex = NSNumber(value: pageIndex)
        result(currentPageIndex)
    }

    func reload(_: FlutterMethodCall, result: FlutterResult) {
        pdfView.document = document
        if let document, document.pageCount > 0, let firstPage = document.page(at: 0) {
            pdfView.go(to: firstPage)

            let pageBounds = firstPage.bounds(for: .mediaBox)
            pdfView.go(
                to: CGRect(x: 0, y: pageBounds.size.height, width: 1, height: 1),
                on: firstPage
            )

            pdfView.scaleFactor = pdfView.scaleFactorForSizeToFit
        }

        result(NSNumber(value: true))
    }

    func setPage(_ call: FlutterMethodCall, result: FlutterResult) {
        let arguments = call.arguments as? [String: Any]
        // Objective-C read this as an NSUInteger, so a negative index wrapped
        // around and failed the bounds check below.
        let requestedPage = arguments?.number("page")?.int64Value ?? 0
        let pageCount = pdfView.document?.pageCount ?? 0
        guard requestedPage >= 0, requestedPage < Int64(pageCount),
              let page = pdfView.document?.page(at: Int(requestedPage))
        else {
            result(
                FlutterError(
                    code: "INVALID_PAGE",
                    message: "Page index out of bounds",
                    details: nil
                )
            )
            return
        }

        pdfView.go(to: page)
        result(NSNumber(value: true))
    }

    func onUpdateSettings(_: FlutterMethodCall, result: FlutterResult) {
        result(nil)
    }

    func setZoomLimits(_ call: FlutterMethodCall, result: FlutterResult) {
        let arguments = call.arguments as? [String: Any]
        let minZoom = arguments?.float("minZoom") ?? 0
        let maxZoom = arguments?.float("maxZoom") ?? 0
        let fitScale = pdfView.scaleFactorForSizeToFit
        let minScale = Float(Double(minZoom) * Double(fitScale))
        let maxScale = Float(Double(maxZoom) * Double(fitScale))
        pdfView.minScaleFactor = CGFloat(minScale != 0.0 ? minScale : minZoom)
        pdfView.maxScaleFactor = CGFloat(maxScale != 0.0 ? maxScale : maxZoom)
        result(NSNumber(value: true))
    }

    // MARK: - Callbacks

    @objc private func handlePageChanged(_: Notification) {
        guard let document = pdfView.document, let currentPage = pdfView.currentPage else {
            return
        }
        let pageIndex = document.index(for: currentPage)
        if pageIndex == NSNotFound {
            return
        }
        hasSentInitialPage = true
        self.currentPage = currentPage
        pageNo = Int32(truncatingIfNeeded: pageIndex + 1)
        controller?.invokeChannelMethod(
            "onPageChanged",
            arguments: [
                "page": NSNumber(value: pageIndex),
                "total": NSNumber(value: document.pageCount),
            ]
        )
    }

    private func handleRenderCompleted(_ pages: NSNumber) {
        controller?.invokeChannelMethod("onRender", arguments: ["pages": pages])
        if !didLoadComplete {
            didLoadComplete = true
            controller?.invokeChannelMethod("onLoadComplete", arguments: ["pages": pages])
        }
        startObserving()
    }

    private func handleOnDraw() {
        let position = calculatePosition()
        controller?.invokeChannelMethod(
            "onDraw",
            arguments: [
                "pdfXOffset": position[0],
                "pdfYOffset": position[1],
                "pdfScale": NSNumber(value: Float(pdfView.scaleFactor)),
            ]
        )
    }

    // MARK: - PDFViewDelegate

    func pdfViewWillClick(onLink _: PDFView, with url: URL) {
        if !preventLinkNavigation {
            UIApplication.shared.open(url, options: [:]) { success in
                if success {
                    NSLog("URL opened successfully")
                } else {
                    NSLog("Failed to open URL")
                }
            }
        }
        controller?.invokeChannelMethod("onLinkHandler", arguments: url.absoluteString)
    }

    // MARK: - Gestures

    @objc private func onDoubleTap(_ recognizer: UITapGestureRecognizer) {
        guard recognizer.state == .ended else { return }

        // Prevent zooming during scrolling
        if isScrolling {
            return
        }

        catchingNSException {
            if pdfView.scaleFactor == pdfView.scaleFactorForSizeToFit {
                let point = recognizer.location(in: pdfView)
                if let page = pdfView.page(for: point, nearest: true) {
                    let pdfPoint = pdfView.convert(point, to: page)
                    let rect = page.bounds(for: .mediaBox)
                    let destination = PDFDestination(
                        page: page,
                        at: CGPoint(
                            x: pdfPoint.x - (rect.size.width / 4),
                            y: pdfPoint.y + (rect.size.height / 4)
                        )
                    )
                    UIView.animate(withDuration: 0.2) {
                        self.pdfView.scaleFactor = self.pdfView.scaleFactorForSizeToFit * 2
                        self.pdfView.go(to: destination)
                    }
                }
            } else {
                UIView.animate(withDuration: 0.2) {
                    self.pdfView.scaleFactor = self.pdfView.scaleFactorForSizeToFit
                }
            }
        } onException: { error in
            NSLog("Warning: Double-tap zoom failed: %@", error.pdfExceptionReason)
        }
    }

    // MARK: - UIGestureRecognizerDelegate

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        // Allow double-tap to work with scroll gestures. Also allow PDF scroll
        // gestures to compete with a parent Flutter ScrollView (#265) — the
        // Flutter-side EagerGestureRecognizer (if set) still owns claim priority.
        if gestureRecognizer is UITapGestureRecognizer {
            return true
        }
        if gestureRecognizer is UIPanGestureRecognizer
            || otherGestureRecognizer is UIPanGestureRecognizer
        {
            return true
        }
        return false
    }

    // `UIView` already implements this, so this is an override rather than a
    // plain `UIGestureRecognizerDelegate` conformance — same as Objective-C.
    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        // Prevent gesture conflicts during scrolling on iPad
        if isIPad, isScrolling, gestureRecognizer is UITapGestureRecognizer {
            return false
        }
        return true
    }

    // MARK: - UIScrollViewDelegate

    func scrollViewWillBeginDragging(_: UIScrollView) {
        isScrolling = true
    }

    func scrollViewDidEndDragging(_: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            isScrolling = false
        }
    }

    func scrollViewDidEndDecelerating(_: UIScrollView) {
        isScrolling = false
    }

    func scrollViewDidEndScrollingAnimation(_: UIScrollView) {
        isScrolling = false
    }
}
