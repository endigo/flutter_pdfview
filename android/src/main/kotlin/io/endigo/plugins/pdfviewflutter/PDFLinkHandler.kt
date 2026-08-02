package io.endigo.plugins.pdfviewflutter

import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.util.Log

import androidx.annotation.VisibleForTesting

import com.github.barteksc.pdfviewer.PDFView
import com.github.barteksc.pdfviewer.link.LinkHandler
import com.github.barteksc.pdfviewer.model.LinkTapEvent

import io.flutter.plugin.common.MethodChannel

class PDFLinkHandler(
    private val context: Context,
    private val pdfView: PDFView,
    private val methodChannel: MethodChannel,
    private var preventLinkNavigation: Boolean
) : LinkHandler {

    override fun handleLinkEvent(event: LinkTapEvent) {
        val uri: String? = event.link.uri
        val page: Int? = event.link.destPageIdx
        if (uri != null && uri.isNotEmpty()) {
            handleUri(uri)
        } else if (page != null) {
            handlePage(page)
        }
    }

    @VisibleForTesting
    fun handleUri(uri: String) {
        // If the property is true just pass the link back to flutter
        if (!this.preventLinkNavigation) {
            val parsedUri = Uri.parse(uri)
            val intent = Intent(Intent.ACTION_VIEW)
            intent.data = parsedUri
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)

            // Don't pre-check with resolveActivity(): on Android 11+ package
            // visibility rules make it return null without a <queries> entry in
            // the host app, silently breaking every external link.
            try {
                context.startActivity(intent, null)
            } catch (e: ActivityNotFoundException) {
                Log.w(FlutterPDFView.TAG, "No activity found to open URI: $uri")
            }
        }
        this.onLinkHandler(uri)
    }

    @VisibleForTesting
    fun handlePage(page: Int) {
        pdfView.jumpTo(page)
    }

    // Notify Flutter of Link request
    private fun onLinkHandler(uri: String) {
        this.methodChannel.invokeMethod("onLinkHandler", uri)
    }

    fun setPreventLinkNavigation(value: Boolean) {
        this.preventLinkNavigation = value
    }
}
