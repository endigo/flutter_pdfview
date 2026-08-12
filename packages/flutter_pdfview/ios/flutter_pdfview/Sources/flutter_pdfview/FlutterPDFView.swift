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
///
/// Internal rather than file-private so `FPVThemedPage` can guard its own PDFKit
/// calls the same way.
func catchingNSException(_ body: () -> Void, onException: (NSError) -> Void) {
    do {
        try FPVExceptionCatcher.catchException(body)
    } catch {
        onException(error as NSError)
    }
}

extension NSError {
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
        case "unlock":
            pdfView.unlock(call, result: result)
        case "getScreenshot":
            pdfView.getScreenshot(call, result: result)
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
final class FlutterPDFView: UIView, FlutterPlatformView, PDFViewDelegate, PDFDocumentDelegate,
    UIGestureRecognizerDelegate, UIScrollViewDelegate
{
    /// How pages are scaled to the viewport (mirrors Dart [FitPolicy]).
    private enum FitPolicy {
        case width
        case height
        case both
    }

    /// How short documents sit in free space (mirrors Dart [PageAlignment]).
    private enum PageAlignment {
        case center
        case top
    }

    private weak var controller: PDFViewController?

    private let pdfView: PDFView
    private var document: PDFDocument?
    private var scrollView: UIScrollView?
    private var pageCount: NSNumber?
    private var currentPageIndex: NSNumber?
    private var preventLinkNavigation = false
    private var autoSpacing = false
    /// User-supplied inter-page gap in points (#335). `nil` keeps historical
    /// platform defaults (4 top+bottom, or 8 bottom-only with top alignment).
    private var spacing: CGFloat?
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
    private var fitPolicy: FitPolicy = .width
    private var pageAlignment: PageAlignment = .center
    /// Last view size we laid out against — used to re-fit after the temporary
    /// non-zero frame (#268) expands to the real Flutter bounds (#150 / #127).
    private var lastLayoutSize: CGSize = .zero
    /// Fit scale applied for `lastLayoutSize` (before user zoom multiplier).
    private var lastFitScale: CGFloat = 0
    /// Whether we have successfully applied an initial fit at a real size.
    private var hasAppliedInitialFit = false
    /// Whether `finishDocumentSetup()` has already run for this document.
    private var hasFinishedSetup = false
    /// Creation arguments the deferred setup needs once the document unlocks.
    private var defaultPageIndex = 0
    private var showScrollIndicators = false
    private var useHorizontalPaging = false
    /// Creation-time paging inputs, kept so a runtime `enableSwipe` update can
    /// re-derive the display mode exactly like `loadDocument` does.
    private var pageFling = false
    private var swipeHorizontal = false
    /// `enableSwipe` from the creation args, superseded by
    /// [swipeEnabledOverride] once Dart pushes an update.
    private var swipeEnabledAtCreation = false
    /// Bottom `contentInset` the top-alignment path added on its last pass, so a
    /// later pass can recompute from the inset the system owns instead of only
    /// ever growing it.
    private var topAlignmentBottomInset: CGFloat = 0
    /// Creation args held until the view has a non-zero size (#190 / #127).
    private var pendingLoadArguments: [String: Any]?
    /// Ensures the document is opened at most once from creation args.
    private var documentLoadStarted = false
    /// Hide until first successful fit so callers do not see a flash of wrong
    /// scale or an empty surface during transitions (#40).
    private var isContentRevealed = false
    /// Resolved color mode, read by `FPVThemedPage` on every page draw.
    ///
    /// Stored rather than derived on demand so the page never has to touch
    /// `traitCollection` — PDFKit renders pages off the main thread.
    private(set) var isDarkMode = false
    /// Set while `rerenderPreservingPosition()` swaps the document out and back,
    /// so the page churn that causes is not reported to Dart as a page change.
    private var isRerendering = false
    /// Last `enableSwipe` pushed through `updateSettings`, re-applied after a
    /// re-render. `nil` until Dart updates it.
    private var swipeEnabledOverride: Bool?
    /// The swipe state currently in force: the update wins over creation.
    private var isSwipeEnabled: Bool { swipeEnabledOverride ?? swipeEnabledAtCreation }

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
        // Keep blank until first real-size fit to avoid flash / wrong initial
        // scale when the platform view is still 0×0 or a placeholder (#40, #127).
        pdfView.isHidden = true
        isHidden = false
        backgroundColor = .clear
        // PDFKit is vector, but ensure the host layer is not stuck at 1× when the
        // Flutter platform view attaches before a window is available (#158).
        applyDisplayScale()

        pendingLoadArguments = args as? [String: Any]
        // If Flutter already handed us a non-zero frame, open immediately;
        // otherwise wait for layoutSubviews (#190 blank until foreground).
        if hasUsableSize(bounds.size) {
            beginDocumentLoadIfNeeded()
        }
    }

    /// True when both dimensions are finite and large enough for PDFKit layout.
    private func hasUsableSize(_ size: CGSize) -> Bool {
        size.width.isFinite && size.height.isFinite && size.width > 1 && size.height > 1
    }

    private func beginDocumentLoadIfNeeded() {
        guard !documentLoadStarted else { return }
        documentLoadStarted = true
        let args = pendingLoadArguments
        pendingLoadArguments = nil
        loadDocument(arguments: args)
    }

    private func reportError(_ message: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            // Reveal so a parent overlay / empty state is not stuck forever.
            self.revealContentIfNeeded()
            self.controller?.invokeChannelMethod(
                "onError",
                arguments: ["error": message]
            )
        }
    }

    private func revealContentIfNeeded() {
        guard !isContentRevealed else { return }
        isContentRevealed = true
        pdfView.isHidden = false
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Resolves a Flutter-provided path or `file:` / `file://` URI to a file URL.
    ///
    /// `URL(string:)` returns nil for unescaped characters (spaces, etc.). Falling
    /// back to `URL(fileURLWithPath:)` on the full `file://...` string would treat
    /// the scheme as part of the filesystem path and fail to open the document.
    private static func pdfURL(fromFilePath filePath: String) -> URL {
        guard filePath.hasPrefix("file:") else {
            return URL(fileURLWithPath: filePath)
        }

        if let url = URL(string: filePath), url.isFileURL, !url.path.isEmpty {
            return url
        }

        // Strip file: / file:// and optional host, then treat the remainder as a path.
        var path = filePath
        if path.hasPrefix("file://") {
            path = String(path.dropFirst(7))
        } else {
            path = String(path.dropFirst(5))
        }

        // file://localhost/Users/... → /Users/...
        if path.hasPrefix("localhost/") {
            path = String(path.dropFirst(9))
        } else if !path.isEmpty, !path.hasPrefix("/") {
            // file://hostname/path → /path
            if let slash = path.firstIndex(of: "/") {
                path = String(path[slash...])
            }
        }

        if let decoded = path.removingPercentEncoding {
            path = decoded
        }
        return URL(fileURLWithPath: path)
    }

    private func loadDocument(arguments args: [String: Any]?) {
        autoSpacing = args?.bool("autoSpacing") ?? false
        fitPolicy = Self.fitPolicy(fromArguments: args)
        pageAlignment = Self.pageAlignment(fromArguments: args)
        pageFling = args?.bool("pageFling") ?? false
        swipeEnabledAtCreation = args?.bool("enableSwipe") ?? false
        preventLinkNavigation = args?.bool("preventLinkNavigation") ?? false
        setColorMode(Self.colorMode(fromSettings: args) ?? .light)

        defaultPageIndex = args?.integer("defaultPage") ?? 0

        if let filePath = args?["filePath"] as? String {
            // Support plain paths and file:// URIs (#266 parity with Android).
            // URL(string:) returns nil for unescaped characters (spaces, etc.);
            // never fall back to fileURLWithPath on a full "file://..." string.
            let url = Self.pdfURL(fromFilePath: filePath)
            // Harden open path (#190): missing / unreadable files used to leave a
            // blank PDFView with no onError until the app was backgrounded.
            var isDirectory: ObjCBool = false
            let exists = FileManager.default.fileExists(
                atPath: url.path,
                isDirectory: &isDirectory
            )
            if !exists || isDirectory.boolValue {
                reportError(
                    "cannot create document: File not found at \(url.path)."
                )
                return
            }
            if !FileManager.default.isReadableFile(atPath: url.path) {
                reportError(
                    "cannot create document: File is not readable at \(url.path)."
                )
                return
            }
            document = PDFDocument(url: url)
            if document == nil {
                reportError(
                    "cannot create document: File not in PDF format or corrupted."
                )
                return
            }
        } else if let pdfData = args?["pdfData"] as? FlutterStandardTypedData {
            if pdfData.data.isEmpty {
                reportError("cannot create document: pdfData is empty.")
                return
            }
            document = PDFDocument(data: pdfData.data)
            if document == nil {
                reportError(
                    "cannot create document: File not in PDF format or corrupted."
                )
                return
            }
        }

        guard let document else {
            reportError(
                "cannot create document: No filePath or pdfData provided."
            )
            return
        }

        // Pages are instantiated lazily on first access, so the delegate that
        // supplies `FPVThemedPage` has to be in place before anything — including
        // `pdfView.document` below — touches a page.
        document.delegate = self

        pdfView.autoresizesSubviews = true
        pdfView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        // #204: Prefer explicit backgroundColor from Flutter; otherwise white
        // (grey 0.95 made continuous pages look non-continuous vs Android).
        let background = args?.color("backgroundColor") ?? .white
        pdfView.backgroundColor = background
        backgroundColor = background

        swipeHorizontal = args?.bool("swipeHorizontal") ?? false
        pdfView.displayDirection = swipeHorizontal ? .horizontal : .vertical

        showScrollIndicators = args?.bool("showScrollIndicators") ?? false

        // Manage scale ourselves so fitPolicy and autoSpacing stay independent
        // (#150). PDFKit's autoScales always does "fit both" and used to be
        // incorrectly tied to autoSpacing.
        pdfView.autoScales = false

        let paging = derivedPagingConfiguration()
        useHorizontalPaging = paging.usePageViewController
        pdfView.usePageViewController(useHorizontalPaging, withViewOptions: nil)
        pdfView.displayMode = paging.displayMode
        // autoSpacing only controls gaps between pages — never zoom/fit (#150).
        // Optional Dart `spacing` (#335) overrides historical defaults; with
        // PageAlignment.top the break sits only after each page (#272).
        if let spacingNumber = args?.number("spacing") {
            let value = CGFloat(spacingNumber.doubleValue)
            spacing = value >= 0 ? value : 0
        } else {
            spacing = nil
        }
        applyPageBreakMargins()
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

        // An encrypted document loads, but its pages stay unreadable until the
        // right password arrives, so the setup below waits for one.
        let suppliedPassword = args?["password"] as? String ?? ""
        if document.isEncrypted, !suppliedPassword.isEmpty {
            document.unlock(withPassword: suppliedPassword)
        }

        let doubleTapGestureRecognizer = UITapGestureRecognizer(
            target: self,
            action: #selector(onDoubleTap(_:))
        )
        doubleTapGestureRecognizer.numberOfTapsRequired = 2
        doubleTapGestureRecognizer.numberOfTouchesRequired = 1
        doubleTapGestureRecognizer.delegate = self
        doubleTapGestureRecognizer.delaysTouchesBegan = false
        doubleTapGestureRecognizer.delaysTouchesEnded = false
        pdfView.addGestureRecognizer(doubleTapGestureRecognizer)

        // First-class single-tap callback for Dart onTap (#133). Platform-view
        // gestureRecognizers are unreliable for TapGestureRecognizer; report
        // taps from the native PDF view instead. Do not require the double-tap
        // to fail so the callback stays responsive (double-tap zoom still works).
        let singleTapGestureRecognizer = UITapGestureRecognizer(
            target: self,
            action: #selector(onSingleTap(_:))
        )
        singleTapGestureRecognizer.numberOfTapsRequired = 1
        singleTapGestureRecognizer.numberOfTouchesRequired = 1
        singleTapGestureRecognizer.delegate = self
        singleTapGestureRecognizer.delaysTouchesBegan = false
        singleTapGestureRecognizer.delaysTouchesEnded = false
        singleTapGestureRecognizer.cancelsTouchesInView = false
        pdfView.addGestureRecognizer(singleTapGestureRecognizer)
        addSubview(pdfView)

        if document.isLocked {
            reportPasswordRequired(passwordSupplied: !suppliedPassword.isEmpty)
            // Android reports a PdfPasswordException through onError; without
            // this the iOS view just stays blank.
            reportError("Password required or incorrect password.")
            return
        }

        if document.pageCount == 0 {
            // Defer like the nil-document path: the Dart handler is only
            // attached after the platform view is created.
            reportError("PDF has no pages.")
            return
        }

        finishDocumentSetup()
    }

    /// The part of the setup that needs a readable document: runs from
    /// `loadDocument`, or from `applyPassword` once an unlock succeeds.
    private func finishDocumentSetup() {
        guard !hasFinishedSetup, let document else { return }
        hasFinishedSetup = true

        let pageCount = document.pageCount
        // Objective-C compared an NSUInteger page count against an NSInteger
        // index, so a negative index wrapped around and also clamped to the
        // last page.
        if defaultPageIndex < 0 || defaultPageIndex >= pageCount {
            defaultPageIndex = pageCount - 1
        }

        defaultPage = document.page(at: defaultPageIndex)

        // Configure scroll view with defensive handling for iPad.
        // PDFKit may not expose its scroll view immediately; retry a few
        // times instead of a single fixed delay. Capture weakly so a
        // disposed view is not reconfigured (#261).
        let maxAttempts = 5
        let retryDelay: TimeInterval = 0.05
        var configureScrollView: ((Int) -> Void)!
        configureScrollView = { [weak self] attempt in
            guard let strongSelf = self else {
                configureScrollView = nil
                return
            }
            var retryScheduled = false
            catchingNSException {
                let scrollView = strongSelf.findScrollView(strongSelf.pdfView)
                if scrollView == nil, attempt + 1 < maxAttempts {
                    DispatchQueue.main.asyncAfter(deadline: .now() + retryDelay) {
                        configureScrollView(attempt + 1)
                    }
                    retryScheduled = true
                    return
                }

                if let scrollView {
                    strongSelf.adopt(scrollView: scrollView)
                }
            } onException: { error in
                NSLog(
                    "Warning: Failed to configure PDF scroll view: %@",
                    error.pdfExceptionReason
                )
            }
            if retryScheduled {
                return
            }
            // Always report render completion after the configure path
            // finishes (even if the scroll view was never found or the
            // configuration raised).
            DispatchQueue.main.async { [weak strongSelf] in
                guard let innerSelf = strongSelf, let document = innerSelf.document else {
                    return
                }
                innerSelf.handleRenderCompleted(NSNumber(value: document.pageCount))
            }
            configureScrollView = nil
        }
        // Defer the first attempt one run-loop turn so PDFKit can finish
        // installing its internal hierarchy after addSubview.
        DispatchQueue.main.async {
            configureScrollView(0)
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePageChanged(_:)),
            name: .PDFViewPageChanged,
            object: pdfView
        )

        // Force a layout pass now that the document is attached so PDFKit
        // installs its scroll hierarchy before we report onRender. Opening
        // against a deferred non-zero size (#190) still needs an immediate
        // fit so the first paint is correct (#127).
        setNeedsLayout()
        layoutIfNeeded()
        if hasUsableSize(bounds.size) {
            _ = applyLayoutUpdates()
        }
    }

    /// Reopens the document with `password`; returns whether it can now be read.
    /// An unencrypted one simply reloads, matching Android.
    @discardableResult
    private func applyPassword(_ password: String) -> Bool {
        guard let document else { return false }
        if document.isLocked {
            document.unlock(withPassword: password)
        }
        if document.isLocked {
            reportPasswordRequired(passwordSupplied: !password.isEmpty)
            reportError("Password required or incorrect password.")
            return false
        }

        // PDFKit does not re-render a document that was locked when it was
        // handed over, so assign it again.
        pdfView.document = document
        hasAppliedInitialFit = false
        lastFitScale = 0
        lastLayoutSize = .zero
        defaultPageSet = false
        if hasFinishedSetup {
            // Already open, so this was a plain reload — report it like Android,
            // which re-runs the configurator and fires the render callbacks.
            handleRenderCompleted(NSNumber(value: document.pageCount))
        } else {
            finishDocumentSetup()
        }
        setNeedsLayout()
        return true
    }

    private func reportPasswordRequired(passwordSupplied: Bool) {
        // Deferred like the other load-time callbacks: Dart attaches its handler
        // only after the platform view has been created.
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            controller?.invokeChannelMethod(
                "onPasswordRequired",
                arguments: ["incorrect": NSNumber(value: passwordSupplied)]
            )
        }
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

    /// Applies the scroll-view configuration the plugin depends on and caches
    /// the reference. Runs for the scroll view PDFKit installs on load, and
    /// again whenever a display-mode change swaps that view out.
    private func adopt(scrollView: UIScrollView) {
        if isIPad {
            scrollView.contentInsetAdjustmentBehavior = .automatic
            if scrollView.delegate == nil {
                scrollView.delegate = self
            }
        } else {
            scrollView.contentInsetAdjustmentBehavior = .never
            scrollView.automaticallyAdjustsScrollIndicatorInsets = false
        }

        scrollView.delaysContentTouches = true
        scrollView.canCancelContentTouches = true
        // Indicators cannot be shown while the page-view controller manages
        // paging (swaps scroll views).
        let shouldShow = showScrollIndicators && !useHorizontalPaging
        scrollView.showsHorizontalScrollIndicator = shouldShow
        scrollView.showsVerticalScrollIndicator = shouldShow
        self.scrollView = scrollView
    }

    /// Re-discovers the scroll view after PDFKit rebuilds its hierarchy
    /// (`usePageViewController` swaps it out), moving the delegate and the
    /// content-offset observation onto the replacement.
    private func rebindScrollView() {
        guard let found = findScrollView(pdfView), found !== scrollView else { return }
        let wasObserving = contentOffsetObservation != nil
        stopObserving()
        if let previous = scrollView, previous.delegate === self {
            previous.delegate = nil
        }
        // The replacement carries PDFKit's own insets, so nothing of our
        // top-alignment contribution survives on it.
        topAlignmentBottomInset = 0
        adopt(scrollView: found)
        if wasObserving {
            startObserving()
        }
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

    override func didMoveToWindow() {
        super.didMoveToWindow()
        applyDisplayScale()
    }

    /// Matches the PDFView layer to the screen's native scale (Retina / ProMotion).
    private func applyDisplayScale() {
        let scale = window?.screen.scale ?? UIScreen.main.scale
        guard scale > 0 else { return }
        if abs(pdfView.contentScaleFactor - scale) > 0.01 {
            pdfView.contentScaleFactor = scale
        }
        if abs(pdfView.layer.contentsScale - scale) > 0.01 {
            pdfView.layer.contentsScale = scale
        }
        if abs(contentScaleFactor - scale) > 0.01 {
            contentScaleFactor = scale
        }
        if abs(layer.contentsScale - scale) > 0.01 {
            layer.contentsScale = scale
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        applyDisplayScale()

        // Skip layout updates during scrolling to prevent conflicts
        if isScrolling {
            return
        }

        // Guard against zero bounds — PDFKit NaN paths (#268).
        if !hasUsableSize(bounds.size) {
            return
        }

        // #190 / #127: open only once we have a real size so PDFKit does not
        // lock to a 0×0 / placeholder layout that stays blank until the next
        // app lifecycle event.
        beginDocumentLoadIfNeeded()

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
            let pageIndex = document.index(for: currentPage)
            if pageIndex != NSNotFound {
                pageNo = Int32(truncatingIfNeeded: pageIndex + 1)
            }
        }
    }

    /// Parses Dart's `FitPolicy.WIDTH|HEIGHT|BOTH` creation argument.
    private static func fitPolicy(fromArguments args: [String: Any]?) -> FitPolicy {
        guard let policy = args?["fitPolicy"] as? String else { return .width }
        switch policy {
        case "FitPolicy.HEIGHT":
            return .height
        case "FitPolicy.BOTH":
            return .both
        default:
            // WIDTH and any unknown value → width (matches Dart default).
            return .width
        }
    }

    /// Scale that fits the current (or default) page per `fitPolicy`.
    private func fitScaleForCurrentPolicy() -> CGFloat {
        guard pdfView.document != nil else { return 0 }

        var viewSize = pdfView.bounds.size
        if viewSize.width <= 0 || viewSize.height <= 0 {
            viewSize = bounds.size
        }
        guard viewSize.width > 0, viewSize.height > 0 else { return 0 }

        var candidatePage = pdfView.currentPage ?? defaultPage
        if candidatePage == nil, let document = pdfView.document, document.pageCount > 0 {
            candidatePage = document.page(at: 0)
        }
        guard let page = candidatePage else { return 0 }

        let pageRect = page.bounds(for: pdfView.displayBox)
        guard pageRect.size.width > 0, pageRect.size.height > 0 else { return 0 }

        // Account for page rotation so landscape pages fit correctly (#247).
        var pageWidth = pageRect.size.width
        var pageHeight = pageRect.size.height
        if page.rotation == 90 || page.rotation == 270 {
            swap(&pageWidth, &pageHeight)
        }

        let scaleWidth = viewSize.width / pageWidth
        let scaleHeight = viewSize.height / pageHeight
        let scale: CGFloat
        switch fitPolicy {
        case .height:
            scale = scaleHeight
        case .both:
            // Prefer PDFKit's geometry (handles display mode / insets) when ready.
            let pdfKitFit = pdfView.scaleFactorForSizeToFit
            scale = (pdfKitFit.isFinite && pdfKitFit > 0)
                ? pdfKitFit
                : min(scaleWidth, scaleHeight)
        case .width:
            scale = scaleWidth
        }

        guard scale.isFinite, scale > 0 else { return 0 }
        return scale
    }

    /// Body of the old `@try` block in `layoutSubviews`.
    ///
    /// - Returns: `false` where the Objective-C code returned from
    ///   `layoutSubviews` early, `true` when it fell through.
    private func applyLayoutUpdates() -> Bool {
        pdfView.frame = bounds

        // Need a page to compute WIDTH/HEIGHT fit; BOTH can use PDFKit helper.
        guard pdfView.document != nil else { return false }
        if !defaultPageSet, let defaultPage {
            pdfView.go(to: defaultPage)
            defaultPageSet = true
        }

        let fitScale = fitScaleForCurrentPolicy()
        // Fit scale can be 0/NaN before the document lays out.
        guard fitScale.isFinite, fitScale > 0 else { return false }
        let minScale = fitScale * minScaleFactor
        let maxScale = fitScale * maxScaleFactor
        guard minScale.isFinite, maxScale.isFinite else { return false }
        pdfView.minScaleFactor = minScale
        pdfView.maxScaleFactor = max(maxScale, minScale)

        // #150: Fit is independent of autoSpacing. Re-apply when:
        //  - we have not yet applied a fit at a real size, or
        //  - the view size changed (placeholder 100x100 → real bounds, or
        //    rotation) and the user is still at the previous fit scale, or
        //  - the view size changed and the user was zoomed — preserve relative
        //    zoom against the new fit baseline.
        let boundsSize = bounds.size
        let sizeChanged = abs(boundsSize.width - lastLayoutSize.width) > 0.5 ||
            abs(boundsSize.height - lastLayoutSize.height) > 0.5
        let nearPreviousFit = lastFitScale > 0 &&
            abs(pdfView.scaleFactor - lastFitScale) <= max(0.02, lastFitScale * 0.02)

        var targetScale = fitScale
        var shouldSetScale = false
        if !hasAppliedInitialFit {
            shouldSetScale = true
        } else if sizeChanged {
            shouldSetScale = true
            if !nearPreviousFit, lastFitScale > 0 {
                let relative = pdfView.scaleFactor / lastFitScale
                if relative.isFinite, relative > 0 {
                    targetScale = fitScale * relative
                }
            }
        }

        if shouldSetScale {
            let clampedScale = min(max(targetScale, pdfView.minScaleFactor), pdfView.maxScaleFactor)
            if clampedScale.isFinite, clampedScale > 0 {
                pdfView.scaleFactor = clampedScale
            }
            lastFitScale = fitScale
            lastLayoutSize = boundsSize
            hasAppliedInitialFit = true
            // First correct fit at a real size — safe to show content (#40).
            if hasUsableSize(boundsSize) {
                revealContentIfNeeded()
            }
        } else {
            // Still track size so a later change is detected; keep fit baseline.
            lastLayoutSize = boundsSize
            lastFitScale = fitScale
            // If we already fit earlier, keep content visible after resizes.
            if hasAppliedInitialFit {
                revealContentIfNeeded()
            }
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

        // After scale/layout, pin short documents to the top when requested
        // (#250, #272). PDFKit centers by default.
        if pageAlignment == .top {
            pinContentToTop(animated: false)
        }
        return true
    }

    /// Parses Dart's `PageAlignment.center|top` creation argument.
    private static func pageAlignment(fromArguments args: [String: Any]?) -> PageAlignment {
        guard let raw = args?["pageAlignment"] as? String else { return .center }
        switch raw {
        case "PageAlignment.top":
            return .top
        default:
            return .center
        }
    }

    /// Pins the visible page to the top of the viewport and removes the
    /// vertical centering inset PDFKit applies when content is shorter than
    /// the view (#250, #272).
    private func pinContentToTop(animated: Bool) {
        guard let page = pdfView.currentPage ?? defaultPage else { return }

        // Navigate to the top edge of the page (PDF coords: origin bottom-left).
        let pageBounds = page.bounds(for: pdfView.displayBox)
        let topRect = CGRect(
            x: 0,
            y: max(pageBounds.maxY - 1, pageBounds.minY),
            width: max(1, min(1, pageBounds.width)),
            height: max(1, min(1, pageBounds.height))
        )
        pdfView.go(to: topRect, on: page)

        guard let scrollView else { return }

        // Everything in the bottom inset except the free space added on the last
        // pass. Recomputing from this base instead of growing the inset lets it
        // shrink again after a rotation or a zoom past the viewport height, and
        // leaves the iPad's automatic adjustment (safe area) untouched — that
        // lands in `adjustedContentInset`, not here.
        let baseBottom = max(0, scrollView.contentInset.bottom - topAlignmentBottomInset)

        // If the document is shorter than the viewport, PDFKit centers it via
        // content offset / insets. Force free space below the page.
        let contentHeight = scrollView.contentSize.height
        let viewHeight = scrollView.bounds.height
        var inset = scrollView.contentInset
        if contentHeight > 0, contentHeight < viewHeight - 0.5 {
            let extra = viewHeight - contentHeight
            // Keep horizontal insets untouched; put leftover height at the bottom.
            inset.top = 0
            inset.bottom = baseBottom + extra
            topAlignmentBottomInset = extra
            if inset != scrollView.contentInset {
                scrollView.contentInset = inset
            }
            let topY = -scrollView.adjustedContentInset.top
            let offset = CGPoint(x: scrollView.contentOffset.x, y: topY)
            scrollView.setContentOffset(offset, animated: animated)
        } else {
            // Tall document: drop the free space a previous short-content pass
            // added, otherwise a blank scroll region stays below the content.
            if topAlignmentBottomInset != 0 {
                inset.bottom = baseBottom
                topAlignmentBottomInset = 0
                if inset != scrollView.contentInset {
                    scrollView.contentInset = inset
                }
            }
            // Still ensure we are at the top of the current page destination
            // (go(to:) above), without rewriting the remaining insets.
            let topY = -scrollView.adjustedContentInset.top
            if scrollView.contentOffset.y < topY - 0.5 {
                scrollView.setContentOffset(
                    CGPoint(x: scrollView.contentOffset.x, y: topY),
                    animated: animated
                )
            }
        }
    }

    func view() -> UIView {
        pdfView
    }

    // MARK: - Method channel handlers

    func getPageCount(_: FlutterMethodCall, result: FlutterResult) {
        if let pageCount {
            result(pageCount)
            return
        }
        // `pageCount` is only cached once a layout pass has run, which can land
        // after the render callback — most visibly right after an unlock. A
        // still-locked document has no readable pages, so it reports nothing.
        guard let document = pdfView.document, !document.isLocked else {
            result(nil)
            return
        }
        result(NSNumber(value: document.pageCount))
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

    func unlock(_ call: FlutterMethodCall, result: FlutterResult) {
        guard let password = (call.arguments as? [String: Any])?["password"] as? String else {
            result(
                FlutterError(code: "INVALID_ARGS", message: "password is required", details: nil)
            )
            return
        }
        // The initial open is deferred until the view has a usable size (#190),
        // so an unlock that lands first has to trigger it.
        if document == nil {
            beginDocumentLoadIfNeeded()
        }
        result(NSNumber(value: applyPassword(password)))
    }

    func reload(_: FlutterMethodCall, result: FlutterResult) {
        // If the initial open was deferred and never completed (still no size),
        // try again now rather than reassigning a nil document.
        if document == nil {
            beginDocumentLoadIfNeeded()
            result(NSNumber(value: document != nil))
            return
        }

        pdfView.document = document
        hasAppliedInitialFit = false
        lastFitScale = 0
        lastLayoutSize = .zero
        isContentRevealed = false
        pdfView.isHidden = true
        if let document, document.pageCount > 0, let firstPage = document.page(at: 0) {
            pdfView.go(to: firstPage)

            let pageBounds = firstPage.bounds(for: .mediaBox)
            pdfView.go(
                to: CGRect(x: 0, y: pageBounds.size.height, width: 1, height: 1),
                on: firstPage
            )

            let fitScale = fitScaleForCurrentPolicy()
            if fitScale.isFinite, fitScale > 0 {
                pdfView.scaleFactor = fitScale
                lastFitScale = fitScale
                lastLayoutSize = bounds.size
                hasAppliedInitialFit = true
                revealContentIfNeeded()
            }
        }

        result(NSNumber(value: true))
    }

    func setPage(_ call: FlutterMethodCall, result: FlutterResult) {
        let arguments = call.arguments as? [String: Any]
        // Objective-C read this as an NSUInteger, so a negative index wrapped
        // around and failed the bounds check below.
        let requestedPage = arguments?.number("page")?.int64Value ?? 0
        // #251: Android animates via jumpTo(page, withAnimation). PDFKit has no
        // equivalent scroll animation for go(to:), so the flag is accepted and
        // ignored — the jump is always instant.
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
        if pageAlignment == .top {
            pinContentToTop(animated: false)
        }
        result(NSNumber(value: true))
    }

    /// Applies `displaysPageBreaks` + `pageBreakMargins` from [autoSpacing],
    /// [pageAlignment], and optional user [spacing] (#335 / #272 / #150).
    private func applyPageBreakMargins() {
        pdfView.displaysPageBreaks = autoSpacing
        guard autoSpacing else {
            pdfView.pageBreakMargins = .zero
            return
        }
        if pageAlignment == .top {
            let gap = spacing ?? 8
            pdfView.pageBreakMargins = UIEdgeInsets(top: 0, left: 0, bottom: gap, right: 0)
        } else {
            let gap = spacing ?? 4
            pdfView.pageBreakMargins = UIEdgeInsets(top: gap, left: 0, bottom: gap, right: 0)
        }
    }

    /// Applies the settings Dart pushes when a `PDFView` is rebuilt with
    /// different values.
    ///
    /// Until 1.5.0 this was a no-op stub and every key was silently dropped, so
    /// apps that relied on updates not taking effect will now see them applied.
    /// Keys iOS cannot honour (`pageFling`, `pageSnap`) and keys it does not know
    /// are accepted and ignored — never rejected — because a `FlutterError` here
    /// surfaces as an unhandled exception in the app's build phase.
    func onUpdateSettings(_ call: FlutterMethodCall, result: FlutterResult) {
        guard let settings = call.arguments as? [String: Any] else {
            result(nil)
            return
        }

        // A rebuild with a new password reopens the document; a null one
        // arrives as NSNull and is ignored here.
        if let password = settings["password"] as? String {
            applyPassword(password)
        }

        // `colorMode` and `backgroundColor` arrive in the same map and both want
        // the view repainted, so state is recorded first and the (expensive)
        // re-render runs once at the end.
        var needsRerender = false

        if settings.keys.contains("colorMode") || settings.keys.contains("nightMode"),
           let mode = Self.colorMode(fromSettings: settings)
        {
            needsRerender = setColorMode(mode)
        }

        if settings.keys.contains("backgroundColor"), let color = settings.color("backgroundColor") {
            // Only pages go through the color matrix on iOS, so the gutter is set
            // to exactly what Dart asked for. A present-but-null value keeps the
            // current color (documented: clearing back to null is not supported).
            pdfView.backgroundColor = color
            backgroundColor = color
        }

        if settings.keys.contains("preventLinkNavigation") {
            preventLinkNavigation = settings.bool("preventLinkNavigation")
        }

        if settings.keys.contains("enableSwipe") {
            swipeEnabledOverride = settings.bool("enableSwipe")
            applySwipeEnabled()
            // Scrolling alone is not swiping: a view created with
            // `enableSwipe: false` sits in `.singlePage`, so the layout has to
            // be re-derived too or the update cannot move between pages.
            applyPagingConfiguration()
        }

        if settings.keys.contains("minZoom") || settings.keys.contains("maxZoom") {
            // Either key can arrive on its own; keep the other multiplier.
            var minZoom = minScaleFactor
            var maxZoom = maxScaleFactor
            if let requested = settings.number("minZoom")?.doubleValue, requested > 0 {
                minZoom = CGFloat(requested)
            }
            if let requested = settings.number("maxZoom")?.doubleValue, requested > 0 {
                maxZoom = CGFloat(requested)
            }
            // Unlike setZoomLimits this cannot report INVALID_ARGS, so an
            // inverted pair is dropped rather than applied.
            if minZoom > 0, maxZoom >= minZoom {
                applyZoomLimits(minZoom: minZoom, maxZoom: maxZoom)
            }
        }


        if settings.keys.contains("pageAlignment") {
            pageAlignment = Self.pageAlignment(fromArguments: settings)
            // Update page-break margins to match top vs center (#272 / #335).
            applyPageBreakMargins()
            if pageAlignment == .top {
                pinContentToTop(animated: false)
            } else if let scrollView {
                // Give back only what top alignment added; an inset the system
                // owns is not ours to clear.
                var inset = scrollView.contentInset
                inset.bottom = max(0, inset.bottom - topAlignmentBottomInset)
                topAlignmentBottomInset = 0
                scrollView.contentInset = inset
            }
            setNeedsLayout()
        }

        if needsRerender {
            rerenderPreservingPosition()
        }
        result(nil)
    }

    func setZoomLimits(_ call: FlutterMethodCall, result: FlutterResult) {
        let arguments = call.arguments as? [String: Any]
        let minZoom = CGFloat(arguments?.double("minZoom") ?? 0)
        let maxZoom = CGFloat(arguments?.double("maxZoom") ?? 0)
        // Match Android's validation (INVALID_ARGS) instead of silently
        // accepting zero/inverted limits.
        guard minZoom > 0, maxZoom > 0, maxZoom >= minZoom else {
            result(
                FlutterError(
                    code: "INVALID_ARGS",
                    message: "Expected 0 < minZoom \u{2264} maxZoom",
                    details: nil
                )
            )
            return
        }
        applyZoomLimits(minZoom: minZoom, maxZoom: maxZoom)
        result(NSNumber(value: true))
    }

    /// Stores the zoom multipliers and derives PDFKit's absolute limits from the
    /// current fit scale. Callers are responsible for validating the pair.
    private func applyZoomLimits(minZoom: CGFloat, maxZoom: CGFloat) {
        // Persist the multipliers — applyLayoutUpdates re-derives PDFKit's
        // min/max from these on every layout pass, so writing only the PDFKit
        // values would be reverted by the next rotation/resize.
        minScaleFactor = minZoom
        maxScaleFactor = maxZoom
        var fitScale = fitScaleForCurrentPolicy()
        if !fitScale.isFinite || fitScale <= 0 {
            fitScale = pdfView.scaleFactorForSizeToFit
        }
        // Before the document lays out, fitScale can still be 0/NaN — skip the
        // immediate application and let the next layout pass apply the stored
        // multipliers instead of feeding NaN into PDFKit (#268).
        if fitScale.isFinite, fitScale > 0 {
            let minScale = fitScale * minZoom
            let maxScale = fitScale * maxZoom
            pdfView.minScaleFactor = minScale
            pdfView.maxScaleFactor = max(maxScale, minScale)
        }
    }

    private func applySwipeEnabled() {
        guard let enabled = swipeEnabledOverride else { return }
        // The scroll view is discovered asynchronously after load, so fall back to
        // a fresh lookup if the update lands first.
        let target = scrollView ?? findScrollView(pdfView)
        target?.isScrollEnabled = enabled
    }

    /// The page layout the current swipe state implies.
    ///
    /// UIPageViewController flips one page at a time — only match the API for
    /// horizontal book-style paging. Vertical layouts scroll continuously so iOS
    /// behaves like Android (#204). With swiping off, a single page is shown and
    /// the neighbouring pages stay out of reach.
    private func derivedPagingConfiguration() -> (usePageViewController: Bool, displayMode: PDFDisplayMode) {
        let enableSwipe = isSwipeEnabled
        let paging = pageFling && swipeHorizontal && enableSwipe
        return (paging, (enableSwipe && !paging) ? .singlePageContinuous : .singlePage)
    }

    /// Re-applies [derivedPagingConfiguration] after `enableSwipe` changed at
    /// runtime, keeping the reader's page and zoom.
    ///
    /// PDFKit rebuilds its view hierarchy for either change — and
    /// `usePageViewController` replaces the scroll view outright — so the
    /// position is captured first and the scroll view re-adopted afterwards.
    private func applyPagingConfiguration() {
        // Before the document opens, `loadDocument` derives this from the same
        // state, so there is nothing to re-apply yet.
        guard pdfView.document != nil else { return }

        let paging = derivedPagingConfiguration()
        guard paging.usePageViewController != useHorizontalPaging
            || paging.displayMode != pdfView.displayMode
        else {
            return
        }

        let savedScale = pdfView.scaleFactor
        let savedDestination = pdfView.currentDestination
        let savedPage = pdfView.currentPage

        // The page churn a rebuild causes is not a page change for Dart.
        isRerendering = true
        catchingNSException {
            if paging.usePageViewController != useHorizontalPaging {
                useHorizontalPaging = paging.usePageViewController
                pdfView.usePageViewController(useHorizontalPaging, withViewOptions: nil)
            }
            pdfView.displayMode = paging.displayMode
            rebindScrollView()

            // A rebuild resets PDFKit's own scale factors, so re-derive them
            // before restoring the scale or the restore is clamped away.
            applyZoomLimits(minZoom: minScaleFactor, maxZoom: maxScaleFactor)
            if savedScale.isFinite, savedScale > 0 {
                pdfView.scaleFactor = savedScale
            }
            if let savedDestination {
                pdfView.go(to: savedDestination)
            } else if let savedPage {
                pdfView.go(to: savedPage)
            }
        } onException: { error in
            NSLog(
                "Warning: Failed to apply swipe display mode: %@",
                error.pdfExceptionReason
            )
        }
        isRerendering = false

        applySwipeEnabled()
        if pageAlignment == .top {
            pinContentToTop(animated: false)
        }
        setNeedsLayout()
    }

    // MARK: - Color mode

    /// Parses `colorMode` (`"PdfColorMode.dark"`, `"dark"`, …), falling back to
    /// the deprecated `nightMode` boolean. `nil` when neither key is usable.
    private static func colorMode(fromSettings settings: [String: Any]?) -> FPVColorMode? {
        if let raw = settings?["colorMode"] as? String {
            // Accepts both `enum.toString()` and `enum.name` spellings.
            let token = (raw.split(separator: ".").last.map(String.init) ?? raw).lowercased()
            switch token {
            case "light":
                return .light
            case "dark":
                return .dark
            case "system":
                return .system
            default:
                break
            }
        }
        if let nightMode = settings?.number("nightMode")?.boolValue {
            return nightMode ? .dark : .light
        }
        return nil
    }

    /// - Returns: `true` when the resolved mode actually changed, i.e. when the
    ///   caller has to force a re-render.
    @discardableResult
    private func setColorMode(_ mode: FPVColorMode) -> Bool {
        let resolved: Bool
        switch mode {
        case .light:
            resolved = false
        case .dark:
            resolved = true
        case .system:
            // Dart normally resolves `system` from the app's Theme; this is only
            // the fallback for a caller that passes it through verbatim.
            resolved = traitCollection.userInterfaceStyle == .dark
        }
        guard resolved != isDarkMode else { return false }
        isDarkMode = resolved
        return true
    }

    /// Forces every visible page through `FPVThemedPage.draw` again without
    /// losing the reader's place.
    ///
    /// PDFKit caches rendered pages and exposes no cache-flush API, so the
    /// document has to be handed back to the view — the same primitive `reload`
    /// uses. Unlike `reload` this restores the page, scale and scroll offset, and
    /// leaves the #150 fit state (`hasAppliedInitialFit` / `lastFitScale` /
    /// `lastLayoutSize`) untouched so the next layout pass does not re-fit.
    private func rerenderPreservingPosition() {
        guard let document = pdfView.document else { return }

        let savedScale = pdfView.scaleFactor
        let savedDestination = pdfView.currentDestination
        let savedOffset = scrollView?.contentOffset
        let savedPage = pdfView.currentPage

        isRerendering = true
        catchingNSException {
            pdfView.document = nil
            pdfView.document = document

            // Reassigning the document resets PDFKit's own min/max scale factors,
            // so re-derive them before restoring the scale — otherwise the restore
            // is clamped to PDFKit's defaults.
            applyZoomLimits(minZoom: minScaleFactor, maxZoom: maxScaleFactor)

            if savedScale.isFinite, savedScale > 0 {
                pdfView.scaleFactor = savedScale
            }
            if let savedDestination {
                pdfView.go(to: savedDestination)
            } else if let savedPage {
                pdfView.go(to: savedPage)
            }
            // The destination restores the page and the point within it; the raw
            // offset pins the remaining sub-page scroll. PDFKit keeps the same
            // scroll view across a document swap, so the cached reference (and the
            // contentOffset observation on it) stays valid.
            if let savedOffset, let scrollView {
                scrollView.setContentOffset(savedOffset, animated: false)
            }
            applySwipeEnabled()
        } onException: { error in
            NSLog("Warning: Failed to re-render after settings update: %@", error.pdfExceptionReason)
        }
        isRerendering = false
    }

    /// Captures the currently visible PDF contents and writes a PNG to `fileName`.
    ///
    /// Flutter platform views / hybrid composition leave `drawHierarchy` and
    /// snapshot helpers blank (white). We rasterize the real PDFKit layer, and
    /// if that is still empty fall back to drawing the current [PDFPage]
    /// into the viewport (#175).
    func getScreenshot(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let fileName = (call.arguments as? [String: Any])?["fileName"] as? String,
              !fileName.isEmpty
        else {
            result(
                FlutterError(code: "FAIL", message: "fileName is required", details: nil)
            )
            return
        }

        let outputURL = URL(fileURLWithPath: fileName)
        // Require a directory component so we don't silently write next to CWD.
        guard outputURL.pathComponents.count > 1,
              !outputURL.deletingLastPathComponent().path.isEmpty
        else {
            result(
                FlutterError(
                    code: "FAIL",
                    message: "fileName must include a directory path",
                    details: nil
                )
            )
            return
        }

        let size = pdfView.bounds.size
        guard size.width > 0, size.height > 0 else {
            result(
                FlutterError(
                    code: "FAIL",
                    message: "PDFView is not laid out yet",
                    details: nil
                )
            )
            return
        }

        let image: UIImage
        var captureError: NSError?
        var captured: UIImage?
        catchingNSException {
            captured = self.capturePDFImage(size: size)
        } onException: { error in
            captureError = error
            NSLog("getScreenshot capture failed: %@", error.pdfExceptionDescription)
        }

        if let captureError {
            result(
                FlutterError(
                    code: "FAIL",
                    message: "Failed to generate image",
                    details: captureError.pdfExceptionReason
                )
            )
            return
        }
        guard let captured else {
            result(
                FlutterError(
                    code: "FAIL",
                    message: "Failed to generate image",
                    details: nil
                )
            )
            return
        }
        image = captured

        guard let data = image.pngData() else {
            result(
                FlutterError(
                    code: "FAIL",
                    message: "Failed to generate image",
                    details: "PNG encoding failed"
                )
            )
            return
        }

        do {
            try FileManager.default.createDirectory(
                at: outputURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try data.write(to: outputURL, options: .atomic)
            result(outputURL.path)
        } catch {
            result(
                FlutterError(
                    code: "FAIL",
                    message: "Failed to generate image",
                    details: error.localizedDescription
                )
            )
        }
    }

    /// Renders the visible PDF into a bitmap without relying on drawing-cache /
    /// hierarchy snapshots (blank under Flutter platform views).
    private func capturePDFImage(size: CGSize) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.opaque = true
        format.scale = UIScreen.main.scale
        let renderer = UIGraphicsImageRenderer(size: size, format: format)

        // 1) Preferred: rasterize the PDFKit layer (includes zoom/scroll).
        let layerImage = renderer.image { ctx in
            let cg = ctx.cgContext
            captureBackgroundColor.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            pdfView.layer.render(in: cg)
        }
        if !isMostlyBlank(layerImage) {
            return layerImage
        }

        // 2) Fallback: draw the current page into the viewport via PDFKit.
        //    This always has real page content even when the platform-view layer
        //    is not snapshot-friendly.
        return renderer.image { ctx in
            let cg = ctx.cgContext
            captureBackgroundColor.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))

            guard let page = pdfView.currentPage else { return }
            let pageRect = page.bounds(for: .mediaBox)
            guard pageRect.width > 0, pageRect.height > 0 else { return }

            // Fit the page into the viewport the same way PDFView would for a
            // single-page snapshot (preserve aspect, center).
            let scale = min(size.width / pageRect.width, size.height / pageRect.height)
            let drawWidth = pageRect.width * scale
            let drawHeight = pageRect.height * scale
            let originX = (size.width - drawWidth) / 2
            let originY = (size.height - drawHeight) / 2

            cg.saveGState()
            // PDFKit page coordinates are bottom-up; flip to UIKit space.
            cg.translateBy(x: originX, y: originY + drawHeight)
            cg.scaleBy(x: scale, y: -scale)
            cg.translateBy(x: -pageRect.origin.x, y: -pageRect.origin.y)
            page.draw(with: .mediaBox, to: cg)
            cg.restoreGState()
        }
    }

    /// The color both capture passes fill behind the page — and the reference
    /// the blank check measures against.
    private var captureBackgroundColor: UIColor {
        pdfView.backgroundColor ?? .white
    }

    /// The 8-bit components a full-coverage fill with `color` leaves in the
    /// opaque capture bitmap. Falls back to white, the color
    /// `capturePDFImage` fills with when the view has no background.
    private static func sampleComponents(
        of color: UIColor,
        for traits: UITraitCollection
    ) -> (r: Int, g: Int, b: Int) {
        var red: CGFloat = 1
        var green: CGFloat = 1
        var blue: CGFloat = 1
        var alpha: CGFloat = 1
        guard color.resolvedColor(with: traits)
            .getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        else {
            return (255, 255, 255)
        }
        // The capture context is opaque and starts black, so a translucent
        // background composites down toward black.
        let component = { (value: CGFloat) -> Int in
            Int((min(max(value * alpha, 0), 1) * 255).rounded())
        }
        return (component(red), component(green), component(blue))
    }

    /// True when the image is effectively the configured background color, i.e.
    /// a failed snapshot with no page content in it.
    private func isMostlyBlank(_ image: UIImage) -> Bool {
        guard let cgImage = image.cgImage else { return true }
        // Downscale into a tiny buffer so we only inspect a handful of pixels.
        let sampleW = 16
        let sampleH = 16
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * sampleW
        var data = [UInt8](repeating: 0, count: bytesPerRow * sampleH)
        guard let context = CGContext(
            data: &data,
            width: sampleW,
            height: sampleH,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return false
        }
        context.interpolationQuality = .low
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: sampleW, height: sampleH))

        // Ink is anything that differs from the background the capture filled
        // with — comparing against white instead made every sample of a dark
        // or tinted background look like content, so a solid-color snapshot
        // was returned rather than the page fallback (#175).
        let background = Self.sampleComponents(of: captureBackgroundColor, for: traitCollection)
        // Same slack the old fixed 250/255 white threshold allowed.
        let tolerance = 5
        var inkPixels = 0
        let total = sampleW * sampleH
        for i in 0..<total {
            let offset = i * bytesPerPixel
            let r = Int(data[offset])
            let g = Int(data[offset + 1])
            let b = Int(data[offset + 2])
            if abs(r - background.r) > tolerance
                || abs(g - background.g) > tolerance
                || abs(b - background.b) > tolerance
            {
                inkPixels += 1
            }
        }
        // If fewer than ~2% of samples have ink, treat as a blank capture.
        return total == 0 || (Double(inkPixels) / Double(total)) < 0.02
    }

    // MARK: - Callbacks

    @objc private func handlePageChanged(_: Notification) {
        // Swapping the document out and back fires this for the intermediate
        // state; the page the user is on has not actually changed.
        if isRerendering {
            return
        }
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
        // If fit applied earlier we already revealed; if not (edge case where
        // scale was not yet computable), still show so #190 does not leave a
        // permanently hidden view after onRender.
        if hasAppliedInitialFit || hasUsableSize(bounds.size) {
            revealContentIfNeeded()
        }
        controller?.invokeChannelMethod("onRender", arguments: ["pages": pages])
        if !didLoadComplete {
            didLoadComplete = true
            controller?.invokeChannelMethod("onLoadComplete", arguments: ["pages": pages])
        }
        startObserving()
        // Post one more layout pass after PDFKit finishes installing pages so
        // the first visible frame uses the real bounds (#127).
        DispatchQueue.main.async { [weak self] in
            guard let self, self.hasUsableSize(self.bounds.size) else { return }
            self.setNeedsLayout()
            self.layoutIfNeeded()
        }
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

    // MARK: - PDFDocumentDelegate

    /// Installed unconditionally, in every color mode: `FPVThemedPage` reads the
    /// mode at draw time, so a theme change never has to re-instantiate pages.
    @objc func classForPage() -> AnyClass {
        FPVThemedPage.self
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

    @objc private func onSingleTap(_ recognizer: UITapGestureRecognizer) {
        guard recognizer.state == .ended else { return }
        // Skip while scrolling so page-fling / drag does not look like a tap.
        if isScrolling {
            return
        }
        controller?.invokeChannelMethod("onTap", arguments: nil)
    }

    @objc private func onDoubleTap(_ recognizer: UITapGestureRecognizer) {
        guard recognizer.state == .ended else { return }

        // Prevent zooming during scrolling
        if isScrolling {
            return
        }

        catchingNSException {
            var fitScale = fitScaleForCurrentPolicy()
            if !fitScale.isFinite || fitScale <= 0 {
                fitScale = pdfView.scaleFactorForSizeToFit
            }
            guard fitScale.isFinite, fitScale > 0 else {
                return
            }
            let atFit = abs(pdfView.scaleFactor - fitScale) <= max(0.02, fitScale * 0.02)
            if atFit {
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
                        self.pdfView.scaleFactor = fitScale * 2
                        self.pdfView.go(to: destination)
                    }
                }
            } else {
                UIView.animate(withDuration: 0.2) {
                    self.pdfView.scaleFactor = fitScale
                    self.lastFitScale = fitScale
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
