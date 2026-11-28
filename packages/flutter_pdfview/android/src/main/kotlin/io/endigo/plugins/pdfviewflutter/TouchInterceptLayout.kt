package io.endigo.plugins.pdfviewflutter

import android.annotation.SuppressLint
import android.content.Context
import android.view.MotionEvent
import android.widget.FrameLayout

/**
 * Hosts the `PdfView` and sees every touch before it does.
 *
 * `PdfView` has no tap callback and no switch for scrolling, and an
 * `OnTouchListener` on it misses events its internal children consume. Taking
 * them here, in [dispatchTouchEvent], is the one place that observes them all.
 */
@SuppressLint("ViewConstructor")
class TouchInterceptLayout(context: Context) : FrameLayout(context) {

    /** Sees each event first; return true to keep it from the `PdfView`. */
    var interceptor: ((MotionEvent) -> Boolean)? = null

    override fun dispatchTouchEvent(event: MotionEvent): Boolean {
        if (interceptor?.invoke(event) == true) {
            return true
        }
        return super.dispatchTouchEvent(event)
    }
}
