package io.endigo.plugins.pdfviewflutter;

import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

import com.shockwave.pdfium.PdfPasswordException;

import org.junit.Test;

import java.io.IOException;

/**
 * Coverage for the detection behind {@code onPasswordRequired}. Pdfium reports a
 * bad password as a plain {@link Throwable} on the AndroidPdfViewer error
 * callback, so telling it apart from every other load failure is what decides
 * whether Flutter is asked to prompt the user.
 */
public class FlutterPDFViewPasswordTest {

    @Test
    public void detectsThePdfiumException() {
        assertTrue(FlutterPDFView.isPasswordError(new PdfPasswordException("Password required")));
    }

    @Test
    public void detectsAWrappedPdfiumException() {
        Throwable wrapped = new RuntimeException("open failed", new PdfPasswordException("nope"));
        assertTrue(FlutterPDFView.isPasswordError(wrapped));
    }

    @Test
    public void detectsADeeplyWrappedPdfiumException() {
        Throwable cause = new PdfPasswordException("nope");
        for (int i = 0; i < 5; i++) {
            cause = new IOException("layer " + i, cause);
        }
        assertTrue(FlutterPDFView.isPasswordError(cause));
    }

    @Test
    public void detectsARepackagedExceptionByName() {
        // Forks of PdfiumAndroid ship the same failure under their own package.
        assertTrue(
                FlutterPDFView.isPasswordError(
                        new com.example.pdfiumfork.PdfPasswordException("Password required")));
    }

    @Test
    public void ignoresAnUnrelatedFailure() {
        assertFalse(FlutterPDFView.isPasswordError(new IOException("File not found")));
    }

    @Test
    public void ignoresAnUnrelatedFailureChain() {
        Throwable wrapped = new RuntimeException("open failed", new IOException("corrupted"));
        assertFalse(FlutterPDFView.isPasswordError(wrapped));
    }

    @Test
    public void ignoresNull() {
        assertFalse(FlutterPDFView.isPasswordError(null));
    }

    @Test
    public void ignoresAnExceptionThatOnlyMentionsAPasswordInItsMessage() {
        // The message is not part of the contract; only the exception type is.
        assertFalse(FlutterPDFView.isPasswordError(new IOException("wrong password")));
    }

    @Test
    public void terminatesOnASelfReferentialCause() {
        SelfCausingException loop = new SelfCausingException();
        assertFalse(FlutterPDFView.isPasswordError(loop));
    }

    @Test
    public void terminatesOnACyclicCauseChain() {
        MutableCauseException first = new MutableCauseException();
        MutableCauseException second = new MutableCauseException();
        first.setNext(second);
        second.setNext(first);
        assertFalse(FlutterPDFView.isPasswordError(first));
    }

    @Test
    public void givesUpOnACauseChainDeeperThanTheBound() {
        // A password failure buried below the depth bound is reported as a plain
        // error rather than costing an unbounded walk.
        Throwable cause = new PdfPasswordException("nope");
        for (int i = 0; i < 20; i++) {
            cause = new IOException("layer " + i, cause);
        }
        assertFalse(FlutterPDFView.isPasswordError(cause));
    }

    private static final class SelfCausingException extends RuntimeException {
        @Override
        public synchronized Throwable getCause() {
            return this;
        }
    }

    private static final class MutableCauseException extends RuntimeException {
        private Throwable next;

        private void setNext(Throwable next) {
            this.next = next;
        }

        @Override
        public synchronized Throwable getCause() {
            return next;
        }
    }
}
