package io.endigo.plugins.pdfviewflutter;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

import org.junit.Test;

/**
 * Pure-JVM coverage for {@link ViewportMath}: the conversions that keep the
 * Dart API's relative scale (1 = fitted) meaningful on top of androidx.pdf's
 * absolute zoom (1 = one pixel per PDF point), and the search navigation.
 */
public class ViewportMathTest {

    private static final float EPS = 0.0001f;

    // ------------------------------------------------------------ fitZoom

    @Test
    public void fitZoom_width_usesWidestPage() {
        // 1080 px view, widest page 540 pt -> 2 px per point.
        assertEquals(2f, ViewportMath.fitZoom(FitPolicy.WIDTH, 1080, 1920, 540f, 800f), EPS);
    }

    @Test
    public void fitZoom_height_usesTallestPage() {
        assertEquals(2.4f, ViewportMath.fitZoom(FitPolicy.HEIGHT, 1080, 1920, 540f, 800f), EPS);
    }

    @Test
    public void fitZoom_both_isTheSmallerOfTheTwo() {
        // Landscape page in a portrait view: width is the constraint.
        assertEquals(1f, ViewportMath.fitZoom(FitPolicy.BOTH, 1080, 1920, 1080f, 600f), EPS);
        // Very tall page: height is the constraint.
        assertEquals(0.5f, ViewportMath.fitZoom(FitPolicy.BOTH, 1080, 1920, 500f, 3840f), EPS);
    }

    @Test
    public void fitZoom_unmeasured_isZero() {
        assertEquals(0f, ViewportMath.fitZoom(FitPolicy.WIDTH, 0, 1920, 540f, 800f), EPS);
        assertEquals(0f, ViewportMath.fitZoom(FitPolicy.WIDTH, 1080, 1920, 0f, 800f), EPS);
    }

    // ------------------------------------------------------------ scale conversion

    @Test
    public void relativeScale_roundTrips() {
        float fit = 2.5f;
        for (float scale : new float[] {0.5f, 1f, 1.75f, 4f}) {
            float zoom = ViewportMath.toViewZoom(scale, fit);
            assertEquals(scale, ViewportMath.toRelativeScale(zoom, fit), EPS);
        }
    }

    @Test
    public void relativeScale_beforeFirstFit_isOne() {
        assertEquals(1f, ViewportMath.toRelativeScale(3f, 0f), EPS);
        assertEquals(1f, ViewportMath.toRelativeScale(0f, 2f), EPS);
    }

    // ------------------------------------------------------------ current page

    @Test
    public void mostVisiblePage_picksLargestVisibleArea() {
        // Page 3 shows 100 px at the top, page 4 the remaining 900 px.
        int page = ViewportMath.mostVisiblePage(
                new int[] {3, 4},
                new float[] {-500f, 100f},
                new float[] {100f, 1600f},
                1000f,
                3);
        assertEquals(4, page);
    }

    @Test
    public void mostVisiblePage_tie_goesToEarlierPage() {
        int page = ViewportMath.mostVisiblePage(
                new int[] {0, 1},
                new float[] {-500f, 500f},
                new float[] {500f, 1500f},
                1000f,
                0);
        assertEquals(0, page);
    }

    @Test
    public void mostVisiblePage_nothingVisible_returnsFallback() {
        assertEquals(7, ViewportMath.mostVisiblePage(
                new int[0], new float[0], new float[0], 1000f, 7));
    }

    // ------------------------------------------------------------ match navigation

    @Test
    public void nextMatchIndex_wraps() {
        assertEquals(1, ViewportMath.nextMatchIndex(0, 3));
        assertEquals(0, ViewportMath.nextMatchIndex(2, 3));
        assertEquals(-1, ViewportMath.nextMatchIndex(0, 0));
    }

    @Test
    public void previousMatchIndex_wraps() {
        assertEquals(2, ViewportMath.previousMatchIndex(0, 3));
        assertEquals(0, ViewportMath.previousMatchIndex(1, 3));
        // No current match yet: previous starts from the end, like iOS.
        assertEquals(2, ViewportMath.previousMatchIndex(-1, 3));
        assertEquals(-1, ViewportMath.previousMatchIndex(0, 0));
    }

    // ------------------------------------------------------------ case-sensitive filter

    @Test
    public void matchesCaseSensitively_exactCase() {
        assertTrue(ViewportMath.matchesCaseSensitively("Hello World", 6, "World"));
        assertFalse(ViewportMath.matchesCaseSensitively("Hello world", 6, "World"));
    }

    @Test
    public void matchesCaseSensitively_failsOpenOnIndexMismatch() {
        assertTrue(ViewportMath.matchesCaseSensitively("short", 10, "World"));
        assertTrue(ViewportMath.matchesCaseSensitively(null, 0, "World"));
        assertTrue(ViewportMath.matchesCaseSensitively("abc", -1, "a"));
    }
}
