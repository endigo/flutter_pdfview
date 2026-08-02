package io.endigo.plugins.pdfviewflutter;

import android.content.Context;
import android.graphics.Bitmap;
import android.graphics.Canvas;
import android.net.Uri;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;
import android.view.View;

import androidx.annotation.NonNull;

import com.github.barteksc.pdfviewer.PDFView;
import com.github.barteksc.pdfviewer.PDFView.Configurator;
import com.github.barteksc.pdfviewer.link.LinkHandler;
import com.github.barteksc.pdfviewer.scroll.DefaultScrollHandle;
import com.github.barteksc.pdfviewer.util.Constants;
import com.github.barteksc.pdfviewer.util.FitPolicy;
import com.shockwave.pdfium.util.SizeF;

import java.io.File;
import java.io.FileOutputStream;
import java.util.HashMap;
import java.util.Map;
import java.util.Objects;

import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import io.flutter.plugin.platform.PlatformView;

public class FlutterPDFView implements PlatformView, MethodCallHandler {
    private static final float DEFAULT_MAX_ZOOM = 4.0f;
    private static final float DEFAULT_MIN_ZOOM = 1.0f;

    private PDFView pdfView;
    private Configurator configurator;
    private final MethodChannel methodChannel;
    private final LinkHandler linkHandler;
    private final Map<String, Object> onDrawArgs = new HashMap<>();
    private long _lastDrawTime = 0;
    private static final long DRAW_THROTTLE_MS = 16; // ~1 frame at 60fps
    private final float displayDensity;
    private final Context context;
    private final Handler mainHandler = new Handler(Looper.getMainLooper());
    private volatile boolean disposed = false;
    private volatile boolean documentLoadStarted = false;
    public static final String TAG = "FlutterPDFView";


    FlutterPDFView(Context context, BinaryMessenger messenger, int id, Map<String, Object> params) {
        this.context = context;
        pdfView = new PDFView(context, null);
        // Prevent premature draw while the Hybrid Composition surface is still
        // being attached (#263 Surface already locked, #280 EGL_NO_DISPLAY).
        pdfView.setVisibility(View.INVISIBLE);
        displayDensity = context.getResources().getDisplayMetrics().density;
        final boolean preventLinkNavigation = getBoolean(params, "preventLinkNavigation");

        methodChannel = new MethodChannel(messenger, "plugins.endigo.io/pdfview_" + id);
        methodChannel.setMethodCallHandler(this);

        linkHandler = new PDFLinkHandler(context, pdfView, methodChannel, preventLinkNavigation);


        pdfView.useBestQuality(getBoolean(params, "useBestQuality"));
        pdfView.enableRenderDuringScale(getBoolean(params, "enableRenderDuringScale"));
        Object thumbnailRatioObj = params.get("thumbnailRatio");
        if (thumbnailRatioObj instanceof Number) {
            float thumbnailRatio = ((Number) thumbnailRatioObj).floatValue();
            // A ratio outside (0, 1] makes AndroidPdfViewer create zero-sized or
            // oversized thumbnail bitmaps, which throws at render time.
            if (thumbnailRatio > 0f && thumbnailRatio <= 1f) {
                Constants.THUMBNAIL_RATIO = thumbnailRatio;
            }
        }

        Object backgroundColor = params.get("backgroundColor");
        if (backgroundColor != null) {
            int color = ((Number) backgroundColor).intValue();
            pdfView.setBackgroundColor(color);
        }

        // Defer load until the view has a non-zero size so Pdfium does not render
        // into a zero-sized / unattached surface (#298 blank, #280 quick-open crash).
        pdfView.addOnLayoutChangeListener(new View.OnLayoutChangeListener() {
            @Override
            public void onLayoutChange(View v, int left, int top, int right, int bottom,
                                       int oldLeft, int oldTop, int oldRight, int oldBottom) {
                if (documentLoadStarted || disposed || pdfView == null) {
                    return;
                }
                if (right - left <= 0 || bottom - top <= 0) {
                    return;
                }
                pdfView.removeOnLayoutChangeListener(this);
                loadDocument(params);
                pdfView.setVisibility(View.VISIBLE);
            }
        });
        // Fallback if layout already has size (e.g. recycled view / tests).
        pdfView.post(() -> {
            if (disposed || pdfView == null || documentLoadStarted) {
                return;
            }
            if (pdfView.getWidth() > 0 && pdfView.getHeight() > 0) {
                loadDocument(params);
                pdfView.setVisibility(View.VISIBLE);
            }
        });
    }

    private void loadDocument(Map<String, Object> params) {
        if (disposed || pdfView == null || documentLoadStarted) {
            return;
        }
        documentLoadStarted = true;
        Configurator config = null;
        if (params.get("filePath") != null) {
            String filePath = (String) params.get("filePath");
            // Prefer fromFile for absolute filesystem paths (#266 No content provider).
            Uri uri = getURI(filePath);
            if ("file".equals(uri.getScheme()) || uri.getScheme() == null) {
                File file = new File(filePath.startsWith("file:") ? uri.getPath() : filePath);
                if (file.exists()) {
                    config = pdfView.fromFile(file);
                } else {
                    config = pdfView.fromUri(uri);
                }
            } else {
                config = pdfView.fromUri(uri);
            }
        } else if (params.get("pdfData") != null) {
            byte[] data = (byte[]) params.get("pdfData");
            config = pdfView.fromBytes(data);
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
                    .scrollHandle(getBoolean(params, "showScrollIndicators") ? new DefaultScrollHandle(context) : null)
                    .linkHandler(linkHandler)
                    .enableAntialiasing(getBoolean(params, "enableAntialiasing"))
                    .enableDoubletap(true)
                    .defaultPage(getInt(params, "defaultPage"))
                    .onPageChange((page, total) -> {
                        if (disposed) return;
                        Map<String, Object> args = new HashMap<>();
                        args.put("page", page);
                        args.put("total", total);
                        methodChannel.invokeMethod("onPageChanged", args);
                    })
                    .onError(t -> {
                        if (disposed) return;
                        Map<String, Object> args = new HashMap<>();
                        args.put("error", t.toString());
                        methodChannel.invokeMethod("onError", args);
                    }).onPageError((page, t) -> {
                        if (disposed) return;
                        Map<String, Object> args = new HashMap<>();
                        args.put("page", page);
                        args.put("error", t.toString());
                        methodChannel.invokeMethod("onPageError", args);
                    }).onRender(pages -> {
                        if (disposed) return;
                        Map<String, Object> args = new HashMap<>();
                        args.put("pages", pages);
                        methodChannel.invokeMethod("onRender", args);
                    }).onDraw((canvas, pageWidth, pageHeight, displayedPage) -> {
                        if (disposed) return;
                        long now = System.currentTimeMillis();
                        if (now - _lastDrawTime < DRAW_THROTTLE_MS) return;
                        _lastDrawTime = now;
                        onDrawArgs.clear();
                        onDrawArgs.put("pdfXOffset", pdfView.getCurrentXOffset() / displayDensity);
                        onDrawArgs.put("pdfYOffset", pdfView.getCurrentYOffset() / displayDensity);
                        onDrawArgs.put("pdfScale", pdfView.getZoom());
                        methodChannel.invokeMethod("onDraw", onDrawArgs);
                    }).onLoad(nbPages -> {
                        if (disposed) return;
                        Map<String, Object> args = new HashMap<>();
                        args.put("pages", nbPages);
                        methodChannel.invokeMethod("onLoadComplete", args);
                    }).load();

            float effectiveMax = getFloat(params, "maxZoom", DEFAULT_MAX_ZOOM);
            float effectiveMin = getFloat(params, "minZoom", DEFAULT_MIN_ZOOM);
            if (effectiveMin > effectiveMax) {
                effectiveMin = effectiveMax;
            }
            pdfView.setMaxZoom(effectiveMax);
            pdfView.setMinZoom(effectiveMin);
        }
        configurator = config;
    }

    @Override
    public View getView() {
        return pdfView;
    }

    @Override
    public void onMethodCall(MethodCall methodCall, @NonNull Result result) {
        switch (methodCall.method) {
            case "pageCount":
                getPageCount(result);
                break;
            case "currentPageSize":
                getCurrentPageSize(result);
                break;
            case "getPosition":
                getPosition(result);
                break;
            case "getScale":
                getScale(result);
                break;
            case "setPosition":
                setPosition(methodCall, result);
                break;
            case "setScale":
                setScale(methodCall, result);
                break;
            case "getScreenshot":
                getScreenshot(methodCall, result);
                break;
            case "reload":
                reload(result);
                break;
            case "currentPage":
                getCurrentPage(result);
                break;
            case "setPage":
                setPage(methodCall, result);
                break;
            case "updateSettings":
                updateSettings(methodCall, result);
                break;
            case "setZoomLimits":
                setZoomLimits(methodCall, result);
                break;
            default:
                result.notImplemented();
                break;
        }
    }

    void getPageCount(Result result) {
        if (disposed || pdfView == null) {
            result.success(0);
            return;
        }
        result.success(pdfView.getPageCount());
    }

    void getCurrentPageSize(Result result) {
        if (disposed || pdfView == null || pdfView.getPageCount() == 0) {
            result.error("INVALID_STATE", "No pages loaded", null);
            return;
        }
        SizeF size = pdfView.getPageSize(pdfView.getCurrentPage());
        if (size == null) {
            result.error("FAIL", "Could not get page size", null);
            return;
        }
        result.success(new float[]{size.getWidth(), size.getHeight()});
    }

    void getPosition(Result result) {
        if (disposed || pdfView == null) {
            result.error("INVALID_STATE", "PDFView disposed", null);
            return;
        }
        float xOffset = pdfView.getCurrentXOffset() / displayDensity;
        float yOffset = pdfView.getCurrentYOffset() / displayDensity;

        result.success(new float[]{xOffset, yOffset});
    }

    void getScale(Result result) {
        if (disposed || pdfView == null) {
            result.success(1.0f);
            return;
        }
        result.success(pdfView.getZoom());
    }

    void setPosition(MethodCall call, Result result) {
        if (disposed || pdfView == null) {
            result.success(false);
            return;
        }
        Double xPosObj = call.argument("xPos");
        double xOffset = Objects.requireNonNullElse(xPosObj, 0.0);
        Double yPosObj = call.argument("yPos");
        double yOffset = Objects.requireNonNullElse(yPosObj, 0.0);
        pdfView.moveTo((float) xOffset * displayDensity, (float) yOffset * displayDensity);
        pdfView.loadPages();
        result.success(true);
    }

    void setScale(MethodCall call, Result result) {
        if (disposed || pdfView == null) {
            result.success(false);
            return;
        }
        Double scaleObj = call.argument("scale");
        double zoom = Objects.requireNonNullElse(scaleObj, 1.0);

        if (zoom != 1.0) {
            pdfView.zoomTo((float) zoom);
        }
        pdfView.loadPages();
        result.success(true);
    }

    void setZoomLimits(MethodCall call, Result result) {
        if (disposed || pdfView == null) {
            result.success(false);
            return;
        }
        Double minZoom = call.argument("minZoom");
        Double midZoom = call.argument("midZoom");
        Double maxZoom = call.argument("maxZoom");
        double minZ = (minZoom != null ? minZoom : 1.0);
        double midZ = (midZoom != null ? midZoom : 1.0);
        double maxZ = (maxZoom != null ? maxZoom : 1.0);
        if (minZ <= 0 || midZ <= 0 || maxZ <= 0 || minZ > midZ || midZ > maxZ) {
            result.error("INVALID_ARGS", "Expected 0 < minZoom ≤ midZoom ≤ maxZoom", null);
            return;
        }
        pdfView.setMinZoom((float) minZ);
        pdfView.setMidZoom((float) midZ);
        pdfView.setMaxZoom((float) maxZ);
        result.success(true);
    }

    void getScreenshot(MethodCall call, Result result) {
        String pdfFileName = call.argument("fileName");
        if (pdfFileName == null || pdfFileName.isEmpty()) {
            result.error("FAIL", "fileName is required", null);
            return;
        }
        try {
            File outputFile = new File(pdfFileName);
            File parent = outputFile.getParentFile();
            if (parent == null) {
                result.error("FAIL", "fileName must include a directory path", null);
                return;
            }
            String imageFileName = outputFile.getAbsolutePath();
            Bitmap bmp = loadBitmapFromPDFView();
            if (bmp == null) {
                result.error("FAIL", "PDFView is not laid out yet", null);
                return;
            }
            try (FileOutputStream fileOut = new FileOutputStream(outputFile, false)) {
                bmp.compress(Bitmap.CompressFormat.PNG, 100, fileOut);
            } finally {
                bmp.recycle();
            }
            result.success(imageFileName);
        } catch (Exception e) {
            result.error("FAIL", "Failed to generate image", e.getMessage());
        }
    }

    Bitmap loadBitmapFromPDFView() {
        if (disposed || pdfView == null) {
            return null;
        }
        int width = pdfView.getWidth();
        int height = pdfView.getHeight();
        if (width <= 0 || height <= 0) {
            return null;
        }
        Bitmap bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888);
        Canvas canvas = new Canvas(bitmap);
        pdfView.draw(canvas);
        return bitmap;
    }

    void reload(Result result) {
        if (disposed || pdfView == null) {
            result.success(false);
            return;
        }
        if (configurator != null) {
            // Recycle before reloading to free Pdfium memory (#261).
            try {
                pdfView.recycle();
            } catch (Exception e) {
                Log.w(TAG, "recycle before reload", e);
            }
            configurator.load();
            result.success(true);
        } else {
            result.success(false);
        }
    }

    void getCurrentPage(Result result) {
        if (disposed || pdfView == null) {
            result.success(0);
            return;
        }
        result.success(pdfView.getCurrentPage());
    }

    void setPage(MethodCall call, Result result) {
        if (disposed || pdfView == null) {
            result.success(false);
            return;
        }
        if (call.argument("page") != null) {
            Integer pageObj = call.argument("page");
            final int page = Objects.requireNonNullElse(pageObj, 0);
            // #182: After an AlertDialog the Hybrid Composition surface may still
            // be reattaching; jump on the next frame so the page change sticks.
            Runnable jump = () -> {
                if (disposed || pdfView == null) {
                    return;
                }
                try {
                    pdfView.jumpTo(page);
                    pdfView.loadPages();
                    pdfView.invalidate();
                } catch (Exception e) {
                    Log.w(TAG, "setPage failed", e);
                }
            };
            if (pdfView.getWidth() > 0 && pdfView.getHeight() > 0) {
                pdfView.post(jump);
            } else {
                mainHandler.post(jump);
            }
        }

        result.success(true);
    }

    @SuppressWarnings("unchecked")
    private void updateSettings(MethodCall methodCall, Result result) {
        applySettings((Map<String, Object>) methodCall.arguments);
        result.success(null);
    }

    private void applySettings(Map<String, Object> settings) {
        if (disposed || pdfView == null) {
            return;
        }
        for (String key : settings.keySet()) {
            switch (key) {
                case "enableSwipe":
                    pdfView.setSwipeEnabled(getBoolean(settings, key));
                    break;
                case "nightMode":
                    pdfView.setNightMode(getBoolean(settings, key));
                    // Night mode paints inverted bitmaps; force redraw so the change is visible.
                    pdfView.invalidate();
                    break;
                case "pageFling":
                    pdfView.setPageFling(getBoolean(settings, key));
                    break;
                case "pageSnap":
                    pdfView.setPageSnap(getBoolean(settings, key));
                    break;
                case "preventLinkNavigation":
                    final PDFLinkHandler plh = (PDFLinkHandler) this.linkHandler;
                    plh.setPreventLinkNavigation(getBoolean(settings, key));
                    break;
                case "maxZoom":
                    pdfView.setMaxZoom(getFloat(settings, key, DEFAULT_MAX_ZOOM));
                    break;
                case "minZoom":
                    pdfView.setMinZoom(getFloat(settings, key, DEFAULT_MIN_ZOOM));
                    break;
                default:
                    throw new IllegalArgumentException("Unknown PDFView setting: " + key);
            }
        }
    }

    @Override
    public void dispose() {
        // #261 memory leak / #263 surface lock / #280 EGL race:
        // Hide first so Flutter stops drawing into the platform surface, then
        // recycle Pdfium resources on the main thread and drop channel handlers.
        disposed = true;
        methodChannel.setMethodCallHandler(null);
        mainHandler.removeCallbacksAndMessages(null);
        final PDFView view = pdfView;
        pdfView = null;
        configurator = null;
        if (view != null) {
            try {
                view.setVisibility(View.GONE);
            } catch (Exception ignored) {
            }
            Runnable recycle = () -> {
                try {
                    view.recycle();
                } catch (Exception e) {
                    Log.w(TAG, "dispose recycle", e);
                }
            };
            if (Looper.myLooper() == Looper.getMainLooper()) {
                // Defer one frame so an in-flight PlatformViewWrapper.draw can finish.
                view.post(recycle);
            } else {
                mainHandler.post(recycle);
            }
        }
    }

    private boolean getBoolean(Map<String, Object> params, String key) {
        Boolean keyObj = (Boolean) params.get(key);
        boolean bKey;
        bKey = Objects.requireNonNullElse(keyObj, false);
        return params.containsKey(key) && bKey;
    }

    private String getString(Map<String, Object> params, String key) {
        return params.containsKey(key) ? (String) params.get(key) : "";
    }

    private int getInt(Map<String, Object> params, String key) {
        Integer keyObj = (Integer) params.get(key);
        int intKey;
        intKey = Objects.requireNonNullElse(keyObj, 0);
        return params.containsKey(key) ? intKey : 0;
    }

    private float getFloat(Map<String, Object> params, String key, float defaultValue) {
        Object value = params.get(key);
        if (value instanceof Number) {
            return ((Number) value).floatValue();
        }
        return defaultValue;
    }

    private FitPolicy getFitPolicy(Map<String, Object> params) {
        String fitPolicy = getString(params, "fitPolicy");
        return switch (fitPolicy) {
            case "FitPolicy.WIDTH" -> FitPolicy.WIDTH;
            case "FitPolicy.HEIGHT" -> FitPolicy.HEIGHT;
            default -> FitPolicy.BOTH;
        };
    }

    private Uri getURI(final String uri) {
        if (uri == null || uri.isEmpty()) {
            return Uri.EMPTY;
        }
        // Absolute filesystem paths without a scheme (common with path_provider /
        // temp downloads) must use file:// — Uri.parse alone can yield a path
        // that ContentResolver rejects with "No content provider" (#266).
        if (uri.startsWith("/") || uri.startsWith("file:/")) {
            if (uri.startsWith("file:")) {
                return Uri.parse(uri);
            }
            return Uri.fromFile(new File(uri));
        }
        Uri parsed = Uri.parse(uri);
        if (parsed.getScheme() == null || parsed.getScheme().isEmpty()) {
            return Uri.fromFile(new File(uri));
        }
        return parsed;
    }

    @Override
    public void onFlutterViewAttached(@NonNull View flutterView) {
        // Ensure pages re-render when reattached after dialog/rotation (#9, #182).
        if (!disposed && pdfView != null && pdfView.getPageCount() > 0) {
            pdfView.post(() -> {
                if (!disposed && pdfView != null) {
                    try {
                        pdfView.loadPages();
                        pdfView.invalidate();
                    } catch (Exception e) {
                        Log.w(TAG, "onFlutterViewAttached", e);
                    }
                }
            });
        }
    }
}
