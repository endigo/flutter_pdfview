package io.endigo.plugins.pdfviewflutter;

import android.content.Context;
import android.view.View;
import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import io.flutter.plugin.platform.PlatformView;
import java.io.File;
import java.util.Map;

import com.github.barteksc.pdfviewer.PDFView;

public class FlutterPDFView implements PlatformView, MethodCallHandler {
    private final PDFView pdfView;
    private final MethodChannel methodChannel;

    @SuppressWarnings("unchecked")
    FlutterPDFView(Context context, BinaryMessenger messenger, int id, Map<String, Object> params) {
        pdfView = new PDFView(context, null);

        methodChannel = new MethodChannel(messenger, "plugins.endigo.io/pdfview_" + id);
        methodChannel.setMethodCallHandler(this);

        if (params.containsKey("filePath")) {
            String filePath = (String) params.get("filePath");

            File file = new File(filePath);

            pdfView.fromFile(file)
                .enableSwipe(getBoolean(params, "enableSwipe"))
                .swipeHorizontal(getBoolean(params, "swipeHorizontal"))
                .password(getString(params,"password"))
                .nightMode(getBoolean(params,"nightMode"))
                .autoSpacing(getBoolean(params,"autoSpacing"))
                .pageFling(getBoolean(params,"pageFling"))
                .pageSnap(getBoolean(params,"pageSnap"))
                .enableDoubletap(true)
                .defaultPage(0)
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
            case "open":
//                openFile(methodCall, result);
                break;
            default:
                result.notImplemented();
        }
    }

//    void openFile(MethodCall methodCall, Result result) {
//        Map<String, Object> arguments = (Map<String, Object>) methodCall.arguments;
//        String filePath = (String) arguments.get("filePath");
//
//        pdfView.fromFile(file)
//            .enableSwipe(getBoolean(methodCall, "enableSwipe"))
//            .swipeHorizontal(getBoolean(methodCall, "swipeHorizontal"))
//            .password(getString(methodCall,"password"))
//            .nightMode(getBoolean(methodCall,"nightMode"))
//            .autoSpacing(getBoolean(methodCall,"autoSpacing"))
//            .pageFling(getBoolean(methodCall,"pageFling"))
//            .pageSnap(getBoolean(methodCall,"pageSnap"))
//            .enableDoubletap(true)
//            .defaultPage(0)
//            .load();
//
//        result.success(null);
//    }

    @Override
    public void dispose() {
        methodChannel.setMethodCallHandler(null);
    }

    Boolean getBoolean(Map<String, Object> params, String key) {
        return params.containsKey(key) ? (Boolean) params.get(key): false;
    }

    String getString(Map<String, Object> params, String key) {
        return params.containsKey(key) ? (String) params.get(key): "";
    }
}