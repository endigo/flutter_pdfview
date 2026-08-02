package io.endigo.plugins.pdfviewflutter;

import android.content.Context;
import android.content.Intent;
import android.net.Uri;
import android.util.Log;

import androidx.annotation.VisibleForTesting;

import com.github.barteksc.pdfviewer.PDFView;
import com.github.barteksc.pdfviewer.link.LinkHandler;
import com.github.barteksc.pdfviewer.model.LinkTapEvent;

import io.flutter.plugin.common.MethodChannel;

public class PDFLinkHandler implements LinkHandler {
    PDFView pdfView;
    Context context;
    MethodChannel methodChannel;
    boolean preventLinkNavigation;

    public PDFLinkHandler(Context context, PDFView pdfView, MethodChannel methodChannel, boolean preventLinkNavigation) {
        this.context = context;
        this.pdfView = pdfView;
        this.methodChannel = methodChannel;
        this.preventLinkNavigation = preventLinkNavigation;
    }

    @Override
    public void handleLinkEvent(LinkTapEvent event) {
        String uri = event.getLink().getUri();
        Integer page = event.getLink().getDestPageIdx();
        if (uri != null && !uri.isEmpty()) {
            handleUri(uri);
        } else if (page != null) {
            handlePage(page);
        }
    }

    @VisibleForTesting
    void handleUri(String uri) {
        // If the property is true just pass the link back to flutter
        if (!this.preventLinkNavigation) {
            Uri parsedUri = Uri.parse(uri);
            String scheme = parsedUri.getScheme();
            // Only auto-launch browser links. file:// throws FileUriExposedException
            // on API 24+; intent:// and content:// can target host-app components.
            // Non-http(s) schemes are still reported to Dart via onLinkHandler.
            if (isBrowserScheme(scheme)) {
                Intent intent = new Intent(Intent.ACTION_VIEW);
                intent.setData(parsedUri);
                intent.addCategory(Intent.CATEGORY_BROWSABLE);
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);

                // Don't pre-check with resolveActivity(): on Android 11+ package
                // visibility rules make it return null without a <queries> entry in
                // the host app, silently breaking every external link.
                try {
                    context.startActivity(intent, null);
                } catch (RuntimeException e) {
                    // ActivityNotFoundException and FileUriExposedException (API 24+)
                    // must not crash the host app for hostile or unresolvable PDF links.
                    Log.w(FlutterPDFView.TAG, "Failed to open URI: " + uri, e);
                }
            }
        }
        this.onLinkHandler(uri);
    }

    private static boolean isBrowserScheme(String scheme) {
        return scheme != null
                && (scheme.equalsIgnoreCase("http") || scheme.equalsIgnoreCase("https"));
    }

    @VisibleForTesting
    void handlePage(int page) {
        pdfView.jumpTo(page);
    }

    // Notify Flutter of Link request
    private void onLinkHandler(String uri) {
        this.methodChannel.invokeMethod("onLinkHandler", uri);
    }

    public void setPreventLinkNavigation(boolean value){
        this.preventLinkNavigation = value;
    }
}
