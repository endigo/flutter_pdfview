package io.endigo.plugins.pdfviewflutter

import android.content.Context

import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

class PDFViewFactory(private val messenger: BinaryMessenger) :
    PlatformViewFactory(StandardMessageCodec.INSTANCE) {

    @Suppress("UNCHECKED_CAST")
    override fun create(context: Context, id: Int, args: Any?): PlatformView {
        val params = args as Map<String, Any?>
        return FlutterPDFView(context, messenger, id, params)
    }
}
