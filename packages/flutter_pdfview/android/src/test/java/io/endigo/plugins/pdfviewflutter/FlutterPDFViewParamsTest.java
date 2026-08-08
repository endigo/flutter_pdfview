package io.endigo.plugins.pdfviewflutter;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertNull;
import static org.junit.Assert.assertThrows;
import static org.junit.Assert.assertTrue;

import com.github.barteksc.pdfviewer.util.FitPolicy;

import org.junit.Test;

import java.util.HashMap;
import java.util.Map;

/**
 * Coverage for the creation-param getters on {@link FlutterPDFView}. These are
 * the single point where the loosely typed Dart creation params are coerced, so
 * missing / null / wrong-typed values all need pinned behaviour.
 */
public class FlutterPDFViewParamsTest {

    private static Map<String, Object> params(String key, Object value) {
        Map<String, Object> params = new HashMap<>();
        params.put(key, value);
        return params;
    }

    private static Map<String, Object> empty() {
        return new HashMap<>();
    }

    // ---------------------------------------------------------------- getBoolean

    @Test
    public void getBoolean_presentTrue() {
        assertTrue(FlutterPDFView.getBoolean(params("nightMode", true), "nightMode"));
    }

    @Test
    public void getBoolean_presentFalse() {
        assertFalse(FlutterPDFView.getBoolean(params("nightMode", false), "nightMode"));
    }

    @Test
    public void getBoolean_missingKey_isFalse() {
        assertFalse(FlutterPDFView.getBoolean(empty(), "nightMode"));
    }

    @Test
    public void getBoolean_nullValue_isFalse() {
        assertFalse(FlutterPDFView.getBoolean(params("nightMode", null), "nightMode"));
    }

    @Test
    public void getBoolean_wrongType_throwsClassCastException() {
        Map<String, Object> params = params("nightMode", "true");
        assertThrows(ClassCastException.class, () -> FlutterPDFView.getBoolean(params, "nightMode"));
    }

    // ----------------------------------------------------------------- getString

    @Test
    public void getString_presentValue() {
        assertEquals("hunter2", FlutterPDFView.getString(params("password", "hunter2"), "password"));
    }

    @Test
    public void getString_presentEmptyValue() {
        assertEquals("", FlutterPDFView.getString(params("password", ""), "password"));
    }

    @Test
    public void getString_missingKey_isEmptyString() {
        assertEquals("", FlutterPDFView.getString(empty(), "password"));
    }

    @Test
    public void getString_nullValue_isNull() {
        // containsKey() wins over the null, so an explicit null is passed through
        // rather than defaulted. Configurator.password(null) means "no password".
        assertNull(FlutterPDFView.getString(params("password", null), "password"));
    }

    @Test
    public void getString_wrongType_throwsClassCastException() {
        Map<String, Object> params = params("password", 42);
        assertThrows(ClassCastException.class, () -> FlutterPDFView.getString(params, "password"));
    }

    // -------------------------------------------------------------------- getInt

    @Test
    public void getInt_presentValue() {
        assertEquals(7, FlutterPDFView.getInt(params("defaultPage", 7), "defaultPage"));
    }

    @Test
    public void getInt_presentZero() {
        assertEquals(0, FlutterPDFView.getInt(params("defaultPage", 0), "defaultPage"));
    }

    @Test
    public void getInt_missingKey_isZero() {
        assertEquals(0, FlutterPDFView.getInt(empty(), "defaultPage"));
    }

    @Test
    public void getInt_nullValue_isZero() {
        assertEquals(0, FlutterPDFView.getInt(params("defaultPage", null), "defaultPage"));
    }

    @Test
    public void getInt_wrongType_throwsClassCastException() {
        Map<String, Object> params = params("defaultPage", 7L);
        assertThrows(ClassCastException.class, () -> FlutterPDFView.getInt(params, "defaultPage"));
    }

    // ------------------------------------------------------------------ getFloat

    @Test
    public void getFloat_presentDouble() {
        // Dart doubles arrive as java.lang.Double over the method channel.
        assertEquals(2.5f, FlutterPDFView.getFloat(params("maxZoom", 2.5d), "maxZoom", 4.0f), 0f);
    }

    @Test
    public void getFloat_presentInteger_isWidened() {
        assertEquals(3.0f, FlutterPDFView.getFloat(params("maxZoom", 3), "maxZoom", 4.0f), 0f);
    }

    @Test
    public void getFloat_presentFloat() {
        assertEquals(1.5f, FlutterPDFView.getFloat(params("minZoom", 1.5f), "minZoom", 1.0f), 0f);
    }

    @Test
    public void getFloat_missingKey_isDefault() {
        assertEquals(4.0f, FlutterPDFView.getFloat(empty(), "maxZoom", 4.0f), 0f);
    }

    @Test
    public void getFloat_nullValue_isDefault() {
        assertEquals(4.0f, FlutterPDFView.getFloat(params("maxZoom", null), "maxZoom", 4.0f), 0f);
    }

    @Test
    public void getFloat_wrongType_isDefaultRatherThanThrowing() {
        assertEquals(4.0f, FlutterPDFView.getFloat(params("maxZoom", "2.5"), "maxZoom", 4.0f), 0f);
    }

    // -------------------------------------------------------------- getFitPolicy

    @Test
    public void getFitPolicy_width() {
        assertEquals(FitPolicy.WIDTH,
                FlutterPDFView.getFitPolicy(params("fitPolicy", "FitPolicy.WIDTH")));
    }

    @Test
    public void getFitPolicy_height() {
        assertEquals(FitPolicy.HEIGHT,
                FlutterPDFView.getFitPolicy(params("fitPolicy", "FitPolicy.HEIGHT")));
    }

    @Test
    public void getFitPolicy_both() {
        assertEquals(FitPolicy.BOTH,
                FlutterPDFView.getFitPolicy(params("fitPolicy", "FitPolicy.BOTH")));
    }

    @Test
    public void getFitPolicy_unknownValue_fallsBackToBoth() {
        assertEquals(FitPolicy.BOTH,
                FlutterPDFView.getFitPolicy(params("fitPolicy", "FitPolicy.DIAGONAL")));
    }

    @Test
    public void getFitPolicy_wrongCase_fallsBackToBoth() {
        assertEquals(FitPolicy.BOTH,
                FlutterPDFView.getFitPolicy(params("fitPolicy", "fitpolicy.width")));
    }

    @Test
    public void getFitPolicy_missingKey_fallsBackToBoth() {
        assertEquals(FitPolicy.BOTH, FlutterPDFView.getFitPolicy(empty()));
    }

    // --------------------------------------------------------- getPageAlignment

    @Test
    public void getPageAlignment_top() {
        assertEquals(
                FlutterPDFView.PageAlignment.TOP,
                FlutterPDFView.getPageAlignment(params("pageAlignment", "PageAlignment.top")));
    }

    @Test
    public void getPageAlignment_center() {
        assertEquals(
                FlutterPDFView.PageAlignment.CENTER,
                FlutterPDFView.getPageAlignment(params("pageAlignment", "PageAlignment.center")));
    }

    @Test
    public void getPageAlignment_missingKey_defaultsToCenter() {
        assertEquals(
                FlutterPDFView.PageAlignment.CENTER,
                FlutterPDFView.getPageAlignment(empty()));
    }

    @Test
    public void getPageAlignment_unknownValue_defaultsToCenter() {
        assertEquals(
                FlutterPDFView.PageAlignment.CENTER,
                FlutterPDFView.getPageAlignment(params("pageAlignment", "PageAlignment.bottom")));
    }

    // ---------------------------------------------------------------- getIntOrNull / spacing (#335)

    @Test
    public void getIntOrNull_presentInt() {
        assertEquals(Integer.valueOf(12), FlutterPDFView.getIntOrNull(params("spacing", 12), "spacing"));
    }

    @Test
    public void getIntOrNull_missingKey_isNull() {
        assertNull(FlutterPDFView.getIntOrNull(empty(), "spacing"));
    }

    @Test
    public void getIntOrNull_nullValue_isNull() {
        Map<String, Object> params = new HashMap<>();
        params.put("spacing", null);
        assertNull(FlutterPDFView.getIntOrNull(params, "spacing"));
    }

    @Test
    public void resolveInterPageSpacingDp_autoSpacingOff_isZero() {
        assertEquals(0, FlutterPDFView.resolveInterPageSpacingDp(false, true, 20));
        assertEquals(0, FlutterPDFView.resolveInterPageSpacingDp(false, false, null));
    }

    @Test
    public void resolveInterPageSpacingDp_userOverrideWins() {
        assertEquals(16, FlutterPDFView.resolveInterPageSpacingDp(true, false, 16));
        assertEquals(0, FlutterPDFView.resolveInterPageSpacingDp(true, true, 0));
    }

    @Test
    public void resolveInterPageSpacingDp_topAlignDefault_isEight() {
        assertEquals(8, FlutterPDFView.resolveInterPageSpacingDp(true, true, null));
    }

    @Test
    public void resolveInterPageSpacingDp_centerDefault_isZero() {
        assertEquals(0, FlutterPDFView.resolveInterPageSpacingDp(true, false, null));
    }

    /**
     * #197: secondary-axis centering math used after setPage / jumpTo.
     * When the page strip is narrower than the viewport the offset is positive
     * (centered); when wider it is negative (moveTo clamps).
     */
    @Test
    public void centerSecondaryOffset_pageNarrowerThanViewport_isPositive() {
        assertEquals(50f, FlutterPDFView.centerSecondaryOffset(200f, 100f), 0.001f);
    }

    @Test
    public void centerSecondaryOffset_pageEqualsViewport_isZero() {
        assertEquals(0f, FlutterPDFView.centerSecondaryOffset(200f, 200f), 0.001f);
    }

    @Test
    public void centerSecondaryOffset_pageWiderThanViewport_isNegative() {
        assertEquals(-50f, FlutterPDFView.centerSecondaryOffset(200f, 300f), 0.001f);
    }

    // ---------------------------------------------------- issue #150 independence

    /**
     * #150: autoSpacing and fitPolicy must be readable from the same creation
     * map without one key forcing or clearing the other. Spacing is only
     * page gaps; fit is pageFitPolicy.
     */
    @Test
    public void issue150_autoSpacingFalse_withFitPolicyBoth() {
        Map<String, Object> params = new HashMap<>();
        params.put("autoSpacing", false);
        params.put("fitPolicy", "FitPolicy.BOTH");
        params.put("enableSwipe", true);
        params.put("swipeHorizontal", false);

        assertFalse(FlutterPDFView.getBoolean(params, "autoSpacing"));
        assertEquals(FitPolicy.BOTH, FlutterPDFView.getFitPolicy(params));
        assertTrue(FlutterPDFView.getBoolean(params, "enableSwipe"));
        assertFalse(FlutterPDFView.getBoolean(params, "swipeHorizontal"));
    }

    @Test
    public void issue150_autoSpacingAndFitPolicy_allCombinationsIndependent() {
        String[] policies = {
            "FitPolicy.WIDTH", "FitPolicy.HEIGHT", "FitPolicy.BOTH"
        };
        FitPolicy[] expected = {
            FitPolicy.WIDTH, FitPolicy.HEIGHT, FitPolicy.BOTH
        };
        for (boolean autoSpacing : new boolean[] {true, false}) {
            for (int i = 0; i < policies.length; i++) {
                Map<String, Object> params = new HashMap<>();
                params.put("autoSpacing", autoSpacing);
                params.put("fitPolicy", policies[i]);
                assertEquals(
                        "autoSpacing=" + autoSpacing + " policy=" + policies[i],
                        autoSpacing,
                        FlutterPDFView.getBoolean(params, "autoSpacing"));
                assertEquals(
                        "autoSpacing=" + autoSpacing + " policy=" + policies[i],
                        expected[i],
                        FlutterPDFView.getFitPolicy(params));
            }
        }
    }
}
