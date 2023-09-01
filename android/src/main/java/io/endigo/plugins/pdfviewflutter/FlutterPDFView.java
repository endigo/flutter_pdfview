package io.endigo.plugins.pdfviewflutter;

import android.content.Context;
import android.view.View;
import android.net.Uri;

import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import io.flutter.plugin.platform.PlatformView;

import java.io.File;
import java.util.HashMap;
import java.util.Map;

import com.github.barteksc.pdfviewer.PDFView;
import com.github.barteksc.pdfviewer.PDFView.Configurator;
import com.github.barteksc.pdfviewer.listener.*;
import com.github.barteksc.pdfviewer.util.Constants;
import com.github.barteksc.pdfviewer.util.FitPolicy;

import com.github.barteksc.pdfviewer.link.LinkHandler;
import com.google.gson.Gson;

import org.json.JSONObject;

public class FlutterPDFView implements PlatformView, MethodCallHandler {
    private final PDFView pdfView;
    private final MethodChannel methodChannel;
    private final LinkHandler linkHandler;
    // Initialize Gson
    Gson gson = new Gson();

    @SuppressWarnings("unchecked")
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
                    .enableDoubletap(getBoolean(params, "enableDoubleTap"))
                    .enableAntialiasing(getBoolean(params, "enableAntialiasing"))
                    .enableAnnotationRendering(getBoolean(params, "enableAnnotationRendering"))
                    .enableSwipe(getBoolean(params, "enableSwipe"))
                    .swipeHorizontal(getBoolean(params, "swipeHorizontal"))
                    .password(getString(params, "password"))
                    .nightMode(getBoolean(params, "nightMode"))
                    .autoSpacing(getBoolean(params, "autoSpacing"))
                    .pageFling(getBoolean(params, "pageFling"))
                    .pageSnap(getBoolean(params, "pageSnap"))
                    .pageFitPolicy(getFitPolicy(params))
                    .linkHandler(linkHandler)
                    // .fitEachPage(getBoolean(params,"fitEachPage"))
                    .onTap(motionEvent -> {
                        Map<String, Object> args = new HashMap<>();
                        // Convert the object to JSON
                        String json = gson.toJson(motionEvent);
                        args.put("motionEvent", json);
                        methodChannel.invokeMethod("onTap", args);
                        return true;
                    })
                    .onDoubleTap((animator, oldZoom, newZoom) -> {
                        Map<String, Object> args = new HashMap<>();
                        // Convert the object to JSON
                        String json = gson.toJson(animator);
                        args.put("animator", json);
                        args.put("oldZoom", oldZoom);
                        args.put("newZoom", newZoom);
                        methodChannel.invokeMethod("onDoubleTap", args);
                        return true;
                    })
                    .onPinchZoom((animator, oldZoom, newZoom) -> {
                        Map<String, Object> args = new HashMap<>();
                        // Convert the object to JSON
                        String json = gson.toJson(animator);
                        args.put("animator", json);
                        args.put("oldZoom", oldZoom);
                        args.put("newZoom", newZoom);
                        methodChannel.invokeMethod("onPinchZoom", args);
                        return true;
                    })
                    .onScrollAnimation((animation, scrollMoveDirection) -> {
                        Map<String, Object> args = new HashMap<>();
                        // Convert the object to JSON
                        String json = gson.toJson(animation);
                        args.put("animation", json);
                        args.put("scrollMoveDirection", scrollMoveDirection);
                        methodChannel.invokeMethod("onScrollAnimation", args);
                        return true;
                    })
                    .onPageChange((page, total) -> {
                        Map<String, Object> args = new HashMap<>();
                        args.put("page", page);
                        args.put("total", total);
                        methodChannel.invokeMethod("onPageChanged", args);
                    })
                    .onError(throwable -> {
                        Map<String, Object> args = new HashMap<>();
                        args.put("error", throwable.toString());
                        methodChannel.invokeMethod("onError", args);
                    })
                    .onPageError((page, throwable) -> {
                        Map<String, Object> args = new HashMap<>();
                        args.put("page", page);
                        args.put("error", throwable.toString());
                        methodChannel.invokeMethod("onPageError", args);
                    })
                    .onRender(pages -> {
                        Map<String, Object> args = new HashMap<>();
                        args.put("pages", pages);
                        methodChannel.invokeMethod("onRender", args);
                    })
                    .defaultPage(getInt(params, "defaultPage"))
                    .load();
        }
    }

    @Override
    public View getView() {
        return pdfView;
    }

    @Override
    public void onMethodCall(MethodCall methodCall, Result result) {
        switch (methodCall.method) {
            case "pageCount":
                getPageCount(result);
                break;
            case "currentPage":
                getCurrentPage(result);
                break;
            case "setPage":
                setPage(methodCall, result);
                break;
            case "zoomTo":
                zoomTo(methodCall, result);
                break;
            case "resetZoom":
                resetZoom(result);
                break;
            case "getZoom":
                getZoom(result);
                break;
            case "getPageSize":
                getPageSize(methodCall, result);
                break;

            case "getPageWidth":
                getPageWidth(methodCall, result);

                //TODO: CREATE METHOD ... AQUI VAMOS


            case "updateSettings":
                updateSettings(methodCall, result);
                break;
            default:
                result.notImplemented();
                break;
        }
    }

    private void getPageWidth(MethodCall methodCall, Result result) {
        if (methodCall.argument("pageIndex") != null) {
            int page = (int) methodCall.argument("pageIndex");
            result.success(pdfView.getPageSize(page).getWidth());
        }
    }

    private void getPageSize(MethodCall methodCall, Result result) {
        String json = gson.toJson(pdfView.getPageSize(pdfView.getCurrentPage()));
        if (methodCall.argument("pageIndex") != null) {
            int page = (int) methodCall.argument("pageIndex");
            //convert Object to JSON
            json = gson.toJson(pdfView.getPageSize(page));
        }
        result.success(json);
    }

    private void getZoom(Result result) {
        result.success(pdfView.getZoom());
    }

    private void resetZoom(Result result) {
        pdfView.resetZoom();
        result.success(true);
    }


    private void zoomTo(MethodCall methodCall, Result result) {
        if (methodCall.argument("zoom") != null) {
            float zoom = (float) methodCall.argument("zoom");
            pdfView.zoomTo(zoom);
        }

        result.success(true);
    }

    void getPageCount(Result result) {
        result.success(pdfView.getPageCount());
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
