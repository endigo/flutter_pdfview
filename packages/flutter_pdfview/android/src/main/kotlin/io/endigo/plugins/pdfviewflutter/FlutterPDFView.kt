package io.endigo.plugins.pdfviewflutter

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Context
import android.content.ContextWrapper
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.ColorMatrix
import android.graphics.ColorMatrixColorFilter
import android.graphics.Paint
import android.graphics.Rect
import android.graphics.RectF
import android.graphics.drawable.ColorDrawable
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.util.Log
import android.util.SparseArray
import android.view.GestureDetector
import android.view.MotionEvent
import android.view.PixelCopy
import android.view.View
import android.view.ViewGroup
import android.view.Window
import android.widget.FrameLayout

import androidx.annotation.VisibleForTesting
import androidx.pdf.Highlight
import androidx.pdf.PdfDocument
import androidx.pdf.PdfPasswordException
import androidx.pdf.PdfPoint
import androidx.pdf.PdfRect
import androidx.pdf.SandboxedPdfLoader
import androidx.pdf.content.ExternalLink
import androidx.pdf.selection.ContextMenuComponent
import androidx.pdf.selection.PdfSelectionMenuKeys
import androidx.pdf.selection.Selection
import androidx.pdf.selection.model.TextSelection
import androidx.pdf.view.PdfView

import java.io.File
import java.io.FileOutputStream

import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.platform.PlatformView

import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

/**
 * Android engine built on Jetpack androidx.pdf: Android's own PDF renderer,
 * loaded in a sandboxed service, behind `PdfView`. It replaces
 * AndroidPdfViewer/PDFium (now the opt-in `flutter_pdfview_android_pdfium`
 * package) and speaks the same method-channel contract, plus the text layer.
 *
 * Not available here, by design of `PdfView`: horizontal paging
 * (`swipeHorizontal`, `pageFling`, `pageSnap` are ignored) and Android < 9.
 */
class FlutterPDFView(
    private val context: Context,
    messenger: BinaryMessenger,
    id: Int,
    creationParams: Map<String, Any?>,
) : PlatformView, MethodCallHandler {

    /** Mutable so a password given later is used by every reopen. */
    private val params: MutableMap<String, Any?> = HashMap(creationParams)

    private val methodChannel = MethodChannel(messenger, "plugins.endigo.io/pdfview_$id")
    private val mainHandler = Handler(Looper.getMainLooper())
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private val loader = SandboxedPdfLoader(context, Dispatchers.IO)
    private val displayDensity = context.resources.displayMetrics.density
    private val viewId = id

    private val container = TouchInterceptLayout(context)
    private var pdfView: PdfView? = PdfView(context, null, 0)

    @Volatile
    private var disposed = false

    // ---------------------------------------------------------------- document
    private var document: PdfDocument? = null
    private var loadJob: Job? = null
    private var pageCount = 0
    private var pageWidths = FloatArray(0)
    private var pageHeights = FloatArray(0)
    private var maxPageWidth = 0f
    private var maxPageHeight = 0f

    /** Copy of `pdfData` on disk; `PdfRenderer` needs a seekable file descriptor. */
    private var dataFile: File? = null

    /** Pending `unlock`, settled once its reopen succeeds or fails. */
    private var pendingUnlockResult: Result? = null

    // ---------------------------------------------------------------- layout
    private val fitPolicy = getFitPolicy(params)
    private var pageAlignment = getPageAlignment(params)
    private var minZoomFactor = getFloat(params, "minZoom", DEFAULT_MIN_ZOOM)
    private var maxZoomFactor = getFloat(params, "maxZoom", DEFAULT_MAX_ZOOM)

    /** Absolute zoom of "page fitted per [fitPolicy]"; 0 until measured. */
    private var fitZoom = 0f
    private var hasAppliedInitialFit = false
    private var defaultPage = getInt(params, "defaultPage")
    private var firstContentLoaded = false
    private var currentPage = -1
    private var lastDrawTime = 0L
    private val onDrawArgs: MutableMap<String, Any> = HashMap()

    // ---------------------------------------------------------------- behaviour
    private var enableSwipe = getBoolean(params, "enableSwipe", true)
    private var preventLinkNavigation = getBoolean(params, "preventLinkNavigation")
    private var enableTextSelection =
        getBoolean(params, "enableTextSelection", DEFAULT_ENABLE_TEXT_SELECTION)
    private var enableCopy = getBoolean(params, "enableCopy", DEFAULT_ENABLE_COPY)

    /** Active color transform, or null for light mode. */
    private var colorMatrix: FloatArray? = null
    private var requestedBackgroundColor: Int? = null

    // ---------------------------------------------------------------- text layer
    private class SearchMatch(val page: Int, val bounds: List<RectF>, val text: String)

    private var searchMatches: List<SearchMatch> = emptyList()
    private var currentSearchIndex = -1
    private var searchJob: Job? = null
    private var lastReportedSelectionText: String? = null

    init {
        val view = pdfView!!
        container.addView(
            view,
            FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT,
            ),
        )
        methodChannel.setMethodCallHandler(this)

        if (getBoolean(params, "swipeHorizontal")) {
            Log.w(
                TAG,
                "swipeHorizontal is not supported by the androidx.pdf engine; pages scroll " +
                    "vertically. Add flutter_pdfview_android_pdfium for horizontal paging.",
            )
        }

        applyPagePlacement(view)
        if (!getBoolean(params, "showScrollIndicators")) {
            hideFastScroller(view)
        }

        requestedBackgroundColor = (params["backgroundColor"] as? Number)?.toInt()
        colorMatrix = resolveColorMatrix(params)
        applyColorTheme()

        installListeners(view)
        openDocument(passwordParam(), result = null)
    }

    override fun getView(): View = container

    // ================================================================ loading

    private fun passwordParam(): String? = (params["password"] as? String)?.takeIf { it.isNotEmpty() }

    /** URI of the document to open, writing `pdfData` to a private file first. */
    private suspend fun documentUri(): Uri? {
        val filePath = params["filePath"] as? String
        if (filePath != null) {
            return getURI(filePath)
        }
        val data = params["pdfData"] as? ByteArray ?: return null
        val existing = dataFile
        if (existing != null && existing.exists()) {
            return Uri.fromFile(existing)
        }
        val file = withContext(Dispatchers.IO) {
            val dir = File(context.cacheDir, DATA_DIR).apply { mkdirs() }
            File.createTempFile("pdfview_${viewId}_", ".pdf", dir).also { it.writeBytes(data) }
        }
        dataFile = file
        return Uri.fromFile(file)
    }

    /**
     * Opens (or reopens) the document with [password]. [result], when given, is
     * settled with whether the document is now readable.
     */
    private fun openDocument(password: String?, result: Result?) {
        // A newer open supersedes one still in flight.
        completeUnlock(false)
        pendingUnlockResult = result
        loadJob?.cancel()
        loadJob = scope.launch {
            try {
                val uri = documentUri()
                if (uri == null) {
                    reportError("cannot create document: No filePath or pdfData provided.")
                    completeUnlock(false)
                    return@launch
                }
                Log.i(TAG, "Opening $uri (password: ${password != null})")
                val opened = loader.openDocument(uri, password)
                Log.i(TAG, "Opened document: ${opened.pageCount} pages")
                if (disposed) {
                    opened.close()
                    return@launch
                }
                val infos = opened.getPageInfos(0 until opened.pageCount)
                onDocumentOpened(opened, infos)
                completeUnlock(true)
            } catch (e: CancellationException) {
                throw e
            } catch (e: PdfPasswordException) {
                Log.i(TAG, "Password required or incorrect: ${e.message}")
                if (!disposed) {
                    notifyPasswordRequired(passwordSupplied = !password.isNullOrEmpty())
                    reportError(e.toString())
                }
                completeUnlock(false)
            } catch (e: Exception) {
                Log.w(TAG, "openDocument", e)
                if (!disposed) {
                    reportError(e.toString())
                }
                completeUnlock(false)
            }
        }
    }

    private fun onDocumentOpened(opened: PdfDocument, infos: List<PdfDocument.PageInfo>) {
        val view = pdfView ?: run {
            opened.close()
            return
        }
        val previous = document
        document = opened
        pageCount = opened.pageCount
        pageWidths = FloatArray(pageCount)
        pageHeights = FloatArray(pageCount)
        for (info in infos) {
            if (info.pageNum in 0 until pageCount) {
                pageWidths[info.pageNum] = info.width.toFloat()
                pageHeights[info.pageNum] = info.height.toFloat()
            }
        }
        maxPageWidth = pageWidths.maxOrNull() ?: 0f
        maxPageHeight = pageHeights.maxOrNull() ?: 0f

        firstContentLoaded = false
        hasAppliedInitialFit = false
        currentPage = -1
        clearSearchState(notify = false)

        view.pdfDocument = opened
        previous?.close()
        applyFitZoom(view)
        Log.i(
            TAG,
            "Document attached: view ${container.width}x${container.height}, fitZoom=$fitZoom, " +
                "attached=${view.isAttachedToWindow}",
        )

        methodChannel.invokeMethod("onLoadComplete", mapOf("pages" to pageCount))
    }

    private fun onFirstContentLoad() {
        Log.i(TAG, "First content loaded")
        val view = pdfView ?: return
        if (disposed || document == null) return
        firstContentLoaded = true
        applyFitZoom(view)
        if (defaultPage in 1 until pageCount) {
            view.scrollToPage(defaultPage)
        }
        updateCurrentPage(view, force = true)
        methodChannel.invokeMethod("onRender", mapOf("pages" to pageCount))
    }

    // ================================================================ listeners

    private fun installListeners(view: PdfView) {
        view.addOnFirstContentLoadListener { onFirstContentLoad() }

        view.addOnViewportChangedListener(object : PdfView.OnViewportChangedListener {
            override fun onViewportChanged(
                firstVisiblePage: Int,
                visiblePagesCount: Int,
                pageLocations: SparseArray<RectF>,
                zoomLevel: Float,
            ) {
                if (disposed) return
                updateCurrentPage(view, firstVisiblePage, pageLocations)
                reportDraw(view)
            }
        })

        view.setLinkClickListener(object : PdfView.LinkClickListener {
            override fun onLinkClicked(externalLink: ExternalLink): Boolean {
                handleExternalLink(externalLink.uri.toString())
                // Always handled here: only http(s) is opened, and only when the
                // app has not asked to handle links itself.
                return true
            }
        })

        view.addOnSelectionChangedListener(object : PdfView.OnSelectionChangedListener {
            override fun onSelectionChanged(newSelection: Selection?) {
                onSelectionChanged(view, newSelection)
            }
        })

        view.addSelectionMenuItemPreparer(object : PdfView.SelectionMenuItemPreparer {
            override fun onPrepareSelectionMenuItems(components: MutableList<ContextMenuComponent>) {
                if (!enableCopy) {
                    components.removeAll { it.key in COPY_MENU_KEYS }
                }
            }
        })

        val tapDetector = GestureDetector(
            context,
            object : GestureDetector.SimpleOnGestureListener() {
                override fun onSingleTapConfirmed(e: MotionEvent): Boolean {
                    if (!disposed) {
                        methodChannel.invokeMethod("onTap", null)
                    }
                    return false
                }
            },
        )
        container.interceptor = { event ->
            tapDetector.onTouchEvent(event)
            // enableSwipe: false keeps the reader on the current position by
            // withholding one-finger drags; pinch-zoom and taps still work.
            !enableSwipe && event.pointerCount == 1 && event.actionMasked == MotionEvent.ACTION_MOVE
        }

        container.addOnLayoutChangeListener { _, left, top, right, bottom, oldLeft, oldTop, oldRight, oldBottom ->
            if ((right - left) != (oldRight - oldLeft) || (bottom - top) != (oldBottom - oldTop)) {
                pdfView?.let { applyFitZoom(it) }
            }
        }
    }

    private fun updateCurrentPage(
        view: PdfView,
        firstVisiblePage: Int = view.firstVisiblePage,
        pageLocations: SparseArray<RectF>? = null,
        force: Boolean = false,
    ) {
        if (pageCount <= 0) return
        var page = firstVisiblePage
        if (pageLocations != null && pageLocations.size() > 0) {
            val n = pageLocations.size()
            val pages = IntArray(n)
            val tops = FloatArray(n)
            val bottoms = FloatArray(n)
            for (i in 0 until n) {
                pages[i] = pageLocations.keyAt(i)
                val rect = pageLocations.valueAt(i)
                tops[i] = rect.top
                bottoms[i] = rect.bottom
            }
            page = ViewportMath.mostVisiblePage(
                pages, tops, bottoms, view.height.toFloat(), firstVisiblePage,
            )
        }
        page = page.coerceIn(0, pageCount - 1)
        if ((page != currentPage || force) && firstContentLoaded) {
            currentPage = page
            methodChannel.invokeMethod(
                "onPageChanged",
                mapOf("page" to page, "total" to pageCount),
            )
        }
    }

    private fun reportDraw(view: PdfView) {
        // Monotonic: a wall-clock rollback would otherwise suppress onDraw.
        val now = SystemClock.uptimeMillis()
        if (now - lastDrawTime < DRAW_THROTTLE_MS) return
        lastDrawTime = now
        onDrawArgs.clear()
        onDrawArgs["pdfXOffset"] = -view.scrollX / displayDensity
        onDrawArgs["pdfYOffset"] = -view.scrollY / displayDensity
        onDrawArgs["pdfScale"] = ViewportMath.toRelativeScale(view.zoom, fitZoom)
        methodChannel.invokeMethod("onDraw", onDrawArgs)
    }

    private fun handleExternalLink(uri: String) {
        if (disposed) return
        if (!preventLinkNavigation && isBrowserScheme(Uri.parse(uri).scheme)) {
            // Only browser links are launched: file:// throws on API 24+, and
            // intent:// / content:// can reach host-app components.
            try {
                val intent = Intent(Intent.ACTION_VIEW, Uri.parse(uri))
                    .addCategory(Intent.CATEGORY_BROWSABLE)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                context.startActivity(intent)
            } catch (e: ActivityNotFoundException) {
                Log.w(TAG, "No activity for link $uri", e)
            } catch (e: RuntimeException) {
                Log.w(TAG, "Failed to open link $uri", e)
            }
        }
        methodChannel.invokeMethod("onLinkHandler", uri)
    }

    // ================================================================ zoom / placement

    /** Re-derives [fitZoom] and PdfView's absolute zoom limits from the current size. */
    private fun applyFitZoom(view: PdfView) {
        val newFit = ViewportMath.fitZoom(
            fitPolicy, container.width, container.height, maxPageWidth, maxPageHeight,
        )
        if (newFit <= 0f) return
        val relative = if (hasAppliedInitialFit) {
            ViewportMath.toRelativeScale(view.zoom, fitZoom)
        } else {
            1f
        }
        fitZoom = newFit
        applyZoomLimits(view)
        view.zoom = ViewportMath.toViewZoom(relative, fitZoom)
        hasAppliedInitialFit = true
    }

    private fun applyZoomLimits(view: PdfView) {
        if (fitZoom <= 0f) return
        var min = minZoomFactor
        val max = maxZoomFactor
        if (min > max) {
            // Same rule as AndroidPdfViewer's creation path.
            min = max
        }
        view.minZoom = ViewportMath.toViewZoom(min, fitZoom)
        view.maxZoom = ViewportMath.toViewZoom(max, fitZoom)
    }

    private fun applyPagePlacement(view: PdfView) {
        view.verticalAlignment = if (pageAlignment == PageAlignment.TOP) {
            PdfView.VERTICAL_ALIGNMENT_TOP
        } else {
            PdfView.VERTICAL_ALIGNMENT_CENTER
        }
        val spacingDp = resolvePageSpacingDp(
            autoSpacing = getBoolean(params, "autoSpacing", true),
            spacing = getIntOrNull(params, "spacing"),
        )
        if (spacingDp != null) {
            view.verticalPageSpacing = (spacingDp * displayDensity).toInt()
        }
    }

    private fun hideFastScroller(view: PdfView) {
        view.fastScrollVerticalThumbDrawable = ColorDrawable(Color.TRANSPARENT)
        view.fastScrollPageIndicatorBackgroundDrawable = ColorDrawable(Color.TRANSPARENT)
    }

    // ================================================================ color

    /**
     * Applies [colorMatrix] as a hardware-layer color filter, compensating the
     * gutter background so it still shows the color Dart asked for (the matrix is
     * an involution). Same approach as the PDFium engine.
     */
    private fun applyColorTheme() {
        val view = pdfView ?: return
        val matrix = colorMatrix
        if (matrix != null) {
            val paint = Paint().apply {
                colorFilter = ColorMatrixColorFilter(ColorMatrix(matrix.copyOf()))
            }
            view.setLayerType(View.LAYER_TYPE_HARDWARE, paint)
            view.setBackgroundColor(
                requestedBackgroundColor?.let { PdfColorMatrix.transformColor(it, matrix) }
                    ?: Color.TRANSPARENT,
            )
        } else {
            view.setLayerType(View.LAYER_TYPE_NONE, null)
            view.setBackgroundColor(requestedBackgroundColor ?: Color.TRANSPARENT)
        }
        view.invalidate()
    }

    private fun resolveColorMatrix(settings: Map<String, Any?>): FloatArray? {
        if (settings.containsKey("colorMode")) {
            return matrixForColorMode(settings["colorMode"] as? String)
        }
        return if (getBoolean(settings, "nightMode")) PdfColorMatrix.LUMINANCE_INVERT else null
    }

    private fun matrixForColorMode(mode: String?): FloatArray? =
        if (mode == "dark") PdfColorMatrix.LUMINANCE_INVERT else null

    // ================================================================ method channel

    override fun onMethodCall(methodCall: MethodCall, result: Result) {
        if (disposed) {
            result.success(null)
            return
        }
        when (methodCall.method) {
            "pageCount" -> result.success(pageCount)
            "currentPageSize" -> getCurrentPageSize(result)
            "getPosition" -> getPosition(result)
            "getScale" -> result.success(
                pdfView?.let { ViewportMath.toRelativeScale(it.zoom, fitZoom) } ?: 1f,
            )
            "setPosition" -> setPosition(methodCall, result)
            "setScale" -> setScale(methodCall, result)
            "getScreenshot" -> getScreenshot(methodCall, result)
            "reload" -> {
                openDocument(passwordParam(), result = null)
                result.success(true)
            }
            "unlock" -> unlock(methodCall, result)
            "currentPage" -> result.success(currentPage.coerceAtLeast(0))
            "setPage" -> setPage(methodCall, result)
            "updateSettings" -> {
                @Suppress("UNCHECKED_CAST")
                applySettings(methodCall.arguments as? Map<String, Any?> ?: emptyMap())
                result.success(null)
            }
            "setZoomLimits" -> setZoomLimits(methodCall, result)
            "isTextLayerSupported" -> result.success(true)
            "searchText" -> searchText(methodCall, result)
            "nextMatch" -> result.success(
                activateMatch(ViewportMath.nextMatchIndex(currentSearchIndex, searchMatches.size)),
            )
            "previousMatch" -> result.success(
                activateMatch(
                    ViewportMath.previousMatchIndex(currentSearchIndex, searchMatches.size),
                ),
            )
            "setCurrentMatch" -> result.success(
                activateMatch(methodCall.argument<Number>("index")?.toInt() ?: -1),
            )
            "clearSearch" -> {
                clearSearchState(notify = true)
                result.success(null)
            }
            "getSelectedText" -> result.success(selectedText())
            "clearSelection" -> {
                clearSelection(notify = true)
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun getCurrentPageSize(result: Result) {
        val page = currentPage.coerceAtLeast(0)
        if (pageCount == 0 || page >= pageCount) {
            result.error("INVALID_STATE", "No pages loaded", null)
            return
        }
        // Same unit as the PDFium engine: pixels at the fitted zoom.
        val zoom = if (fitZoom > 0f) fitZoom else 1f
        result.success(floatArrayOf(pageWidths[page] * zoom, pageHeights[page] * zoom))
    }

    private fun getPosition(result: Result) {
        val view = pdfView ?: run {
            result.error("INVALID_STATE", "PDFView disposed", null)
            return
        }
        // Negative scroll offsets, as AndroidPdfViewer reported them.
        result.success(
            floatArrayOf(-view.scrollX / displayDensity, -view.scrollY / displayDensity),
        )
    }

    private fun setPosition(call: MethodCall, result: Result) {
        val view = pdfView ?: run {
            result.success(false)
            return
        }
        val x = call.argument<Number>("xPos")?.toFloat() ?: 0f
        val y = call.argument<Number>("yPos")?.toFloat() ?: 0f
        view.scrollTo((-x * displayDensity).toInt(), (-y * displayDensity).toInt())
        result.success(true)
    }

    private fun setScale(call: MethodCall, result: Result) {
        val view = pdfView ?: run {
            result.success(false)
            return
        }
        val scale = call.argument<Number>("scale")?.toFloat() ?: 1f
        if (fitZoom > 0f) {
            view.zoom = ViewportMath.toViewZoom(scale, fitZoom)
        }
        result.success(true)
    }

    private fun setZoomLimits(call: MethodCall, result: Result) {
        val min = call.argument<Number>("minZoom")?.toFloat() ?: 1f
        val mid = call.argument<Number>("midZoom")?.toFloat() ?: 1f
        val max = call.argument<Number>("maxZoom")?.toFloat() ?: 1f
        if (min <= 0f || mid <= 0f || max <= 0f || min > mid || mid > max) {
            result.error("INVALID_ARGS", "Expected 0 < minZoom ≤ midZoom ≤ maxZoom", null)
            return
        }
        // PdfView's double tap has its own targets, so midZoom is validated
        // for compatibility but has no effect.
        minZoomFactor = min
        maxZoomFactor = max
        pdfView?.let { applyZoomLimits(it) }
        result.success(true)
    }

    private fun setPage(call: MethodCall, result: Result) {
        val page = call.argument<Number>("page")?.toInt()
        val view = pdfView
        if (page == null || view == null) {
            result.success(false)
            return
        }
        if (!firstContentLoaded) {
            // Applied once the first content is laid out.
            defaultPage = page
            result.success(true)
            return
        }
        // PdfView has no instant/animated choice; withAnimation is accepted.
        view.scrollToPage(page.coerceIn(0, (pageCount - 1).coerceAtLeast(0)))
        result.success(true)
    }

    private fun unlock(call: MethodCall, result: Result) {
        val password = call.argument<String>("password")
        if (password == null) {
            result.error("INVALID_ARGS", "password is required", null)
            return
        }
        params["password"] = password
        openDocument(password.takeIf { it.isNotEmpty() }, result)
    }

    private fun completeUnlock(success: Boolean) {
        val pending = pendingUnlockResult ?: return
        pendingUnlockResult = null
        pending.success(success)
    }

    private fun notifyPasswordRequired(passwordSupplied: Boolean) {
        methodChannel.invokeMethod("onPasswordRequired", mapOf("incorrect" to passwordSupplied))
    }

    private fun reportError(message: String) {
        methodChannel.invokeMethod("onError", mapOf("error" to message))
    }

    private fun applySettings(settings: Map<String, Any?>) {
        val view = pdfView ?: return
        var colorThemeDirty = false
        for ((key, value) in settings) {
            when (key) {
                "enableSwipe" -> enableSwipe = getBoolean(settings, key, true)
                "colorMode" -> {
                    colorMatrix = matrixForColorMode(value as? String)
                    colorThemeDirty = true
                }
                "nightMode" -> {
                    colorMatrix = if (getBoolean(settings, key)) {
                        PdfColorMatrix.LUMINANCE_INVERT
                    } else {
                        null
                    }
                    colorThemeDirty = true
                }
                "backgroundColor" -> {
                    requestedBackgroundColor = (value as? Number)?.toInt()
                    colorThemeDirty = true
                }
                "preventLinkNavigation" -> preventLinkNavigation = getBoolean(settings, key)
                "pageAlignment" -> {
                    pageAlignment = getPageAlignment(settings)
                    applyPagePlacement(view)
                }
                "maxZoom" -> maxZoomFactor = getFloat(settings, key, DEFAULT_MAX_ZOOM)
                "minZoom" -> minZoomFactor = getFloat(settings, key, DEFAULT_MIN_ZOOM)
                "password" -> {
                    params["password"] = value as? String
                    openDocument(passwordParam(), result = null)
                }
                "enableTextSelection" -> {
                    enableTextSelection =
                        getBoolean(settings, key, DEFAULT_ENABLE_TEXT_SELECTION)
                    if (!enableTextSelection) {
                        clearSelection(notify = true)
                    }
                }
                "enableCopy" -> enableCopy = getBoolean(settings, key, DEFAULT_ENABLE_COPY)
                // pageFling / pageSnap only apply to horizontal paging, which
                // this engine does not have; anything unknown is ignored rather
                // than failing the rebuild that sent it.
                else -> Unit
            }
        }
        if (settings.containsKey("minZoom") || settings.containsKey("maxZoom")) {
            applyZoomLimits(view)
        }
        if (colorThemeDirty) {
            applyColorTheme()
        }
    }

    // ================================================================ text layer

    private fun searchText(call: MethodCall, result: Result) {
        val query = call.argument<String>("query") ?: ""
        val caseSensitive = call.argument<Boolean>("caseSensitive") ?: false
        val doc = document
        searchJob?.cancel()
        if (query.isEmpty() || doc == null) {
            clearSearchState(notify = true)
            result.success(emptyList<Map<String, Any?>>())
            return
        }
        searchJob = scope.launch {
            val matches = try {
                findMatches(doc, query, caseSensitive)
            } catch (e: CancellationException) {
                result.success(emptyList<Map<String, Any?>>())
                throw e
            } catch (e: Exception) {
                Log.w(TAG, "searchText", e)
                result.error("SEARCH_FAILED", e.toString(), null)
                return@launch
            }
            if (disposed || document !== doc) {
                result.success(emptyList<Map<String, Any?>>())
                return@launch
            }
            searchMatches = matches
            if (matches.isEmpty()) {
                currentSearchIndex = -1
                pdfView?.setHighlights(emptyList())
                reportSearchResultChanged(-1, 0)
                result.success(emptyList<Map<String, Any?>>())
                return@launch
            }
            // Activate the first hit so the user sees a result immediately.
            activateMatch(0)
            result.success(matches.indices.mapNotNull { matchMap(it) })
        }
    }

    private suspend fun findMatches(
        doc: PdfDocument,
        query: String,
        caseSensitive: Boolean,
    ): List<SearchMatch> {
        val hits = doc.searchDocument(query, 0 until doc.pageCount)
        val matches = ArrayList<SearchMatch>()
        for (page in 0 until doc.pageCount) {
            val pageHits = hits.get(page) ?: continue
            if (pageHits.isEmpty()) continue
            // PdfRenderer searches case-insensitively; narrow the hits against
            // the page text when the caller asked for an exact-case match.
            val pageText = if (caseSensitive) {
                doc.getPageContent(page)?.textContents?.joinToString("") { it.text }
            } else {
                null
            }
            for (hit in pageHits) {
                if (caseSensitive &&
                    !ViewportMath.matchesCaseSensitively(pageText, hit.textStartIndex, query)
                ) {
                    continue
                }
                val text = pageText
                    ?.takeIf { hit.textStartIndex >= 0 && hit.textStartIndex + query.length <= it.length }
                    ?.substring(hit.textStartIndex, hit.textStartIndex + query.length)
                    ?: query
                matches.add(SearchMatch(page, hit.bounds.map { RectF(it) }, text))
            }
        }
        return matches
    }

    /** Makes match [index] current, highlights every match and scrolls to it. */
    private fun activateMatch(index: Int): Map<String, Any?>? {
        val view = pdfView ?: return null
        if (index !in searchMatches.indices) return null
        currentSearchIndex = index
        val highlights = ArrayList<Highlight>()
        searchMatches.forEachIndexed { i, match ->
            val color = if (i == index) CURRENT_MATCH_COLOR else MATCH_COLOR
            for (rect in match.bounds) {
                highlights.add(Highlight(PdfRect(match.page, rect), color))
            }
        }
        view.setHighlights(highlights)
        val target = searchMatches[index]
        val first = target.bounds.firstOrNull()
        if (first != null) {
            view.scrollToPosition(PdfPoint(target.page, first.left, first.top))
        } else {
            view.scrollToPage(target.page)
        }
        reportSearchResultChanged(index, searchMatches.size)
        return matchMap(index)
    }

    private fun matchMap(index: Int): Map<String, Any?>? {
        val match = searchMatches.getOrNull(index) ?: return null
        return mapOf("pageIndex" to match.page, "matchIndex" to index, "text" to match.text)
    }

    private fun clearSearchState(notify: Boolean) {
        searchJob?.cancel()
        searchMatches = emptyList()
        currentSearchIndex = -1
        pdfView?.setHighlights(emptyList())
        // Deliberately leaves any user text selection alone, like iOS.
        if (notify) {
            reportSearchResultChanged(-1, 0)
        }
    }

    private fun reportSearchResultChanged(currentIndex: Int, total: Int) {
        methodChannel.invokeMethod(
            "onSearchResultChanged",
            mapOf("currentIndex" to currentIndex, "total" to total),
        )
    }

    private fun selectedText(): String? {
        if (!enableTextSelection) return null
        return (pdfView?.currentSelection as? TextSelection)?.text?.toString()
    }

    private fun onSelectionChanged(view: PdfView, selection: Selection?) {
        if (disposed) return
        if (selection != null && !enableTextSelection) {
            // PdfView has no switch for text selection; drop it as it appears.
            view.clearCurrentSelection()
            return
        }
        val text = (selection as? TextSelection)?.text?.toString()
        if (text == lastReportedSelectionText) return
        lastReportedSelectionText = text
        methodChannel.invokeMethod("onTextSelectionChanged", mapOf("text" to text))
    }

    private fun clearSelection(notify: Boolean) {
        pdfView?.clearCurrentSelection()
        val hadSelection = lastReportedSelectionText != null
        lastReportedSelectionText = null
        if (notify && hadSelection) {
            methodChannel.invokeMethod("onTextSelectionChanged", mapOf("text" to null))
        }
    }

    // ================================================================ screenshot

    private fun getScreenshot(call: MethodCall, result: Result) {
        val fileName = call.argument<String>("fileName")
        if (fileName.isNullOrEmpty()) {
            result.error("FAIL", "fileName is required", null)
            return
        }
        val outputFile = File(fileName)
        if (outputFile.parentFile == null) {
            result.error("FAIL", "fileName must include a directory path", null)
            return
        }
        val target = container
        val width = target.width
        val height = target.height
        if (width <= 0 || height <= 0) {
            result.error("FAIL", "PDFView is not laid out yet", null)
            return
        }
        // Prefer PixelCopy of the real window pixels under hybrid composition
        // (#175); fall back to a software draw.
        val window = findWindow(context)
        if (window != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            target.isAttachedToWindow
        ) {
            val location = IntArray(2)
            target.getLocationInWindow(location)
            val srcRect = Rect(location[0], location[1], location[0] + width, location[1] + height)
            val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
            try {
                PixelCopy.request(window, srcRect, bitmap, { copyResult ->
                    if (disposed) {
                        bitmap.recycle()
                        result.error("FAIL", "PDFView disposed", null)
                        return@request
                    }
                    if (copyResult == PixelCopy.SUCCESS) {
                        writeScreenshot(outputFile, bitmap, result)
                    } else {
                        bitmap.recycle()
                        val fallback = drawToBitmap(target)
                        if (fallback == null) {
                            result.error("FAIL", "Failed to generate image", "PixelCopy result=$copyResult")
                        } else {
                            writeScreenshot(outputFile, fallback, result)
                        }
                    }
                }, mainHandler)
                return
            } catch (e: IllegalArgumentException) {
                bitmap.recycle()
                Log.w(TAG, "PixelCopy unavailable, using software capture", e)
            }
        }
        val bitmap = drawToBitmap(target)
        if (bitmap == null) {
            result.error("FAIL", "PDFView is not laid out yet", null)
        } else {
            writeScreenshot(outputFile, bitmap, result)
        }
    }

    private fun drawToBitmap(target: View): Bitmap? {
        val width = target.width
        val height = target.height
        if (width <= 0 || height <= 0) return null
        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        canvas.drawColor(requestedBackgroundColor ?: Color.WHITE)
        val matrix = colorMatrix
        if (matrix != null) {
            // View.draw bypasses the hardware layer paint, so apply the theme here.
            val paint = Paint().apply {
                colorFilter = ColorMatrixColorFilter(ColorMatrix(matrix.copyOf()))
            }
            canvas.saveLayer(null, paint)
            target.draw(canvas)
            canvas.restore()
        } else {
            target.draw(canvas)
        }
        return bitmap
    }

    private fun writeScreenshot(outputFile: File, bitmap: Bitmap, result: Result) {
        try {
            outputFile.parentFile?.takeIf { !it.exists() }?.mkdirs()
            FileOutputStream(outputFile, false).use { bitmap.compress(Bitmap.CompressFormat.PNG, 100, it) }
            result.success(outputFile.absolutePath)
        } catch (e: Exception) {
            result.error("FAIL", "Failed to generate image", e.message)
        } finally {
            bitmap.recycle()
        }
    }

    private fun findWindow(context: Context): Window? {
        var ctx: Context? = context
        while (ctx is ContextWrapper) {
            if (ctx is Activity) return ctx.window
            ctx = ctx.baseContext
        }
        return null
    }

    // ================================================================ lifecycle

    override fun dispose() {
        disposed = true
        // Settle an unlock that will never finish now, so its caller stops waiting.
        completeUnlock(false)
        methodChannel.setMethodCallHandler(null)
        container.interceptor = null
        scope.cancel()
        val view = pdfView
        pdfView = null
        val doc = document
        document = null
        try {
            view?.pdfDocument = null
        } catch (e: Exception) {
            Log.w(TAG, "dispose: detach document", e)
        }
        try {
            doc?.close()
        } catch (e: Exception) {
            Log.w(TAG, "dispose: close document", e)
        }
        dataFile?.delete()
        dataFile = null
    }

    /** Dart [PageAlignment] mirrored for creation-param parsing. */
    enum class PageAlignment {
        CENTER,
        TOP,
    }

    companion object {
        const val TAG = "FlutterPDFView"

        private const val DEFAULT_MAX_ZOOM = 4.0f
        private const val DEFAULT_MIN_ZOOM = 1.0f
        private const val DRAW_THROTTLE_MS = 16L
        private const val DATA_DIR = "flutter_pdfview"

        /** Matches Dart [PDFView.enableTextSelection] default. */
        const val DEFAULT_ENABLE_TEXT_SELECTION = true

        /** Matches Dart [PDFView.enableCopy] default. */
        const val DEFAULT_ENABLE_COPY = true

        /** Every match is tinted; the current one stronger. */
        private const val MATCH_COLOR = 0x55FFEB3B
        private const val CURRENT_MATCH_COLOR = 0x99FF9800.toInt()

        /** Selection-menu items that let text leave the document. */
        private val COPY_MENU_KEYS: Set<Any> = setOf(
            PdfSelectionMenuKeys.CopyKey,
            PdfSelectionMenuKeys.CopyLinkKey,
            PdfSelectionMenuKeys.SmartActionKey,
        )

        @JvmStatic
        @VisibleForTesting
        fun isBrowserScheme(scheme: String?): Boolean =
            scheme != null && (scheme.equals("http", ignoreCase = true) ||
                scheme.equals("https", ignoreCase = true))

        /**
         * Inter-page gap in dp for `PdfView.verticalPageSpacing`, or null to keep
         * PdfView's own default.
         *
         * - [autoSpacing] false → 0 (pages touch, as before).
         * - [spacing] given → that value (#335), never negative.
         * - otherwise → null.
         */
        @JvmStatic
        @VisibleForTesting
        fun resolvePageSpacingDp(autoSpacing: Boolean, spacing: Int?): Int? {
            if (!autoSpacing) return 0
            if (spacing != null) return maxOf(0, spacing)
            return null
        }

        @JvmStatic
        @VisibleForTesting
        fun getBoolean(params: Map<String, Any?>, key: String): Boolean =
            getBoolean(params, key, false)

        /** Boolean param, [defaultValue] when the key is missing or null. */
        @JvmStatic
        @VisibleForTesting
        fun getBoolean(params: Map<String, Any?>, key: String, defaultValue: Boolean): Boolean {
            if (!params.containsKey(key)) return defaultValue
            val value = params[key] as Boolean?
            return value ?: defaultValue
        }

        @JvmStatic
        @VisibleForTesting
        fun getPageAlignment(params: Map<String, Any?>): PageAlignment =
            when (getString(params, "pageAlignment")) {
                "PageAlignment.top" -> PageAlignment.TOP
                else -> PageAlignment.CENTER
            }

        @JvmStatic
        @VisibleForTesting
        fun getString(params: Map<String, Any?>, key: String): String? =
            if (params.containsKey(key)) params[key] as String? else ""

        @JvmStatic
        @VisibleForTesting
        fun getInt(params: Map<String, Any?>, key: String): Int {
            val value = params[key] as Int?
            return if (params.containsKey(key)) value ?: 0 else 0
        }

        /** Optional int param: missing / null → null (#335 spacing). */
        @JvmStatic
        @VisibleForTesting
        fun getIntOrNull(params: Map<String, Any?>, key: String): Int? {
            if (!params.containsKey(key)) return null
            return when (val value = params[key]) {
                is Int -> value
                is Number -> value.toInt()
                else -> null
            }
        }

        @JvmStatic
        @VisibleForTesting
        fun getFloat(params: Map<String, Any?>, key: String, defaultValue: Float): Float {
            val value = params[key]
            return if (value is Number) value.toFloat() else defaultValue
        }

        @JvmStatic
        @VisibleForTesting
        fun getFitPolicy(params: Map<String, Any?>): FitPolicy =
            when (getString(params, "fitPolicy")) {
                "FitPolicy.WIDTH" -> FitPolicy.WIDTH
                "FitPolicy.HEIGHT" -> FitPolicy.HEIGHT
                else -> FitPolicy.BOTH
            }

        @JvmStatic
        @VisibleForTesting
        fun getURI(uri: String?): Uri {
            if (uri == null || uri.isEmpty()) return Uri.EMPTY
            // Absolute filesystem paths without a scheme (path_provider / temp
            // downloads) must use file:// (#266 "No content provider").
            if (uri.startsWith("/") || uri.startsWith("file:/")) {
                if (uri.startsWith("file:")) return Uri.parse(uri)
                return Uri.fromFile(File(uri))
            }
            val parsed = Uri.parse(uri)
            if (parsed.scheme.isNullOrEmpty()) return Uri.fromFile(File(uri))
            return parsed
        }
    }
}
