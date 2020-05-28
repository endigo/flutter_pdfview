package io.endigo.plugins.pdfviewflutter;

import android.content.Context;
import android.content.Intent;
import android.net.Uri;

import com.github.barteksc.pdfviewer.link.LinkHandler;
import com.github.barteksc.pdfviewer.model.LinkTapEvent;

public class PDFLinkHandler implements LinkHandler {
    Context context;

    public PDFLinkHandler(Context context) {
        this.context = context;
    }

    @Override
    public void handleLinkEvent(LinkTapEvent event) {
        String url = event.getLink().getUri();
        Intent i = new Intent(Intent.ACTION_VIEW);
        i.setData(Uri.parse(url));
        i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
        i.addFlags(Intent.FLAG_ACTIVITY_CLEAR_TASK);
        context.startActivity(i, null);
    }
}
