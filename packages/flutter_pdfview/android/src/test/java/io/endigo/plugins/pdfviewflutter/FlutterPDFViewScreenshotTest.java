package io.endigo.plugins.pdfviewflutter;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertNotNull;
import static org.junit.Assert.assertNull;
import static org.mockito.Mockito.mock;

import android.content.Context;
import android.graphics.Bitmap;
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

/**
 * Regression for #175: getScreenshot must produce a real bitmap under hybrid
 * composition, not a drawing-cache / empty hardware-layer white frame.
 */
@RunWith(RobolectricTestRunner.class)
@Config(sdk = 35)
public class FlutterPDFViewScreenshotTest {

    private Context context;
    private BinaryMessenger messenger;
    private int nextViewId;

    @Before
    public void setUp() {
        context = RuntimeEnvironment.getApplication();
        messenger = mock(BinaryMessenger.class);
    }

    private FlutterPDFView newView() {
        Map<String, Object> params = new HashMap<>();
        return new FlutterPDFView(context, messenger, nextViewId++, params);
    }

    @Test
    public void loadBitmap_returnsNullWhenNotLaidOut() {
        FlutterPDFView flutterPdf = newView();
        assertNull(flutterPdf.loadBitmapFromPDFView());
    }

    @Test
    public void loadBitmap_returnsArgbBitmapOfViewSize() {
        FlutterPDFView flutterPdf = newView();
        View view = flutterPdf.getView();
        assertNotNull(view);

        view.measure(
                View.MeasureSpec.makeMeasureSpec(240, View.MeasureSpec.EXACTLY),
                View.MeasureSpec.makeMeasureSpec(320, View.MeasureSpec.EXACTLY));
        view.layout(0, 0, 240, 320);

        Bitmap bmp = flutterPdf.loadBitmapFromPDFView();
        assertNotNull(bmp);
        assertEquals(240, bmp.getWidth());
        assertEquals(320, bmp.getHeight());
        assertEquals(Bitmap.Config.ARGB_8888, bmp.getConfig());
        bmp.recycle();
    }

    @Test
    public void loadBitmap_restoresLayerTypeAfterCapture() {
        FlutterPDFView flutterPdf = newView();
        View view = flutterPdf.getView();
        assertNotNull(view);

        view.measure(
                View.MeasureSpec.makeMeasureSpec(100, View.MeasureSpec.EXACTLY),
                View.MeasureSpec.makeMeasureSpec(100, View.MeasureSpec.EXACTLY));
        view.layout(0, 0, 100, 100);

        int before = view.getLayerType();
        Bitmap bmp = flutterPdf.loadBitmapFromPDFView();
        assertNotNull(bmp);
        assertEquals(before, view.getLayerType());
        bmp.recycle();
    }
}
