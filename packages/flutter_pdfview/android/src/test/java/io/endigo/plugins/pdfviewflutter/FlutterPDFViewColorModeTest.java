package io.endigo.plugins.pdfviewflutter;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertNull;
import static org.junit.Assert.assertThrows;
import static org.mockito.ArgumentMatchers.isNull;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;

import android.content.Context;
import android.graphics.drawable.ColorDrawable;
import android.view.View;

import org.junit.Before;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.robolectric.RobolectricTestRunner;
import org.robolectric.RuntimeEnvironment;
import org.robolectric.annotation.Config;

import java.util.HashMap;
import java.util.Map;

import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

/**
 * {@code applySettings} is private, so drive
 * {@link FlutterPDFView#onMethodCall} with {@code updateSettings} and assert
 * {@code colorMode} / {@code backgroundColor} are accepted (not
 * {@link IllegalArgumentException}) and applied via the hardware-layer path.
 */
@RunWith(RobolectricTestRunner.class)
@Config(sdk = 35)
public class FlutterPDFViewColorModeTest {

    private Context context;
    private BinaryMessenger messenger;
    private int nextViewId;

    @Before
    public void setUp() {
        context = RuntimeEnvironment.getApplication();
        messenger = mock(BinaryMessenger.class);
    }

    private FlutterPDFView newView(Map<String, Object> params) {
        return new FlutterPDFView(context, messenger, nextViewId++, params);
    }

    private void updateSettings(FlutterPDFView view, Map<String, Object> settings) {
        MethodChannel.Result result = mock(MethodChannel.Result.class);
        view.onMethodCall(new MethodCall("updateSettings", settings), result);
        verify(result).success(isNull());
    }

    @Test
    public void updateSettings_acceptsColorModeDark() {
        FlutterPDFView pdf = newView(new HashMap<>());
        Map<String, Object> settings = new HashMap<>();
        settings.put("colorMode", "dark");
        updateSettings(pdf, settings);

        View view = pdf.getView();
        assertEquals(View.LAYER_TYPE_HARDWARE, view.getLayerType());
    }

    @Test
    public void updateSettings_acceptsColorModeLight() {
        Map<String, Object> create = new HashMap<>();
        create.put("colorMode", "dark");
        FlutterPDFView pdf = newView(create);

        Map<String, Object> settings = new HashMap<>();
        settings.put("colorMode", "light");
        updateSettings(pdf, settings);

        View view = pdf.getView();
        assertEquals(View.LAYER_TYPE_NONE, view.getLayerType());
    }

    @Test
    public void updateSettings_acceptsBackgroundColor() {
        FlutterPDFView pdf = newView(new HashMap<>());
        Map<String, Object> settings = new HashMap<>();
        settings.put("backgroundColor", 0xFFFEF7FF);
        updateSettings(pdf, settings);

        View view = pdf.getView();
        ColorDrawable bg = (ColorDrawable) view.getBackground();
        assertEquals(0xFFFEF7FF, bg.getColor());
    }

    @Test
    public void updateSettings_colorModeAndBackgroundColor_together_darkCompensatesGutter() {
        // Both keys in one map must not throw and must compensate gutter with M(bg).
        FlutterPDFView pdf = newView(new HashMap<>());
        int requested = 0xFF121212;
        Map<String, Object> settings = new HashMap<>();
        settings.put("colorMode", "dark");
        settings.put("backgroundColor", requested);
        updateSettings(pdf, settings);

        View view = pdf.getView();
        assertEquals(View.LAYER_TYPE_HARDWARE, view.getLayerType());
        ColorDrawable bg = (ColorDrawable) view.getBackground();
        int expected = PdfColorMatrix.transformColor(requested, PdfColorMatrix.LUMINANCE_INVERT);
        assertEquals(expected, bg.getColor());
    }

    @Test
    public void updateSettings_darkWithoutBackground_setsNullBackground() {
        FlutterPDFView pdf = newView(new HashMap<>());
        Map<String, Object> settings = new HashMap<>();
        settings.put("colorMode", "dark");
        updateSettings(pdf, settings);

        View view = pdf.getView();
        assertEquals(View.LAYER_TYPE_HARDWARE, view.getLayerType());
        // Never TRANSPARENT — AndroidPdfViewer self-fills only when background is null.
        assertNull(view.getBackground());
    }

    @Test
    public void updateSettings_legacyNightMode_mapsToHardwareLayer() {
        FlutterPDFView pdf = newView(new HashMap<>());
        Map<String, Object> settings = new HashMap<>();
        settings.put("nightMode", true);
        updateSettings(pdf, settings);

        assertEquals(View.LAYER_TYPE_HARDWARE, pdf.getView().getLayerType());
    }

    @Test
    public void creationParams_colorModeDark_appliesHardwareLayer() {
        Map<String, Object> params = new HashMap<>();
        params.put("colorMode", "dark");
        params.put("backgroundColor", 0xFFFEF7FF);
        FlutterPDFView pdf = newView(params);

        View view = pdf.getView();
        assertEquals(View.LAYER_TYPE_HARDWARE, view.getLayerType());
        ColorDrawable bg = (ColorDrawable) view.getBackground();
        int expected = PdfColorMatrix.transformColor(0xFFFEF7FF, PdfColorMatrix.LUMINANCE_INVERT);
        assertEquals(expected, bg.getColor());
    }

    @Test
    public void updateSettings_unknownKey_stillThrows() {
        FlutterPDFView pdf = newView(new HashMap<>());
        Map<String, Object> settings = new HashMap<>();
        settings.put("notARealSetting", true);
        assertThrows(IllegalArgumentException.class, () ->
                pdf.onMethodCall(
                        new MethodCall("updateSettings", settings),
                        mock(MethodChannel.Result.class)
                )
        );
    }
}
