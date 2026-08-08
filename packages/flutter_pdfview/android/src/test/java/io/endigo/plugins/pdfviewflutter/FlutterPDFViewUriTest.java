package io.endigo.plugins.pdfviewflutter;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertNull;
import static org.junit.Assert.assertSame;
import static org.junit.Assert.assertTrue;

import android.net.Uri;

import org.junit.Test;
import org.junit.runner.RunWith;
import org.robolectric.RobolectricTestRunner;
import org.robolectric.annotation.Config;

import java.io.File;

/**
 * Regression coverage for {@link FlutterPDFView#getURI(String)} — issue #266
 * ("No content provider" when a plain absolute filesystem path was handed to
 * ContentResolver instead of being turned into a {@code file://} URI).
 */
@RunWith(RobolectricTestRunner.class)
@Config(sdk = 35)
public class FlutterPDFViewUriTest {

    @Test
    public void absolutePath_becomesFileUri() {
        Uri uri = FlutterPDFView.getURI("/data/user/0/io.endigo.example/cache/sample.pdf");

        assertEquals("file", uri.getScheme());
        assertEquals("/data/user/0/io.endigo.example/cache/sample.pdf", uri.getPath());
        assertEquals("file:///data/user/0/io.endigo.example/cache/sample.pdf", uri.toString());
    }

    @Test
    public void absolutePathWithSpaces_isEncodedByFromFile() {
        Uri uri = FlutterPDFView.getURI("/data/user/0/app/cache/my file.pdf");

        assertEquals("file", uri.getScheme());
        // getPath() decodes, toString() keeps the percent-encoding. Uri.parse()
        // would have left the raw space in place, which is what broke #266.
        assertEquals("/data/user/0/app/cache/my file.pdf", uri.getPath());
        assertEquals("file:///data/user/0/app/cache/my%20file.pdf", uri.toString());
    }

    @Test
    public void fileUriWithAuthority_isParsedAsIs() {
        Uri uri = FlutterPDFView.getURI("file:///data/user/0/app/cache/sample.pdf");

        assertEquals("file", uri.getScheme());
        assertEquals("/data/user/0/app/cache/sample.pdf", uri.getPath());
        assertEquals("file:///data/user/0/app/cache/sample.pdf", uri.toString());
    }

    @Test
    public void fileUriWithSingleSlash_isParsedAsIs() {
        Uri uri = FlutterPDFView.getURI("file:/data/user/0/app/cache/sample.pdf");

        assertEquals("file", uri.getScheme());
        assertEquals("/data/user/0/app/cache/sample.pdf", uri.getPath());
        // Parsed verbatim — no extra slashes are introduced.
        assertEquals("file:/data/user/0/app/cache/sample.pdf", uri.toString());
    }

    @Test
    public void httpUrl_passesThroughUnchanged() {
        Uri uri = FlutterPDFView.getURI("http://example.com/docs/sample.pdf");

        assertEquals("http", uri.getScheme());
        assertEquals("example.com", uri.getHost());
        assertEquals("http://example.com/docs/sample.pdf", uri.toString());
    }

    @Test
    public void httpsUrlWithQuery_passesThroughUnchanged() {
        String input = "https://example.com/docs/sample.pdf?token=abc%20123";
        Uri uri = FlutterPDFView.getURI(input);

        assertEquals("https", uri.getScheme());
        assertEquals(input, uri.toString());
    }

    @Test
    public void contentUri_passesThroughUnchanged() {
        String input = "content://com.android.providers.downloads.documents/document/42";
        Uri uri = FlutterPDFView.getURI(input);

        assertEquals("content", uri.getScheme());
        assertEquals(input, uri.toString());
    }

    @Test
    public void nullString_returnsEmptyUri() {
        assertSame(Uri.EMPTY, FlutterPDFView.getURI(null));
    }

    @Test
    public void emptyString_returnsEmptyUri() {
        assertSame(Uri.EMPTY, FlutterPDFView.getURI(""));
    }

    @Test
    public void relativePath_isResolvedToAnAbsoluteFileUri() {
        Uri uri = FlutterPDFView.getURI("cache/sample.pdf");

        assertEquals("file", uri.getScheme());
        assertTrue("expected an absolute path, got " + uri.getPath(),
                uri.getPath().startsWith("/"));
        assertTrue("expected the relative part to be preserved, got " + uri.getPath(),
                uri.getPath().endsWith("cache/sample.pdf"));
        assertEquals(new File("cache/sample.pdf").getAbsolutePath(), uri.getPath());
    }

    @Test
    public void bareFileName_isResolvedToAnAbsoluteFileUri() {
        Uri uri = FlutterPDFView.getURI("sample.pdf");

        assertEquals("file", uri.getScheme());
        assertEquals(new File("sample.pdf").getAbsolutePath(), uri.getPath());
    }

    @Test
    public void emptyUriHasNoScheme() {
        // loadDocument() branches on a null scheme, so pin the contract Uri.EMPTY offers.
        assertNull(Uri.EMPTY.getScheme());
    }
}
