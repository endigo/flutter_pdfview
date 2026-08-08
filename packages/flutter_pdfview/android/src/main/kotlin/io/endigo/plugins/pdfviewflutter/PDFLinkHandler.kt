package io.endigo.plugins.pdfviewflutter

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
            val scheme = parsedUri.scheme
            // Only auto-launch browser links. file:// throws FileUriExposedException
            // on API 24+; intent:// and content:// can target host-app components.
            // Non-http(s) schemes are still reported to Dart via onLinkHandler.
            if (isBrowserScheme(scheme)) {
                val intent = Intent(Intent.ACTION_VIEW)
                intent.data = parsedUri
                intent.addCategory(Intent.CATEGORY_BROWSABLE)
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)

                // Don't pre-check with resolveActivity(): on Android 11+ package
                // visibility rules make it return null without a <queries> entry in
                // the host app, silently breaking every external link.
                try {
                    context.startActivity(intent, null)
                } catch (e: RuntimeException) {
                    // ActivityNotFoundException and FileUriExposedException (API 24+)
                    // must not crash the host app for hostile or unresolvable PDF links.
                    Log.w(FlutterPDFView.TAG, "Failed to open URI: $uri", e)
                }
            }
        }
        this.onLinkHandler(uri)
    }

    private fun isBrowserScheme(scheme: String?): Boolean =
        scheme != null && (scheme.equals("http", ignoreCase = true) ||
            scheme.equals("https", ignoreCase = true))

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
