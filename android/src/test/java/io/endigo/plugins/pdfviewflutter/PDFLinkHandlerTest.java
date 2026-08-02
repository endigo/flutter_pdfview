package io.endigo.plugins.pdfviewflutter;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertNotNull;
import static org.junit.Assert.assertNull;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.isNull;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

import android.app.Application;
import android.content.ActivityNotFoundException;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.graphics.RectF;
import android.net.Uri;
import android.os.Bundle;

import com.github.barteksc.pdfviewer.PDFView;
import com.github.barteksc.pdfviewer.model.LinkTapEvent;
import com.shockwave.pdfium.PdfDocument;

import org.junit.Before;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.mockito.ArgumentCaptor;
import org.robolectric.RobolectricTestRunner;
import org.robolectric.RuntimeEnvironment;
import org.robolectric.Shadows;
import org.robolectric.annotation.Config;
import org.robolectric.shadows.ShadowApplication;

import io.flutter.plugin.common.MethodChannel;

@RunWith(RobolectricTestRunner.class)
@Config(sdk = 35)
public class PDFLinkHandlerTest {

    private static final String LINK = "https://example.com/docs/sample.pdf";

    private Application application;
    private PDFView pdfView;
    private MethodChannel methodChannel;

    @Before
    public void setUp() {
        application = RuntimeEnvironment.getApplication();
        pdfView = mock(PDFView.class);
        methodChannel = mock(MethodChannel.class);
    }

    private ShadowApplication shadowApplication() {
        return Shadows.shadowOf(application);
    }

    private PDFLinkHandler handler(boolean preventLinkNavigation) {
        return new PDFLinkHandler(application, pdfView, methodChannel, preventLinkNavigation);
    }

    private static LinkTapEvent linkEvent(String uri, Integer destPageIdx) {
        PdfDocument.Link link = new PdfDocument.Link(new RectF(0, 0, 10, 10), destPageIdx, uri);
        return new LinkTapEvent(0f, 0f, 0f, 0f, new RectF(0, 0, 10, 10), link);
    }

    // ------------------------------------------------- preventLinkNavigation = true

    @Test
    public void preventNavigation_doesNotStartAnActivity() {
        handler(true).handleUri(LINK);

        assertNull("no activity should be started when navigation is prevented",
                shadowApplication().getNextStartedActivity());
    }

    @Test
    public void preventNavigation_stillNotifiesFlutter() {
        handler(true).handleUri(LINK);

        verify(methodChannel).invokeMethod("onLinkHandler", LINK);
    }

    @Test
    public void preventNavigation_doesNotTouchThePdfView() {
        handler(true).handleUri(LINK);

        verifyNoInteractions(pdfView);
    }

    // ------------------------------------------------ preventLinkNavigation = false

    @Test
    public void allowNavigation_firesActionViewIntent() {
        handler(false).handleUri(LINK);

        Intent started = shadowApplication().getNextStartedActivity();
        assertNotNull("an ACTION_VIEW intent should have been fired", started);
        assertEquals(Intent.ACTION_VIEW, started.getAction());
        assertEquals(Uri.parse(LINK), started.getData());
        assertEquals("FLAG_ACTIVITY_NEW_TASK is required to launch from a non-activity context",
                Intent.FLAG_ACTIVITY_NEW_TASK,
                started.getFlags() & Intent.FLAG_ACTIVITY_NEW_TASK);
    }

    @Test
    public void allowNavigation_alsoNotifiesFlutter() {
        handler(false).handleUri(LINK);

        verify(methodChannel).invokeMethod("onLinkHandler", LINK);
    }

    @Test
    public void allowNavigation_startsOnlyOneActivity() {
        handler(false).handleUri(LINK);

        assertNotNull(shadowApplication().getNextStartedActivity());
        assertNull(shadowApplication().getNextStartedActivity());
    }

    /**
     * Android 11+ package visibility makes {@code resolveActivity()} return null
     * unless the host app declares a {@code <queries>} entry, which silently broke
     * every external link. The handler must fire the intent regardless and only
     * catch the failure.
     */
    @Test
    public void allowNavigation_doesNotPreCheckWithResolveActivity() {
        Context context = mock(Context.class);
        PackageManager packageManager = mock(PackageManager.class);
        when(context.getPackageManager()).thenReturn(packageManager);
        when(packageManager.resolveActivity(any(Intent.class), anyInt())).thenReturn(null);

        new PDFLinkHandler(context, pdfView, methodChannel, false).handleUri(LINK);

        ArgumentCaptor<Intent> intent = ArgumentCaptor.forClass(Intent.class);
        verify(context).startActivity(intent.capture(), isNull());
        assertEquals(Intent.ACTION_VIEW, intent.getValue().getAction());
        assertEquals(Uri.parse(LINK), intent.getValue().getData());
        verify(methodChannel).invokeMethod("onLinkHandler", LINK);
    }

    @Test
    public void allowNavigation_swallowsActivityNotFoundAndStillNotifiesFlutter() {
        Context context = mock(Context.class);
        doThrow(new ActivityNotFoundException("no handler"))
                .when(context).startActivity(any(Intent.class), any());

        new PDFLinkHandler(context, pdfView, methodChannel, false).handleUri("mailto:nobody@example.com");

        verify(methodChannel).invokeMethod("onLinkHandler", "mailto:nobody@example.com");
    }

    @Test
    public void setPreventLinkNavigation_togglesBehaviourAtRuntime() {
        PDFLinkHandler handler = handler(false);
        handler.setPreventLinkNavigation(true);
        handler.handleUri(LINK);
        assertNull(shadowApplication().getNextStartedActivity());

        handler.setPreventLinkNavigation(false);
        handler.handleUri(LINK);
        assertNotNull(shadowApplication().getNextStartedActivity());

        verify(methodChannel, org.mockito.Mockito.times(2)).invokeMethod("onLinkHandler", LINK);
    }

    // ------------------------------------------------------------- event routing

    @Test
    public void linkEventWithUri_isRoutedToUriHandling() {
        handler(false).handleLinkEvent(linkEvent(LINK, null));

        assertNotNull(shadowApplication().getNextStartedActivity());
        verify(methodChannel).invokeMethod("onLinkHandler", LINK);
        verify(pdfView, never()).jumpTo(anyInt());
    }

    @Test
    public void linkEventWithUriAndDestPage_prefersTheUri() {
        handler(true).handleLinkEvent(linkEvent(LINK, 3));

        verify(methodChannel).invokeMethod("onLinkHandler", LINK);
        verify(pdfView, never()).jumpTo(anyInt());
    }

    @Test
    public void linkEventWithNullUriAndDestPage_jumpsToPage() {
        handler(false).handleLinkEvent(linkEvent(null, 4));

        verify(pdfView).jumpTo(4);
        verify(methodChannel, never()).invokeMethod(anyString(), any());
        assertNull(shadowApplication().getNextStartedActivity());
    }

    @Test
    public void linkEventWithEmptyUriAndDestPage_jumpsToPage() {
        handler(false).handleLinkEvent(linkEvent("", 0));

        verify(pdfView).jumpTo(0);
        verify(methodChannel, never()).invokeMethod(anyString(), any());
    }

    @Test
    public void linkEventWithNeitherUriNorDestPage_isANoOp() {
        handler(false).handleLinkEvent(linkEvent(null, null));

        verifyNoInteractions(pdfView);
        verifyNoInteractions(methodChannel);
        assertNull(shadowApplication().getNextStartedActivity());
    }

    @Test
    public void handlePage_delegatesToPdfView() {
        handler(false).handlePage(7);

        verify(pdfView).jumpTo(7);
    }

    /**
     * The two-arg {@code startActivity(Intent, Bundle)} overload is used with null
     * options; pinned so a future switch to the one-arg overload is a deliberate change.
     */
    @Test
    public void allowNavigation_passesNullActivityOptions() {
        Context context = mock(Context.class);

        new PDFLinkHandler(context, pdfView, methodChannel, false).handleUri(LINK);

        verify(context).startActivity(any(Intent.class), (Bundle) isNull());
    }
}
