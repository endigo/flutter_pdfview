package io.endigo.plugins.pdfviewflutter

import io.flutter.embedding.engine.plugins.FlutterPlugin

class PDFViewFlutterPlugin : FlutterPlugin {
    /**
     * Plugin registration.
     */
    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        binding
            .platformViewRegistry
            .registerViewFactory(
                "plugins.endigo.io/pdfview",
                PDFViewFactory(binding.binaryMessenger)
            )
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    }
}
