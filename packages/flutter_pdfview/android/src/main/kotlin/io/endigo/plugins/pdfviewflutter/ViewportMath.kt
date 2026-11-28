package io.endigo.plugins.pdfviewflutter

/** Mirrors Dart `FitPolicy`. */
enum class FitPolicy {
    WIDTH,
    HEIGHT,
    BOTH,
}

/**
 * Pure geometry shared by the androidx.pdf engine, kept free of Android types
 * so it can be unit-tested on the JVM.
 *
 * androidx.pdf's `PdfView.zoom` is absolute: 1 means one screen pixel per PDF
 * point. The Dart API (and AndroidPdfViewer before it) uses a *relative* scale,
 * where 1 is "page fitted to the view per [FitPolicy]". These helpers convert
 * between the two so `getScale` / `setScale` / `minZoom` / `maxZoom` keep their
 * meaning across engines.
 */
object ViewportMath {

    /**
     * The absolute `PdfView.zoom` at which the widest (or tallest) page fits
     * the view, or 0 when the view or the document has not been measured yet.
     */
    @JvmStatic
    fun fitZoom(
        policy: FitPolicy,
        viewWidth: Int,
        viewHeight: Int,
        maxPageWidth: Float,
        maxPageHeight: Float,
    ): Float {
        if (viewWidth <= 0 || viewHeight <= 0 || maxPageWidth <= 0f || maxPageHeight <= 0f) {
            return 0f
        }
        val byWidth = viewWidth / maxPageWidth
        val byHeight = viewHeight / maxPageHeight
        return when (policy) {
            FitPolicy.WIDTH -> byWidth
            FitPolicy.HEIGHT -> byHeight
            FitPolicy.BOTH -> minOf(byWidth, byHeight)
        }
    }

    /** Dart-facing relative scale for an absolute [viewZoom]; 1 before the first fit. */
    @JvmStatic
    fun toRelativeScale(viewZoom: Float, fitZoom: Float): Float =
        if (fitZoom > 0f && viewZoom > 0f) viewZoom / fitZoom else 1f

    /** Absolute `PdfView.zoom` for a Dart-facing relative [scale]. */
    @JvmStatic
    fun toViewZoom(scale: Float, fitZoom: Float): Float = scale * fitZoom

    /**
     * The page that occupies the most of a viewport of [viewportHeight]
     * pixels, given each visible page's on-screen [tops] and [bottoms]. Ties go
     * to the earlier page; returns [fallback] when nothing is visible.
     */
    @JvmStatic
    fun mostVisiblePage(
        pages: IntArray,
        tops: FloatArray,
        bottoms: FloatArray,
        viewportHeight: Float,
        fallback: Int,
    ): Int {
        var best = fallback
        var bestVisible = 0f
        for (i in pages.indices) {
            val visible = minOf(bottoms[i], viewportHeight) - maxOf(tops[i], 0f)
            if (visible > bestVisible) {
                bestVisible = visible
                best = pages[i]
            }
        }
        return best
    }

    /** Index after [current] in a list of [count] matches, wrapping around. */
    @JvmStatic
    fun nextMatchIndex(current: Int, count: Int): Int =
        if (count <= 0) -1 else (current + 1).mod(count)

    /** Index before [current] in a list of [count] matches, wrapping around. */
    @JvmStatic
    fun previousMatchIndex(current: Int, count: Int): Int =
        if (count <= 0) -1 else if (current <= 0) count - 1 else current - 1

    /**
     * Whether a case-insensitive hit of [query] starting at [start] in
     * [pageText] also matches case-sensitively. Fails open (returns true) when
     * [start] does not land inside [pageText], so an index mismatch between the
     * search and the extracted text never hides a real match.
     */
    @JvmStatic
    fun matchesCaseSensitively(pageText: String?, start: Int, query: String): Boolean {
        if (pageText == null || start < 0 || start + query.length > pageText.length) {
            return true
        }
        return pageText.regionMatches(start, query, 0, query.length, ignoreCase = false)
    }
}
