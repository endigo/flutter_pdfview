package com.example.pdfiumfork;

/**
 * Stand-in for a fork of PdfiumAndroid that ships the password failure under its
 * own package, pinning the name-based fallback in isPasswordError.
 */
public class PdfPasswordException extends RuntimeException {
    public PdfPasswordException(String message) {
        super(message);
    }
}
