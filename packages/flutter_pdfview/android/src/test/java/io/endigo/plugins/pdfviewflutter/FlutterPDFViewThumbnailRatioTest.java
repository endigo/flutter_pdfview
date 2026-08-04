package io.endigo.plugins.pdfviewflutter;

import static org.junit.Assert.assertEquals;
import static org.mockito.Mockito.mock;

import android.content.Context;

import com.github.barteksc.pdfviewer.util.Constants;

import org.junit.After;
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
 * {@code Constants.THUMBNAIL_RATIO} is a process-wide static in AndroidPdfViewer.
 * A ratio outside (0, 1] makes it allocate zero-sized or oversized thumbnail
 * bitmaps, which blows up at render time, so {@link FlutterPDFView}'s constructor
 * only writes values inside that range.
 */
@RunWith(RobolectricTestRunner.class)
@Config(sdk = 35)
public class FlutterPDFViewThumbnailRatioTest {

    /** Distinct from every value used in the tests so a write is unmistakable. */
    private static final float SENTINEL = 0.123f;

    private float originalRatio;
    private Context context;
    private BinaryMessenger messenger;
    private int nextViewId;

    @Before
    public void setUp() {
        originalRatio = Constants.THUMBNAIL_RATIO;
        context = RuntimeEnvironment.getApplication();
        messenger = mock(BinaryMessenger.class);
    }

    @After
    public void tearDown() {
        Constants.THUMBNAIL_RATIO = originalRatio;
    }

    /** Builds a view with only {@code thumbnailRatio} set and returns the resulting global. */
    private float ratioAfterCreating(Object thumbnailRatio) {
        Constants.THUMBNAIL_RATIO = SENTINEL;
        Map<String, Object> params = new HashMap<>();
        if (thumbnailRatio != null) {
            params.put("thumbnailRatio", thumbnailRatio);
        }
        new FlutterPDFView(context, messenger, nextViewId++, params);
        return Constants.THUMBNAIL_RATIO;
    }

    @Test
    public void zero_isRejected() {
        assertEquals(SENTINEL, ratioAfterCreating(0.0d), 0f);
    }

    @Test
    public void negative_isRejected() {
        assertEquals(SENTINEL, ratioAfterCreating(-1.0d), 0f);
    }

    @Test
    public void greaterThanOne_isRejected() {
        assertEquals(SENTINEL, ratioAfterCreating(1.5d), 0f);
    }

    @Test
    public void nonNumericValue_fallsBackToPluginDefault() {
        // Same path as a missing param: only Numbers in (0, 1] write the static.
        assertEquals(FlutterPDFView.DEFAULT_THUMBNAIL_RATIO, ratioAfterCreating("0.5"), 0f);
    }

    @Test
    public void missingValue_appliesPluginDefault() {
        // #158: AndroidPdfViewer defaults to 0.3; the plugin matches Dart's 0.8
        // when the creation param is omitted so first paint is not soft.
        assertEquals(FlutterPDFView.DEFAULT_THUMBNAIL_RATIO, ratioAfterCreating(null), 0f);
    }

    @Test
    public void halfway_isAccepted() {
        assertEquals(0.5f, ratioAfterCreating(0.5d), 0f);
    }

    @Test
    public void one_isAccepted() {
        assertEquals(1.0f, ratioAfterCreating(1.0d), 0f);
    }

    @Test
    public void integerOne_isAccepted() {
        // Dart sends 1 (not 1.0) as a java.lang.Integer over the method channel.
        assertEquals(1.0f, ratioAfterCreating(1), 0f);
    }

    @Test
    public void smallPositiveValue_isAccepted() {
        assertEquals(0.01f, ratioAfterCreating(0.01d), 1e-7f);
    }
}
