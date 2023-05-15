package io.endigo.plugins.pdfviewflutter;

import android.content.Context;
import android.graphics.Bitmap;
import android.graphics.Canvas;
import android.net.Uri;
import android.util.Log;
import android.view.View;

import com.github.barteksc.pdfviewer.PDFView;
import com.github.barteksc.pdfviewer.PDFView.Configurator;
import com.github.barteksc.pdfviewer.link.LinkHandler;
import com.github.barteksc.pdfviewer.util.FitPolicy;
import com.shockwave.pdfium.util.SizeF;

import java.io.File;
import java.io.FileOutputStream;
import java.util.HashMap;
import java.util.Map;
import java.util.Objects;

import androidx.annotation.NonNull;
import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import io.flutter.plugin.platform.PlatformView;

public class FlutterPDFView implements PlatformView, MethodCallHandler {
    private final PDFView pdfView;
    private final Configurator configurator;
    private final MethodChannel methodChannel;
    private final LinkHandler linkHandler;
    public static final String TAG = "FlutterPDFView";

    //@SuppressWarnings("unchecked")
    FlutterPDFView(Context context, BinaryMessenger messenger, int id, Map<String, Object> params) {
        pdfView = new PDFView(context, null);
        final boolean preventLinkNavigation = getBoolean(params, "preventLinkNavigation");

        methodChannel = new MethodChannel(messenger, "plugins.endigo.io/pdfview_" + id);
        methodChannel.setMethodCallHandler(this);

        linkHandler = new PDFLinkHandler(context, pdfView, methodChannel, preventLinkNavigation);

        Configurator config = null;
        if (params.get("filePath") != null) {
            String filePath = (String) params.get("filePath");
            config = pdfView.fromUri(getURI(filePath));
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
                    .linkHandler(linkHandler).
                    enableAntialiasing(false)
                    // .fitEachPage(getBoolean(params,"fitEachPage"))
                    .onPageChange((page, total) -> {
                        Map<String, Object> args = new HashMap<>();
                        args.put("page", page);
                        args.put("total", total);
                        methodChannel.invokeMethod("onPageChanged", args);
                    }).onError(t -> {
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
                        Map<String, Object> args = new HashMap<>();
                        args.put("zoom", pdfView.getZoom());
                        args.put("pageWidth", pageWidth);
                        args.put("pageHeight", pageHeight);
                        methodChannel.invokeMethod("onDraw", args);
                    }).onLoad(nbPages -> {
                        Map<String, Object> args = new HashMap<>();
                        args.put("pages", nbPages);
                        methodChannel.invokeMethod("onLoadComplete", args);
                    }).enableDoubletap(true).defaultPage(getInt(params, "defaultPage")).load();
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
            case "getPositionAndScale":
                getPositionAndScale(result);
                break;
            case "setPositionAndScale":
                setPositionAndScale(methodCall, result);
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
            default:
                result.notImplemented();
                break;
        }
    }

    void getPageCount(Result result) {
        result.success(pdfView.getPageCount());
    }

    void getCurrentPageSize(Result result) {
        SizeF size = pdfView.getPageSize(pdfView.getCurrentPage());

        result.success(new float[]{size.getWidth(), size.getHeight()});
    }

    void getPositionAndScale(Result result) {
        float xOffset = pdfView.getCurrentXOffset();
        float yOffset = pdfView.getCurrentYOffset();
        float zoom = pdfView.getZoom();

        result.success(new float[]{xOffset, yOffset, zoom});
    }

    void setPositionAndScale(MethodCall call, Result result) {
        double xOffset = call.argument("xPos");
        double yOffset = call.argument("yPos");
        double zoom = call.argument("scale");

        if (zoom != 1.0) {
            pdfView.zoomTo((float) zoom);
        }
        pdfView.moveTo((float) xOffset, (float) yOffset);
        pdfView.loadPages();
        //pdfView.refreshDrawableState();
        result.success(true);
    }

    void getScreenshot(MethodCall call, Result result) {
        String pdfFileName = call.argument("fileName");
        try {
            assert pdfFileName != null;
            String imageFileName = pdfFileName.substring(0, pdfFileName.lastIndexOf("/")) + "/image.png";
            Bitmap bmp = loadBitmapFromPDFView();
            FileOutputStream fileOut = new FileOutputStream(imageFileName, false);
            bmp.compress(Bitmap.CompressFormat.PNG, 100, fileOut);
            fileOut.close();
            if (!Objects.equals(imageFileName, "")) {
                Log.d(TAG, "getScreenshot: generate image success ");
                result.success(imageFileName);
            } else {
                result.error("FAIL", "Failed to generate image", null);
            }
        } catch (Exception e) {
            result.error("FAIL", "Failed to generate image", e.getMessage());
        }
    }

    Bitmap loadBitmapFromPDFView() {
        Bitmap bitmap = Bitmap.createBitmap(
                pdfView.getWidth(), pdfView.getHeight(), Bitmap.Config.ARGB_8888
        );
        Canvas canvas = new Canvas(bitmap);
        pdfView.draw(canvas);
        return bitmap;
    }

    void reload(Result result) {
        configurator.load();
        result.success(true);
    }

    void getCurrentPage(Result result) {
        result.success(pdfView.getCurrentPage());
    }

    void setPage(MethodCall call, Result result) {
        if (call.argument("page") != null) {
            int page = (int) call.argument("page");
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
                default:
                    throw new IllegalArgumentException("Unknown PDFView setting: " + key);
            }
        }
    }

    @Override
    public void dispose() {
        methodChannel.setMethodCallHandler(null);
    }

    boolean getBoolean(Map<String, Object> params, String key) {
        return params.containsKey(key) ? (boolean) params.get(key) : false;
    }

    String getString(Map<String, Object> params, String key) {
        return params.containsKey(key) ? (String) params.get(key) : "";
    }

    int getInt(Map<String, Object> params, String key) {
        return params.containsKey(key) ? (int) params.get(key) : 0;
    }

    FitPolicy getFitPolicy(Map<String, Object> params) {
        String fitPolicy = getString(params, "fitPolicy");
        switch (fitPolicy) {
            case "FitPolicy.WIDTH":
                return FitPolicy.WIDTH;
            case "FitPolicy.HEIGHT":
                return FitPolicy.HEIGHT;
            case "FitPolicy.BOTH":
            default:
                return FitPolicy.BOTH;
        }
    }

    private Uri getURI(final String uri) {
        Uri parsed = Uri.parse(uri);

        if (parsed.getScheme() == null || parsed.getScheme().isEmpty()) {
            return Uri.fromFile(new File(uri));
        }
        return parsed;
    }

}