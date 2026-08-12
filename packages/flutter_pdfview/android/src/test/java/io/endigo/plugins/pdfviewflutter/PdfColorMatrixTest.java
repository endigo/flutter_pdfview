package io.endigo.plugins.pdfviewflutter;

import static org.junit.Assert.assertArrayEquals;
import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertTrue;

import org.junit.Test;

/**
 * Plain JUnit tests for {@link PdfColorMatrix} (no Android framework / Robolectric).
 */
public class PdfColorMatrixTest {

    private static final float[] M = PdfColorMatrix.LUMINANCE_INVERT;

    @Test
    public void luminanceInvert_hasExpectedLayout() {
        assertEquals(20, M.length);
        // Row 0 linear coeffs ≈ 1/3, -2/3, -2/3 and bias 255
        assertEquals(1f / 3f, M[0], 1e-6f);
        assertEquals(-2f / 3f, M[1], 1e-6f);
        assertEquals(-2f / 3f, M[2], 1e-6f);
        assertEquals(0f, M[3], 0f);
        assertEquals(255f, M[4], 0f);
        // Alpha row is identity
        assertArrayEquals(
                new float[]{0f, 0f, 0f, 1f, 0f},
                new float[]{M[15], M[16], M[17], M[18], M[19]},
                0f
        );
    }

    @Test
    public void white_becomesBlack() {
        assertEquals(0xFF000000, PdfColorMatrix.transformColor(0xFFFFFFFF, M));
    }

    @Test
    public void black_becomesWhite() {
        assertEquals(0xFFFFFFFF, PdfColorMatrix.transformColor(0xFF000000, M));
    }

    @Test
    public void midGrey_isInvolution() {
        assertInvolution(0xFF808080);
    }

    @Test
    public void nearWhite_becomesNearBlack() {
        // Example Material surface (0xFEF7FF): may clip slightly so exact
        // involution is not required; it must still land in the dark range.
        int out = PdfColorMatrix.transformColor(0xFFFEF7FF, M);
        int r = (out >> 16) & 0xFF;
        int g = (out >> 8) & 0xFF;
        int b = out & 0xFF;
        assertTrue("expected dark result, got r=" + r + " g=" + g + " b=" + b,
                r < 32 && g < 32 && b < 32);
    }

    @Test
    public void nearBlack_isInvolution() {
        // Low-saturation greys (and near-blacks) stay in range → exact involution.
        assertInvolution(0xFF121212);
    }

    @Test
    public void realisticGutter_surfaceGrey_isInvolution() {
        // Non-saturated gutters recover exactly under M∘M.
        assertInvolution(0xFFF5F5F5);
        assertInvolution(0xFFE8E8E8);
        assertInvolution(0xFF1C1B1F);
    }

    @Test
    public void red_staysReddish_notCyan() {
        // Luminance invert of pure red stays in the red family (R dominant),
        // unlike a naive channel invert which yields cyan.
        int out = PdfColorMatrix.transformColor(0xFFFF0000, M);
        int r = (out >> 16) & 0xFF;
        int g = (out >> 8) & 0xFF;
        int b = out & 0xFF;
        assertTrue("R should dominate after luminance invert of red, got r=" + r + " g=" + g + " b=" + b,
                r > g && r > b);
        assertTrue("G and B channels should match for pure red input", g == b);
    }

    @Test
    public void doubleApplication_recoversGreys() {
        // Greys lie on the eigenspace where involution is exact (no clipping).
        int[] greys = {
                0xFF000000, 0xFF111111, 0xFF404040, 0xFF808080,
                0xFFC0C0C0, 0xFFEEEEEE, 0xFFFFFFFF
        };
        for (int c : greys) {
            assertInvolution(c);
        }
    }

    @Test
    public void defaultMatrix_overload_usesLuminanceInvert() {
        assertEquals(
                PdfColorMatrix.transformColor(0xFF808080, M),
                PdfColorMatrix.transformColor(0xFF808080)
        );
    }

    private static void assertInvolution(int argb) {
        int once = PdfColorMatrix.transformColor(argb, M);
        int twice = PdfColorMatrix.transformColor(once, M);
        assertEquals(
                String.format("M(M(0x%08X)) should recover original, got 0x%08X via 0x%08X",
                        argb, twice, once),
                argb,
                twice
        );
    }
}
