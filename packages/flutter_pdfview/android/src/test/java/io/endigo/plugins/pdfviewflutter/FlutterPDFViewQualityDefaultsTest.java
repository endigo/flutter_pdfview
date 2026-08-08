package io.endigo.plugins.pdfviewflutter;

import static org.junit.Assert.assertArrayEquals;
import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

import com.github.barteksc.pdfviewer.util.Constants;

import org.junit.After;
import org.junit.Before;
import org.junit.Test;

import java.util.Collections;
import java.util.HashMap;
import java.util.Map;

/**
 * Density-aware quality defaults and boolean param fallbacks for #158.
 *
 * AndroidPdfViewer exposes process-wide statics ({@link Constants#THUMBNAIL_RATIO},
 * {@link Constants.Cache}). These tests restore them after each case.
 */
public class FlutterPDFViewQualityDefaultsTest {

    private float originalThumbnailRatio;
    private int originalCacheSize;
    private int originalThumbnailCacheSize;

    @Before
    public void setUp() {
        originalThumbnailRatio = Constants.THUMBNAIL_RATIO;
        originalCacheSize = Constants.Cache.CACHE_SIZE;
        originalThumbnailCacheSize = Constants.Cache.THUMBNAILS_CACHE_SIZE;
    }

    @After
    public void tearDown() {
        Constants.THUMBNAIL_RATIO = originalThumbnailRatio;
        Constants.Cache.CACHE_SIZE = originalCacheSize;
        Constants.Cache.THUMBNAILS_CACHE_SIZE = originalThumbnailCacheSize;
    }

    // ------------------------------------------------- cacheSizesForDensity

    @Test
    public void cacheSizes_ldpi_usesLibraryBaselines() {
        assertArrayEquals(
                new int[]{
                        FlutterPDFView.BASE_PAGE_PART_CACHE_SIZE,
                        FlutterPDFView.BASE_THUMBNAIL_CACHE_SIZE
                },
                FlutterPDFView.cacheSizesForDensity(1.0f));
    }

    @Test
    public void cacheSizes_justBelow2x_stillBaseline() {
        assertArrayEquals(
                new int[]{
                        FlutterPDFView.BASE_PAGE_PART_CACHE_SIZE,
                        FlutterPDFView.BASE_THUMBNAIL_CACHE_SIZE
                },
                FlutterPDFView.cacheSizesForDensity(1.99f));
    }

    @Test
    public void cacheSizes_xhdpi() {
        assertArrayEquals(new int[]{150, 10}, FlutterPDFView.cacheSizesForDensity(2.0f));
    }

    @Test
    public void cacheSizes_xxhdpi() {
        assertArrayEquals(new int[]{180, 12}, FlutterPDFView.cacheSizesForDensity(2.5f));
        assertArrayEquals(new int[]{180, 12}, FlutterPDFView.cacheSizesForDensity(3.0f));
    }

    @Test
    public void cacheSizes_highXxxhdpi() {
        assertArrayEquals(new int[]{200, 16}, FlutterPDFView.cacheSizesForDensity(3.5f));
        assertArrayEquals(new int[]{200, 16}, FlutterPDFView.cacheSizesForDensity(4.0f));
    }

    // ----------------------------------------- applyDisplayQualityDefaults

    @Test
    public void applyDefaults_missingThumbnail_usesPluginDefault() {
        Constants.THUMBNAIL_RATIO = 0.3f;
        FlutterPDFView.applyDisplayQualityDefaults(1.0f, Collections.emptyMap());
        assertEquals(FlutterPDFView.DEFAULT_THUMBNAIL_RATIO, Constants.THUMBNAIL_RATIO, 0f);
    }

    @Test
    public void applyDefaults_explicitThumbnail_isApplied() {
        FlutterPDFView.applyDisplayQualityDefaults(
                1.0f, Collections.singletonMap("thumbnailRatio", 0.55d));
        assertEquals(0.55f, Constants.THUMBNAIL_RATIO, 0f);
    }

    @Test
    public void applyDefaults_invalidThumbnail_doesNotOverwrite() {
        Constants.THUMBNAIL_RATIO = 0.42f;
        Map<String, Object> params = new HashMap<>();
        params.put("thumbnailRatio", 1.5d);
        FlutterPDFView.applyDisplayQualityDefaults(1.0f, params);
        assertEquals(0.42f, Constants.THUMBNAIL_RATIO, 0f);
    }

    @Test
    public void applyDefaults_raisesCacheOnHighDpi() {
        Constants.Cache.CACHE_SIZE = FlutterPDFView.BASE_PAGE_PART_CACHE_SIZE;
        Constants.Cache.THUMBNAILS_CACHE_SIZE = FlutterPDFView.BASE_THUMBNAIL_CACHE_SIZE;
        FlutterPDFView.applyDisplayQualityDefaults(3.0f, Collections.emptyMap());
        assertEquals(180, Constants.Cache.CACHE_SIZE);
        assertEquals(12, Constants.Cache.THUMBNAILS_CACHE_SIZE);
    }

    @Test
    public void applyDefaults_neverLowersExistingLargerCache() {
        Constants.Cache.CACHE_SIZE = 500;
        Constants.Cache.THUMBNAILS_CACHE_SIZE = 40;
        FlutterPDFView.applyDisplayQualityDefaults(3.0f, Collections.emptyMap());
        assertEquals(500, Constants.Cache.CACHE_SIZE);
        assertEquals(40, Constants.Cache.THUMBNAILS_CACHE_SIZE);
    }

    @Test
    public void applyDefaults_ldpi_leavesBaselines() {
        Constants.Cache.CACHE_SIZE = FlutterPDFView.BASE_PAGE_PART_CACHE_SIZE;
        Constants.Cache.THUMBNAILS_CACHE_SIZE = FlutterPDFView.BASE_THUMBNAIL_CACHE_SIZE;
        FlutterPDFView.applyDisplayQualityDefaults(1.0f, Collections.emptyMap());
        assertEquals(FlutterPDFView.BASE_PAGE_PART_CACHE_SIZE, Constants.Cache.CACHE_SIZE);
        assertEquals(FlutterPDFView.BASE_THUMBNAIL_CACHE_SIZE, Constants.Cache.THUMBNAILS_CACHE_SIZE);
    }

    // --------------------------------------------- getBoolean with default

    @Test
    public void getBoolean_withDefault_missingKey_returnsDefault() {
        assertTrue(FlutterPDFView.getBoolean(Collections.emptyMap(), "useBestQuality", true));
        assertFalse(FlutterPDFView.getBoolean(Collections.emptyMap(), "useBestQuality", false));
    }

    @Test
    public void getBoolean_withDefault_presentFalse_wins() {
        assertFalse(
                FlutterPDFView.getBoolean(
                        Collections.singletonMap("useBestQuality", false),
                        "useBestQuality",
                        true));
    }

    @Test
    public void getBoolean_withDefault_nullValue_returnsDefault() {
        Map<String, Object> params = new HashMap<>();
        params.put("useBestQuality", null);
        assertTrue(FlutterPDFView.getBoolean(params, "useBestQuality", true));
    }

    @Test
    public void qualityFlagDefaults_matchDartPdfView() {
        assertTrue(FlutterPDFView.DEFAULT_USE_BEST_QUALITY);
        assertTrue(FlutterPDFView.DEFAULT_ENABLE_ANTIALIASING);
        assertTrue(FlutterPDFView.DEFAULT_ENABLE_RENDER_DURING_SCALE);
        assertEquals(0.8f, FlutterPDFView.DEFAULT_THUMBNAIL_RATIO, 0f);
    }
}
