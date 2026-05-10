package io.endigo.plugins.pdfviewflutter;

import android.content.Context;
import android.graphics.Bitmap;
import android.graphics.Canvas;
import android.net.Uri;
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

    private final PDFView pdfView;
    private final Configurator configurator;
    private final MethodChannel methodChannel;
    private final LinkHandler linkHandler;
    private final Map<String, Object> onDrawArgs = new HashMap<>();
    private long _lastDrawTime = 0;
    private static final long DRAW_THROTTLE_MS = 16; // ~1 frame at 60fps
    private final float displayDensity;
    public static final String TAG = "FlutterPDFView";


    FlutterPDFView(Context context, BinaryMessenger messenger, int id, Map<String, Object> params) {
        pdfView = new PDFView(context, null);
        displayDensity = context.getResources().getDisplayMetrics().density;
        final boolean preventLinkNavigation = getBoolean(params, "preventLinkNavigation");

        methodChannel = new MethodChannel(messenger, "plugins.endigo.io/pdfview_" + id);
        methodChannel.setMethodCallHandler(this);

        linkHandler = new PDFLinkHandler(context, pdfView, methodChannel, preventLinkNavigation);


        pdfView.useBestQuality(getBoolean(params, "useBestQuality"));
        pdfView.enableRenderDuringScale(getBoolean(params, "enableRenderDuringScale"));
        Object thumbnailRatioObj = params.get("thumbnailRatio");
        if (thumbnailRatioObj instanceof Number) {
            Constants.THUMBNAIL_RATIO = ((Number) thumbnailRatioObj).floatValue();
        }

        Configurator config = null;
        if (params.get("filePath") != null) {
            String filePath = (String) params.get("filePath");
            config = pdfView.fromUri(getURI(filePath));
        } else if (params.get("pdfData") != null) {
            byte[] data = (byte[]) params.get("pdfData");
            config = pdfView.fromBytes(data);
        }

        Object backgroundColor = params.get("backgroundColor");
        if (backgroundColor != null) {
            int color = ((Number) backgroundColor).intValue();
            pdfView.setBackgroundColor(color);
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
                    // .fitEachPage(getBoolean(params,"fitEachPage"))
                    .defaultPage(getInt(params, "defaultPage"))
                    .onPageChange((page, total) -> {
                        Map<String, Object> args = new HashMap<>();
                        args.put("page", page);
                        args.put("total", total);
                        methodChannel.invokeMethod("onPageChanged", args);
                    })
                    .onError(t -> {
                        Map<String, Object> args = new HashMap<>();
                        args.put("error", t.toString());
                        methodChannel.invokeMethod("onError", args);
                    }).onPageError((page, t) -> {
                        Map<String, Object> args = new HashMap<>();
                        args.put("page", page);
                        args.put("error", t.toString());
                        methodChannel.invokeMethod("onPageError", args);
                    }).onRender(pages -> {
                        Map<String, Object> args = new HashMap<>();
                        args.put("pages", pages);
                        methodChannel.invokeMethod("onRender", args);
                    }).onDraw((canvas, pageWidth, pageHeight, displayedPage) -> {
                        long now = System.currentTimeMillis();
                        if (now - _lastDrawTime < DRAW_THROTTLE_MS) return;
                        _lastDrawTime = now;
                        onDrawArgs.clear();
                        onDrawArgs.put("pdfXOffset", pdfView.getCurrentXOffset() / displayDensity);
                        onDrawArgs.put("pdfYOffset", pdfView.getCurrentYOffset() / displayDensity);
                        onDrawArgs.put("pdfScale", pdfView.getZoom());
                        methodChannel.invokeMethod("onDraw", onDrawArgs);
                    }).onLoad(nbPages -> {
                        Map<String, Object> args = new HashMap<>();
                        args.put("pages", nbPages);
                        methodChannel.invokeMethod("onLoadComplete", args);
                    }).load();

            float effectiveMax = getFloat(params, "maxZoom", DEFAULT_MAX_ZOOM);
            float effectiveMin = getFloat(params, "minZoom", DEFAULT_MIN_ZOOM);
//            float effectiveMax = maxZoom != null ? maxZoom : DEFAULT_MAX_ZOOM;
//            float effectiveMin = minZoom != null ? minZoom : DEFAULT_MIN_ZOOM;
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
        result.success(pdfView.getPageCount());
    }

    void getCurrentPageSize(Result result) {
        if (pdfView.getPageCount() == 0) {
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
        float xOffset = pdfView.getCurrentXOffset() / displayDensity;
        float yOffset = pdfView.getCurrentYOffset() / displayDensity;

        result.success(new float[]{xOffset, yOffset});
    }

    void getScale(Result result) {
        float zoom = pdfView.getZoom();

        result.success(zoom);
    }

    void setPosition(MethodCall call, Result result) {
        Double xPosObj = call.argument("xPos");
        double xOffset;
        xOffset = Objects.requireNonNullElse(xPosObj, 0.0); // Safe unboxing
        Double yPosObj = call.argument("yPos");
        double yOffset;
        yOffset = Objects.requireNonNullElse(yPosObj, 0.0); // Safe unboxing
        pdfView.moveTo((float) xOffset * displayDensity, (float) yOffset * displayDensity);
        pdfView.loadPages();
        result.success(true);
    }

    void setScale(MethodCall call, Result result) {
        Double scaleObj = call.argument("scale");
        double zoom;
        zoom = Objects.requireNonNullElse(scaleObj, 1.0); // Safe unboxing

        if (zoom != 1.0) {
            pdfView.zoomTo((float) zoom);
        }
        pdfView.loadPages();
        result.success(true);
    }

    void setZoomLimits(MethodCall call, Result result) {
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
        if (configurator != null) {
            configurator.load();
            result.success(true);
        } else {
            result.success(false);
        }
    }

    void getCurrentPage(Result result) {
        result.success(pdfView.getCurrentPage());
    }

    void setPage(MethodCall call, Result result) {
        if (call.argument("page") != null) {
            Integer pageObj = call.argument("page");
            int page;
            page = Objects.requireNonNullElse(pageObj, 1); // Safe unboxing
            pdfView.jumpTo(page);
        }

        result.success(true);
    }

    @SuppressWarnings("unchecked")
    private void updateSettings(MethodCall methodCall, Result result) {
        applySettings((Map<String, Object>) methodCall.arguments);
        result.success(null);
    }

    private void applySettings(Map<String, Object> settings) {
        for (String key : settings.keySet()) {
            switch (key) {
                case "enableSwipe":
                    pdfView.setSwipeEnabled(getBoolean(settings, key));
                    break;
                case "nightMode":
                    pdfView.setNightMode(getBoolean(settings, key));
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
        if (pdfView != null) {
            pdfView.recycle();
        }
        methodChannel.setMethodCallHandler(null);
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
        Uri parsed = Uri.parse(uri);

        if (parsed.getScheme() == null || parsed.getScheme().isEmpty()) {
            return Uri.fromFile(new File(uri));
        }
        return parsed;
    }

}
