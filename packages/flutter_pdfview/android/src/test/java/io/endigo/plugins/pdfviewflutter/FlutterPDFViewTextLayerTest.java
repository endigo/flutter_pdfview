package io.endigo.plugins.pdfviewflutter;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

import java.util.HashMap;
import java.util.Map;
import org.junit.Test;

/**
 * Text-layer creation params and the unsupported-platform contract (#137, #285).
 *
 * <p>AndroidPdfViewer ships a libpdfium that exports the {@code FPDFText_*} family, but
 * PdfiumCore binds none of it in Java, so there is no text to search or select. The native
 * side must therefore fail these calls loudly; returning an empty result would read to an app
 * as "this document contains no matches".
 */
public class FlutterPDFViewTextLayerTest {

    private static Map<String, Object> params(String key, Object value) {
        Map<String, Object> params = new HashMap<>();
        params.put(key, value);
        return params;
    }

    @Test
    public void enableTextSelection_defaultsToTrue() {
        assertTrue(FlutterPDFView.DEFAULT_ENABLE_TEXT_SELECTION);
        assertTrue(
                FlutterPDFView.getBoolean(
                        new HashMap<>(),
                        "enableTextSelection",
                        FlutterPDFView.DEFAULT_ENABLE_TEXT_SELECTION));
    }

    @Test
    public void enableTextSelection_readsBothValues() {
        assertFalse(
                FlutterPDFView.getBoolean(
                        params("enableTextSelection", false),
                        "enableTextSelection",
                        FlutterPDFView.DEFAULT_ENABLE_TEXT_SELECTION));
        assertTrue(
                FlutterPDFView.getBoolean(
                        params("enableTextSelection", true),
                        "enableTextSelection",
                        FlutterPDFView.DEFAULT_ENABLE_TEXT_SELECTION));
    }

    @Test
    public void enableCopy_readsBothValues() {
        assertFalse(FlutterPDFView.getBoolean(params("enableCopy", false), "enableCopy", true));
        assertTrue(FlutterPDFView.getBoolean(params("enableCopy", true), "enableCopy", false));
    }

    /**
     * Pins the wire contract with Dart. {@code MethodChannelPdfViewController} turns exactly this
     * code into an {@code UnsupportedError}; if the two ever drift, the Dart side would surface a
     * raw PlatformException instead and the "unsupported vs. no matches" distinction would be lost.
     */
    @Test
    public void unsupportedCode_matchesThePlatformInterfaceConstant() {
        assertEquals("text_layer_unsupported", FlutterPDFView.TEXT_LAYER_UNSUPPORTED_CODE);
    }
}
