package io.endigo.plugins.pdfviewflutter;

import io.flutter.plugin.common.PluginRegistry.Registrar;

public class PDFViewFlutterPlugin {
    /** Plugin registration. */
    public static void registerWith(Registrar registrar) {
        registrar
                .platformViewRegistry()
                .registerViewFactory(
                        "plugins.endigo.io/pdfview", new PDFViewFactory(registrar.messenger()));
    }
}
