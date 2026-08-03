package io.endigo.plugins.pdfviewflutter

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.View

import androidx.annotation.VisibleForTesting

import com.github.barteksc.pdfviewer.PDFView
import com.github.barteksc.pdfviewer.PDFView.Configurator
import com.github.barteksc.pdfviewer.link.LinkHandler
import com.github.barteksc.pdfviewer.scroll.DefaultScrollHandle
import com.github.barteksc.pdfviewer.util.Constants
import com.github.barteksc.pdfviewer.util.FitPolicy

import java.io.File
import java.io.FileOutputStream

import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.platform.PlatformView

class FlutterPDFView(
    private val context: Context,
    messenger: BinaryMessenger,
    id: Int,
    params: Map<String, Any?>
) : PlatformView, MethodCallHandler {

    private var pdfView: PDFView?
    private var configurator: Configurator? = null
    private val methodChannel: MethodChannel
    private val linkHandler: LinkHandler
    private val onDrawArgs: MutableMap<String, Any> = HashMap()
    private var lastDrawTime: Long = 0
    private val displayDensity: Float
    private val mainHandler = Handler(Looper.getMainLooper())

    /** Creation / runtime page alignment (#250, #272). Default centers short docs. */
    private var pageAlignment: PageAlignment = getPageAlignment(params)

    @Volatile
    private var disposed = false

    @Volatile
    private var documentLoadStarted = false

    init {
        val view = PDFView(context, null)
        pdfView = view
        // Prevent premature draw while the Hybrid Composition surface is still
        // being attached (#263 Surface already locked, #280 EGL_NO_DISPLAY).
        view.visibility = View.INVISIBLE
        displayDensity = context.resources.displayMetrics.density
        val preventLinkNavigation = getBoolean(params, "preventLinkNavigation")

        methodChannel = MethodChannel(messenger, "plugins.endigo.io/pdfview_$id")
        methodChannel.setMethodCallHandler(this)

        linkHandler = PDFLinkHandler(context, view, methodChannel, preventLinkNavigation)

        view.useBestQuality(getBoolean(params, "useBestQuality"))
        view.enableRenderDuringScale(getBoolean(params, "enableRenderDuringScale"))
        val thumbnailRatioObj = params["thumbnailRatio"]
        if (thumbnailRatioObj is Number) {
            val thumbnailRatio = thumbnailRatioObj.toFloat()
            // A ratio outside (0, 1] makes AndroidPdfViewer create zero-sized or
            // oversized thumbnail bitmaps, which throws at render time.
            if (thumbnailRatio > 0f && thumbnailRatio <= 1f) {
                Constants.THUMBNAIL_RATIO = thumbnailRatio
            }
        }

        val backgroundColor = params["backgroundColor"]
        if (backgroundColor != null) {
            val color = (backgroundColor as Number).toInt()
            view.setBackgroundColor(color)
        }

        // Defer load until the view has a non-zero size so Pdfium does not render
        // into a zero-sized / unattached surface (#298 blank, #280 quick-open crash).
        view.addOnLayoutChangeListener(object : View.OnLayoutChangeListener {
            override fun onLayoutChange(
                v: View, left: Int, top: Int, right: Int, bottom: Int,
                oldLeft: Int, oldTop: Int, oldRight: Int, oldBottom: Int
            ) {
                val currentView = pdfView
                if (documentLoadStarted || disposed || currentView == null) {
                    return
                }
                if (right - left <= 0 || bottom - top <= 0) {
                    return
                }
                currentView.removeOnLayoutChangeListener(this)
                loadDocument(params)
                currentView.visibility = View.VISIBLE
            }
        })
        // Fallback if layout already has size (e.g. recycled view / tests).
        view.post {
            val currentView = pdfView
            if (disposed || currentView == null || documentLoadStarted) {
                return@post
            }
            if (currentView.width > 0 && currentView.height > 0) {
                loadDocument(params)
                currentView.visibility = View.VISIBLE
            }
        }
    }

    private fun loadDocument(params: Map<String, Any?>) {
        val view = pdfView
        if (disposed || view == null || documentLoadStarted) {
            return
        }
        documentLoadStarted = true
        var config: Configurator? = null
        if (params["filePath"] != null) {
            val filePath = params["filePath"] as String
            // Prefer fromFile for absolute filesystem paths (#266 No content provider).
            val uri = getURI(filePath)
            config = if ("file" == uri.scheme || uri.scheme == null) {
                val file = File(if (filePath.startsWith("file:")) uri.path!! else filePath)
                if (file.exists()) {
                    view.fromFile(file)
                } else {
                    view.fromUri(uri)
                }
            } else {
                view.fromUri(uri)
            }
        } else if (params["pdfData"] != null) {
            val data = params["pdfData"] as ByteArray
            config = view.fromBytes(data)
        }

        if (config != null) {
            // PageAlignment.top disables AndroidPdfViewer's autoSpacing "center each
            // page in the viewport" pads (#250). Keep a small fixed gap when the user
            // still asked for spacing between multi-page documents.
            val userAutoSpacing = getBoolean(params, "autoSpacing")
            val topAlign = pageAlignment == PageAlignment.TOP
            val effectiveAutoSpacing = userAutoSpacing && !topAlign
            val interPageSpacingDp = if (topAlign && userAutoSpacing) TOP_ALIGN_SPACING_DP else 0
            config
                .enableSwipe(getBoolean(params, "enableSwipe"))
                .swipeHorizontal(getBoolean(params, "swipeHorizontal"))
                .password(getString(params, "password"))
                .nightMode(getBoolean(params, "nightMode"))
                .autoSpacing(effectiveAutoSpacing)
                .spacing(interPageSpacingDp)
                .pageFling(getBoolean(params, "pageFling"))
                .pageSnap(getBoolean(params, "pageSnap"))
                .pageFitPolicy(getFitPolicy(params))
                .enableAnnotationRendering(true)
                .scrollHandle(
                    if (getBoolean(params, "showScrollIndicators")) DefaultScrollHandle(context) else null
                )
                .linkHandler(linkHandler)
                .enableAntialiasing(getBoolean(params, "enableAntialiasing"))
                .enableDoubletap(true)
                .defaultPage(getInt(params, "defaultPage"))
                .onPageChange { page, total ->
                    if (disposed) return@onPageChange
                    val args: MutableMap<String, Any> = HashMap()
                    args["page"] = page
                    args["total"] = total
                    methodChannel.invokeMethod("onPageChanged", args)
                }
                .onError { t ->
                    if (disposed) return@onError
                    val args: MutableMap<String, Any> = HashMap()
                    args["error"] = t.toString()
                    methodChannel.invokeMethod("onError", args)
                }.onPageError { page, t ->
                    if (disposed) return@onPageError
                    val args: MutableMap<String, Any> = HashMap()
                    args["page"] = page
                    args["error"] = t.toString()
                    methodChannel.invokeMethod("onPageError", args)
                }.onRender { pages ->
                    if (disposed) return@onRender
                    // After first layout, pin short docs to top and re-center
                    // the secondary axis for defaultPage / setPage parity (#197, #250).
                    view.post {
                        if (!disposed && pdfView != null) {
                            applyPagePlacement(view)
                        }
                    }
                    val args: MutableMap<String, Any> = HashMap()
                    args["pages"] = pages
                    methodChannel.invokeMethod("onRender", args)
                }.onDraw { _, _, _, _ ->
                    if (disposed) return@onDraw
                    val now = System.currentTimeMillis()
                    if (now - lastDrawTime < DRAW_THROTTLE_MS) return@onDraw
                    lastDrawTime = now
                    onDrawArgs.clear()
                    onDrawArgs["pdfXOffset"] = view.currentXOffset / displayDensity
                    onDrawArgs["pdfYOffset"] = view.currentYOffset / displayDensity
                    onDrawArgs["pdfScale"] = view.zoom
                    methodChannel.invokeMethod("onDraw", onDrawArgs)
                }.onLoad { nbPages ->
                    if (disposed) return@onLoad
                    val args: MutableMap<String, Any> = HashMap()
                    args["pages"] = nbPages
                    methodChannel.invokeMethod("onLoadComplete", args)
                }.load()

            val effectiveMax = getFloat(params, "maxZoom", DEFAULT_MAX_ZOOM)
            var effectiveMin = getFloat(params, "minZoom", DEFAULT_MIN_ZOOM)
            if (effectiveMin > effectiveMax) {
                effectiveMin = effectiveMax
            }
            view.maxZoom = effectiveMax
            view.minZoom = effectiveMin
        }
        configurator = config
    }

    override fun getView(): View? {
        return pdfView
    }

    override fun onMethodCall(methodCall: MethodCall, result: Result) {
        when (methodCall.method) {
            "pageCount" -> getPageCount(result)
            "currentPageSize" -> getCurrentPageSize(result)
            "getPosition" -> getPosition(result)
            "getScale" -> getScale(result)
            "setPosition" -> setPosition(methodCall, result)
            "setScale" -> setScale(methodCall, result)
            "getScreenshot" -> getScreenshot(methodCall, result)
            "reload" -> reload(result)
            "currentPage" -> getCurrentPage(result)
            "setPage" -> setPage(methodCall, result)
            "updateSettings" -> updateSettings(methodCall, result)
            "setZoomLimits" -> setZoomLimits(methodCall, result)
            else -> result.notImplemented()
        }
    }

    fun getPageCount(result: Result) {
        val view = pdfView
        if (disposed || view == null) {
            result.success(0)
            return
        }
        result.success(view.pageCount)
    }

    fun getCurrentPageSize(result: Result) {
        val view = pdfView
        if (disposed || view == null) {
            result.error("INVALID_STATE", "PDFView disposed", null)
            return
        }
        if (view.pageCount == 0) {
            result.error("INVALID_STATE", "No pages loaded", null)
            return
        }
        val size = view.getPageSize(view.currentPage)
        if (size == null) {
            result.error("FAIL", "Could not get page size", null)
            return
        }
        result.success(floatArrayOf(size.width, size.height))
    }

    fun getPosition(result: Result) {
        val view = pdfView
        if (disposed || view == null) {
            result.error("INVALID_STATE", "PDFView disposed", null)
            return
        }
        val xOffset = view.currentXOffset / displayDensity
        val yOffset = view.currentYOffset / displayDensity

        result.success(floatArrayOf(xOffset, yOffset))
    }

    fun getScale(result: Result) {
        val view = pdfView
        if (disposed || view == null) {
            result.success(1.0f)
            return
        }
        result.success(view.zoom)
    }

    fun setPosition(call: MethodCall, result: Result) {
        val view = pdfView
        if (disposed || view == null) {
            result.success(false)
            return
        }
        val xPosObj = call.argument<Double>("xPos")
        val xOffset = xPosObj ?: 0.0
        val yPosObj = call.argument<Double>("yPos")
        val yOffset = yPosObj ?: 0.0
        view.moveTo(xOffset.toFloat() * displayDensity, yOffset.toFloat() * displayDensity)
        view.loadPages()
        result.success(true)
    }

    fun setScale(call: MethodCall, result: Result) {
        val view = pdfView
        if (disposed || view == null) {
            result.success(false)
            return
        }
        val scaleObj = call.argument<Double>("scale")
        val zoom = scaleObj ?: 1.0

        if (zoom != 1.0) {
            view.zoomTo(zoom.toFloat())
        }
        view.loadPages()
        result.success(true)
    }

    fun setZoomLimits(call: MethodCall, result: Result) {
        val view = pdfView
        if (disposed || view == null) {
            result.success(false)
            return
        }
        val minZoom = call.argument<Double>("minZoom")
        val midZoom = call.argument<Double>("midZoom")
        val maxZoom = call.argument<Double>("maxZoom")
        val minZ = minZoom ?: 1.0
        val midZ = midZoom ?: 1.0
        val maxZ = maxZoom ?: 1.0
        if (minZ <= 0 || midZ <= 0 || maxZ <= 0 || minZ > midZ || midZ > maxZ) {
            result.error("INVALID_ARGS", "Expected 0 < minZoom ≤ midZoom ≤ maxZoom", null)
            return
        }
        view.minZoom = minZ.toFloat()
        view.midZoom = midZ.toFloat()
        view.maxZoom = maxZ.toFloat()
        result.success(true)
    }

    fun getScreenshot(call: MethodCall, result: Result) {
        val pdfFileName = call.argument<String>("fileName")
        if (pdfFileName == null || pdfFileName.isEmpty()) {
            result.error("FAIL", "fileName is required", null)
            return
        }
        try {
            val outputFile = File(pdfFileName)
            if (outputFile.parentFile == null) {
                result.error("FAIL", "fileName must include a directory path", null)
                return
            }
            val imageFileName = outputFile.absolutePath
            val bmp = loadBitmapFromPDFView()
            if (bmp == null) {
                result.error("FAIL", "PDFView is not laid out yet", null)
                return
            }
            try {
                FileOutputStream(outputFile, false).use { fileOut ->
                    bmp.compress(Bitmap.CompressFormat.PNG, 100, fileOut)
                }
            } finally {
                bmp.recycle()
            }
            result.success(imageFileName)
        } catch (e: Exception) {
            result.error("FAIL", "Failed to generate image", e.message)
        }
    }

    fun loadBitmapFromPDFView(): Bitmap? {
        val view = pdfView
        if (disposed || view == null) {
            return null
        }
        val width = view.width
        val height = view.height
        if (width <= 0 || height <= 0) {
            return null
        }
        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        view.draw(canvas)
        return bitmap
    }

    fun reload(result: Result) {
        val view = pdfView
        if (disposed || view == null) {
            result.success(false)
            return
        }
        val config = configurator
        if (config != null) {
            // Recycle before reloading to free Pdfium memory (#261).
            try {
                view.recycle()
            } catch (e: Exception) {
                Log.w(TAG, "recycle before reload", e)
            }
            config.load()
            result.success(true)
        } else {
            result.success(false)
        }
    }

    fun getCurrentPage(result: Result) {
        val view = pdfView
        if (disposed || view == null) {
            result.success(0)
            return
        }
        result.success(view.currentPage)
    }

    fun setPage(call: MethodCall, result: Result) {
        val view = pdfView
        if (disposed || view == null) {
            result.success(false)
            return
        }
        if (call.argument<Any>("page") == null) {
            result.success(false)
            return
        }
        val pageObj = call.argument<Int>("page")
        val page = pageObj ?: 0
        // #182: After an AlertDialog the Hybrid Composition surface may still
        // be reattaching; jump on the next frame so the page change sticks.
        // Complete the method channel only after jumpTo so await setPage()
        // followed by getCurrentPage() observes the new page.
        val jump = Runnable {
            val current = pdfView
            if (disposed || current == null) {
                result.success(false)
                return@Runnable
            }
            try {
                current.jumpTo(page)
                // #197: jumpTo keeps the previous secondary-axis offset, so after
                // a pan/zoom the new page can sit left-aligned. Re-center X (or Y
                // in horizontal mode) and re-apply PageAlignment.top when needed.
                applyPagePlacement(current)
                current.loadPages()
                current.invalidate()
                result.success(true)
            } catch (e: Exception) {
                Log.w(TAG, "setPage failed", e)
                result.success(false)
            }
        }
        if (view.width > 0 && view.height > 0) {
            view.post(jump)
        } else {
            mainHandler.post(jump)
        }
    }

    /**
     * Re-centers the secondary axis (#197) and optionally pins the primary axis
     * to the start for [PageAlignment.TOP] when the document is shorter than the
     * viewport (#250, #272).
     *
     * AndroidPdfViewer's [PDFView.moveTo] always vertical-centers short
     * documents and [PDFView.jumpTo] preserves the previous X offset, so we
     * recompute offsets here after load / setPage.
     */
    private fun applyPagePlacement(view: PDFView) {
        if (disposed || view.pageCount <= 0 || view.width <= 0 || view.height <= 0) {
            return
        }
        try {
            // Preserve the primary-axis offset from jumpTo / current scroll; only
            // recompute the secondary axis (#197). For short docs + TOP, force
            // primary to 0 after moveTo undoes library vertical-centering (#250).
            val secondary = centeredSecondaryOffset(view)
            if (view.isSwipeVertical) {
                view.moveTo(secondary, view.currentYOffset)
                if (pageAlignment == PageAlignment.TOP) {
                    forcePrimaryOffsetIfShort(view, isVertical = true)
                }
            } else {
                view.moveTo(view.currentXOffset, secondary)
                if (pageAlignment == PageAlignment.TOP) {
                    forcePrimaryOffsetIfShort(view, isVertical = false)
                }
            }
        } catch (e: Exception) {
            Log.w(TAG, "applyPagePlacement", e)
        }
    }

    /**
     * Offset that centers the max-page strip on the secondary axis (X when
     * swiping vertically, Y when swiping horizontally).
     */
    private fun centeredSecondaryOffset(view: PDFView): Float {
        val pageCount = view.pageCount
        if (pageCount <= 0) {
            return 0f
        }
        var maxSecondary = 0f
        for (i in 0 until pageCount) {
            val size = view.getPageSize(i) ?: continue
            val dim = if (view.isSwipeVertical) size.width else size.height
            if (dim > maxSecondary) {
                maxSecondary = dim
            }
        }
        val scaled = view.toCurrentScale(maxSecondary)
        return if (view.isSwipeVertical) {
            centerSecondaryOffset(view.width.toFloat(), scaled)
        } else {
            centerSecondaryOffset(view.height.toFloat(), scaled)
        }
    }

    /**
     * [PDFView.moveTo] overwrites the primary offset when content fits the
     * viewport (centers it). For [PageAlignment.TOP] we write 0 after moveTo so
     * free space sits below / after the content.
     */
    private fun forcePrimaryOffsetIfShort(view: PDFView, isVertical: Boolean) {
        if (!documentFitsAlongPrimary(view, isVertical)) {
            return
        }
        try {
            val fieldName = if (isVertical) "currentYOffset" else "currentXOffset"
            val field = PDFView::class.java.getDeclaredField(fieldName)
            field.isAccessible = true
            field.setFloat(view, 0f)
            view.loadPages()
            view.invalidate()
        } catch (e: Exception) {
            Log.w(TAG, "forcePrimaryOffsetIfShort", e)
        }
    }

    /** True when the tight document length is smaller than the viewport. */
    private fun documentFitsAlongPrimary(view: PDFView, isVertical: Boolean): Boolean {
        val pageCount = view.pageCount
        if (pageCount <= 0) {
            return true
        }
        var length = 0f
        val spacingPx = view.spacingPx.toFloat() * view.zoom
        for (i in 0 until pageCount) {
            val size = view.getPageSize(i) ?: continue
            length += if (isVertical) {
                view.toCurrentScale(size.height)
            } else {
                view.toCurrentScale(size.width)
            }
            if (i < pageCount - 1) {
                length += spacingPx
            }
        }
        val viewport = if (isVertical) view.height.toFloat() else view.width.toFloat()
        return length < viewport - 1f
    }

    @Suppress("UNCHECKED_CAST")
    private fun updateSettings(methodCall: MethodCall, result: Result) {
        applySettings(methodCall.arguments as Map<String, Any?>)
        result.success(null)
    }

    private fun applySettings(settings: Map<String, Any?>) {
        val view = pdfView
        if (disposed || view == null) {
            return
        }
        for (key in settings.keys) {
            when (key) {
                "enableSwipe" -> view.setSwipeEnabled(getBoolean(settings, key))
                "nightMode" -> {
                    view.setNightMode(getBoolean(settings, key))
                    // Night mode is applied when pages are (re)rendered; AndroidPdfViewer
                    // caches page bitmaps so invalidate() alone is not enough.
                    view.loadPages()
                    view.invalidate()
                }
                "pageFling" -> view.setPageFling(getBoolean(settings, key))
                "pageSnap" -> view.setPageSnap(getBoolean(settings, key))
                "preventLinkNavigation" -> {
                    val plh = this.linkHandler as PDFLinkHandler
                    plh.setPreventLinkNavigation(getBoolean(settings, key))
                }
                "pageAlignment" -> {
                    pageAlignment = getPageAlignment(settings)
                    // Re-apply offsets; full autoSpacing flip needs a remount.
                    view.post {
                        if (!disposed && pdfView != null) {
                            applyPagePlacement(view)
                        }
                    }
                }
                "maxZoom" -> view.maxZoom = getFloat(settings, key, DEFAULT_MAX_ZOOM)
                "minZoom" -> view.minZoom = getFloat(settings, key, DEFAULT_MIN_ZOOM)
                else -> throw IllegalArgumentException("Unknown PDFView setting: $key")
            }
        }
    }

    override fun dispose() {
        // #261 memory leak / #263 surface lock / #280 EGL race:
        // Hide first so Flutter stops drawing into the platform surface, then
        // recycle Pdfium resources on the main thread and drop channel handlers.
        disposed = true
        methodChannel.setMethodCallHandler(null)
        mainHandler.removeCallbacksAndMessages(null)
        val view = pdfView
        pdfView = null
        configurator = null
        if (view != null) {
            try {
                view.visibility = View.GONE
            } catch (ignored: Exception) {
            }
            // Defer one frame so an in-flight PlatformViewWrapper.draw can finish.
            // Always use the main-thread handler: View.post() is dropped when the
            // view is already detached from a window, which would leak Pdfium (#261).
            // removeCallbacksAndMessages above already ran, so this post is not cancelled.
            mainHandler.post {
                try {
                    view.recycle()
                } catch (e: Exception) {
                    Log.w(TAG, "dispose recycle", e)
                }
            }
        }
    }

    override fun onFlutterViewAttached(flutterView: View) {
        // Ensure pages re-render when reattached after dialog/rotation (#9, #182).
        val view = pdfView
        if (!disposed && view != null && view.pageCount > 0) {
            view.post {
                if (!disposed && pdfView != null) {
                    try {
                        view.loadPages()
                        view.invalidate()
                    } catch (e: Exception) {
                        Log.w(TAG, "onFlutterViewAttached", e)
                    }
                }
            }
        }
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
        private const val DRAW_THROTTLE_MS = 16L // ~1 frame at 60fps
        /** Fixed inter-page gap (dp) when top-align disables autoSpacing but user wants gaps. */
        private const val TOP_ALIGN_SPACING_DP = 8

        @JvmStatic
        @VisibleForTesting
        fun getBoolean(params: Map<String, Any?>, key: String): Boolean {
            val keyObj = params[key] as Boolean?
            val bKey: Boolean = keyObj ?: false
            return params.containsKey(key) && bKey
        }

        @JvmStatic
        @VisibleForTesting
        fun getPageAlignment(params: Map<String, Any?>): PageAlignment {
            return when (getString(params, "pageAlignment")) {
                "PageAlignment.top" -> PageAlignment.TOP
                else -> PageAlignment.CENTER
            }
        }

        /**
         * Secondary-axis offset that centers a [scaledMax] strip in [viewport].
         * Exposed for unit tests of the #197 centering math.
         */
        @JvmStatic
        @VisibleForTesting
        fun centerSecondaryOffset(viewport: Float, scaledMax: Float): Float {
            return (viewport - scaledMax) / 2f
        }

        @JvmStatic
        @VisibleForTesting
        fun getString(params: Map<String, Any?>, key: String): String? {
            return if (params.containsKey(key)) params[key] as String? else ""
        }

        @JvmStatic
        @VisibleForTesting
        fun getInt(params: Map<String, Any?>, key: String): Int {
            val keyObj = params[key] as Int?
            val intKey: Int = keyObj ?: 0
            return if (params.containsKey(key)) intKey else 0
        }

        @JvmStatic
        @VisibleForTesting
        fun getFloat(params: Map<String, Any?>, key: String, defaultValue: Float): Float {
            val value = params[key]
            if (value is Number) {
                return value.toFloat()
            }
            return defaultValue
        }

        @JvmStatic
        @VisibleForTesting
        fun getFitPolicy(params: Map<String, Any?>): FitPolicy {
            return when (getString(params, "fitPolicy")) {
                "FitPolicy.WIDTH" -> FitPolicy.WIDTH
                "FitPolicy.HEIGHT" -> FitPolicy.HEIGHT
                else -> FitPolicy.BOTH
            }
        }

        @JvmStatic
        @VisibleForTesting
        fun getURI(uri: String?): Uri {
            if (uri == null || uri.isEmpty()) {
                return Uri.EMPTY
            }
            // Absolute filesystem paths without a scheme (common with path_provider /
            // temp downloads) must use file:// — Uri.parse alone can yield a path
            // that ContentResolver rejects with "No content provider" (#266).
            if (uri.startsWith("/") || uri.startsWith("file:/")) {
                if (uri.startsWith("file:")) {
                    return Uri.parse(uri)
                }
                return Uri.fromFile(File(uri))
            }
            val parsed = Uri.parse(uri)
            if (parsed.scheme.isNullOrEmpty()) {
                return Uri.fromFile(File(uri))
            }
            return parsed
        }
    }
}
