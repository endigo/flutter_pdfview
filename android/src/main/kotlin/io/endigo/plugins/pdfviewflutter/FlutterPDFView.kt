package io.endigo.plugins.pdfviewflutter

import android.app.Activity
import android.content.Context
import android.content.ContextWrapper
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Rect
import android.graphics.drawable.ColorDrawable
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.PixelCopy
import android.view.View
import android.view.Window

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
            config
                .enableSwipe(getBoolean(params, "enableSwipe"))
                .swipeHorizontal(getBoolean(params, "swipeHorizontal"))
                .password(getString(params, "password"))
                .nightMode(getBoolean(params, "nightMode"))
                .autoSpacing(getBoolean(params, "autoSpacing"))
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
        val outputFile = File(pdfFileName)
        if (outputFile.parentFile == null) {
            result.error("FAIL", "fileName must include a directory path", null)
            return
        }
        val view = pdfView
        if (disposed || view == null) {
            result.error("FAIL", "PDFView is not laid out yet", null)
            return
        }
        val width = view.width
        val height = view.height
        if (width <= 0 || height <= 0) {
            result.error("FAIL", "PDFView is not laid out yet", null)
            return
        }

        // Prefer PixelCopy of the real window pixels when the hybrid-composition
        // platform view is attached (#175). Fall back to a software-layer draw.
        val window = findWindow(context)
        if (window != null &&
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            view.isAttachedToWindow
        ) {
            val location = IntArray(2)
            view.getLocationInWindow(location)
            val srcRect = Rect(
                location[0],
                location[1],
                location[0] + width,
                location[1] + height
            )
            val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
            try {
                PixelCopy.request(
                    window,
                    srcRect,
                    bitmap,
                    { copyResult ->
                        if (disposed) {
                            bitmap.recycle()
                            result.error("FAIL", "PDFView disposed", null)
                            return@request
                        }
                        if (copyResult == PixelCopy.SUCCESS) {
                            writeScreenshot(outputFile, bitmap, result)
                        } else {
                            bitmap.recycle()
                            val fallback = loadBitmapFromPDFView()
                            if (fallback == null) {
                                result.error(
                                    "FAIL",
                                    "Failed to generate image",
                                    "PixelCopy result=$copyResult"
                                )
                            } else {
                                writeScreenshot(outputFile, fallback, result)
                            }
                        }
                    },
                    mainHandler
                )
                return
            } catch (e: IllegalArgumentException) {
                // Window not ready / invalid rect — fall through to software draw.
                bitmap.recycle()
                Log.w(TAG, "PixelCopy unavailable, using software capture", e)
            }
        }

        try {
            val bmp = loadBitmapFromPDFView()
            if (bmp == null) {
                result.error("FAIL", "PDFView is not laid out yet", null)
                return
            }
            writeScreenshot(outputFile, bmp, result)
        } catch (e: Exception) {
            result.error("FAIL", "Failed to generate image", e.message)
        }
    }

    private fun writeScreenshot(outputFile: File, bmp: Bitmap, result: Result) {
        try {
            val parent = outputFile.parentFile
            if (parent != null && !parent.exists()) {
                parent.mkdirs()
            }
            FileOutputStream(outputFile, false).use { fileOut ->
                bmp.compress(Bitmap.CompressFormat.PNG, 100, fileOut)
            }
            result.success(outputFile.absolutePath)
        } catch (e: Exception) {
            result.error("FAIL", "Failed to generate image", e.message)
        } finally {
            bmp.recycle()
        }
    }

    /**
     * Rasterizes the PDFView into an ARGB bitmap.
     *
     * A plain [View.draw] into a software [Canvas] returns a blank white image when
     * the view (or its children) uses a hardware layer — which is the default under
     * Flutter hybrid composition (`initExpensiveAndroidView`). Temporarily force a
     * software layer so Pdfium page bitmaps are actually drawn into the capture (#175).
     * Drawing-cache APIs are intentionally avoided; they are broken for the same reason.
     */
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
        val background = view.background
        if (background is ColorDrawable) {
            canvas.drawColor(background.color)
        } else if (background != null) {
            background.setBounds(0, 0, width, height)
            background.draw(canvas)
        } else {
            canvas.drawColor(Color.WHITE)
        }
        val previousLayerType = view.layerType
        try {
            // LAYER_TYPE_SOFTWARE rebuilds the display list into a CPU bitmap so
            // subsequent draw() copies real page content instead of an empty HW layer.
            view.setLayerType(View.LAYER_TYPE_SOFTWARE, null)
            view.draw(canvas)
        } finally {
            view.setLayerType(previousLayerType, null)
        }
        return bitmap
    }

    private fun findWindow(context: Context): Window? {
        var ctx: Context? = context
        while (ctx is ContextWrapper) {
            if (ctx is Activity) {
                return ctx.window
            }
            ctx = ctx.baseContext
        }
        return null
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

    companion object {
        const val TAG = "FlutterPDFView"

        private const val DEFAULT_MAX_ZOOM = 4.0f
        private const val DEFAULT_MIN_ZOOM = 1.0f
        private const val DRAW_THROTTLE_MS = 16L // ~1 frame at 60fps

        @JvmStatic
        @VisibleForTesting
        fun getBoolean(params: Map<String, Any?>, key: String): Boolean {
            val keyObj = params[key] as Boolean?
            val bKey: Boolean = keyObj ?: false
            return params.containsKey(key) && bKey
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
