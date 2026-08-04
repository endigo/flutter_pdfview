package io.endigo.plugins.pdfviewflutter

/**
 * Shared 4×5 color-matrix constants for PDF color modes.
 *
 * No Android framework imports — plain JUnit can exercise the math without
 * Robolectric. Matrices use the Android [ColorMatrix] layout (RGB in 0–255,
 * fifth column is additive bias).
 *
 * Luminance invert preserves hue while swapping light/dark: white↔black, but
 * red (255,0,0) stays reddish rather than becoming cyan. Algebraically
 * `A = I − (2/3)J` with bias +255; linear part has eigenvalues −1 on the grey
 * axis and +1 on the zero-sum plane, so **M is an involution** (`M(M(v)) == v`)
 * wherever the intermediate stays in range. Saturated extremes can clip
 * (worst case ~#00FFFF); realistic gutter colors are safe.
 *
 * Store the matrix (`FloatArray?`, null = light) rather than a boolean so a
 * future sepia/soft-dark mode is a new constant, not an API change.
 */
object PdfColorMatrix {

    private const val ONE_THIRD = 1f / 3f
    private const val NEG_TWO_THIRDS = -2f / 3f

    /**
     * Luminance-preserving invert (dark mode). 20 floats, row-major 4×5.
     *
     * ```
     *  1/3  -2/3  -2/3  0  255
     * -2/3   1/3  -2/3  0  255
     * -2/3  -2/3   1/3  0  255
     *  0     0     0    1    0
     * ```
     */
    @JvmField
    val LUMINANCE_INVERT: FloatArray = floatArrayOf(
        ONE_THIRD, NEG_TWO_THIRDS, NEG_TWO_THIRDS, 0f, 255f,
        NEG_TWO_THIRDS, ONE_THIRD, NEG_TWO_THIRDS, 0f, 255f,
        NEG_TWO_THIRDS, NEG_TWO_THIRDS, ONE_THIRD, 0f, 255f,
        0f, 0f, 0f, 1f, 0f
    )

    /**
     * Apply a 4×5 color matrix to an ARGB packed color (components 0–255).
     * Result channels are clamped to [0, 255].
     */
    @JvmStatic
    @JvmOverloads
    fun transformColor(argb: Int, matrix: FloatArray = LUMINANCE_INVERT): Int {
        val a = ((argb ushr 24) and 0xFF).toFloat()
        val r = ((argb ushr 16) and 0xFF).toFloat()
        val g = ((argb ushr 8) and 0xFF).toFloat()
        val b = (argb and 0xFF).toFloat()

        val rOut = clamp255(
            matrix[0] * r + matrix[1] * g + matrix[2] * b + matrix[3] * a + matrix[4]
        )
        val gOut = clamp255(
            matrix[5] * r + matrix[6] * g + matrix[7] * b + matrix[8] * a + matrix[9]
        )
        val bOut = clamp255(
            matrix[10] * r + matrix[11] * g + matrix[12] * b + matrix[13] * a + matrix[14]
        )
        val aOut = clamp255(
            matrix[15] * r + matrix[16] * g + matrix[17] * b + matrix[18] * a + matrix[19]
        )

        return (aOut shl 24) or (rOut shl 16) or (gOut shl 8) or bOut
    }

    private fun clamp255(value: Float): Int {
        return when {
            value <= 0f -> 0
            value >= 255f -> 255
            else -> (value + 0.5f).toInt()
        }
    }
}
