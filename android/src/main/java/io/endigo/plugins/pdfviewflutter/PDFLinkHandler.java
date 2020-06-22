package io.endigo.plugins.pdfviewflutter;

import android.content.Context;
import android.content.Intent;
import android.net.Uri;

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

    private void handleUri(String uri) {
        // If the property is true just pass the link back to flutter
        if (!this.preventLinkNavigation) {
            Uri parsedUri = Uri.parse(uri);
            Intent intent = new Intent(Intent.ACTION_VIEW);
            intent.setData(parsedUri);
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            intent.addFlags(Intent.FLAG_ACTIVITY_CLEAR_TASK);

            if (intent.resolveActivity(context.getPackageManager()) != null) {
                context.startActivity(intent, null);
            }
        }
        this.onLinkHandler(uri);
    }

    private void handlePage(int page) {
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
