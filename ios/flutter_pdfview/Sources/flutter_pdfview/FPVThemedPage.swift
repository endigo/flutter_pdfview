import CoreImage
import CoreImage.CIFilterBuiltins
import PDFKit
import UIKit

// MARK: - Color mode

/// How page content is themed. Mirrors Dart's `PdfColorMode`.
enum FPVColorMode {
    case light
    case dark
    /// Follow the app's theme. Dart resolves this before it reaches the native
    /// side; it is only handled here so a caller that sends it verbatim gets the
    /// system appearance rather than an unconditional light page.
    case system
}

// MARK: - The color transform

/// The luminance-inverting color matrix shared with the Android implementation.
///
/// ```
///  0.333  -0.667  -0.667   bias +1
/// -0.667   0.333  -0.667   bias +1
/// -0.667  -0.667   0.333   bias +1
/// ```
///
/// It inverts lightness while preserving hue: white→black, black→white, but a
/// saturated red (1, 0, 0) becomes (1, 0.333, 0.333) — still red — where a naive
/// `1 - v` inversion would flip it to cyan and turn photos into negatives.
///
/// The matrix is an involution (`M(M(v)) == v`), which is what lets Android
/// compensate its inverted gutter with the same matrix. iOS transforms only page
/// content, so the gutter is set to the requested color directly.
///
/// Kept as a constant rather than inlined so a future sepia / soft-dark mode is a
/// new constant instead of an API change.
enum FPVColorMatrix {
    private static let diagonal: CGFloat = 0.333
    private static let offDiagonal: CGFloat = -0.667

    static let luminanceInvertR = CIVector(x: diagonal, y: offDiagonal, z: offDiagonal, w: 0)
    static let luminanceInvertG = CIVector(x: offDiagonal, y: diagonal, z: offDiagonal, w: 0)
    static let luminanceInvertB = CIVector(x: offDiagonal, y: offDiagonal, z: diagonal, w: 0)
    /// Alpha passes through untouched.
    static let luminanceInvertA = CIVector(x: 0, y: 0, z: 0, w: 1)
    static let luminanceInvertBias = CIVector(x: 1, y: 1, z: 1, w: 0)
}

// MARK: - Themed page

/// A `PDFPage` that renders itself through ``FPVColorMatrix`` in dark mode.
///
/// `FlutterPDFView` installs this class **unconditionally** through
/// `PDFDocumentDelegate.classForPage()`, in every color mode: the mode is read at
/// draw time, so flipping it never requires re-instantiating pages. In light mode
/// this is exactly `super.draw`.
///
/// The mode is read through the document's delegate rather than a static or a
/// per-page flag — iterating the document to push a flag onto every page would
/// instantiate every page of a large document.
final class FPVThemedPage: PDFPage {
    /// Ceiling on the offscreen bitmap for a single draw call (16 Mpx ≈ 64 MB).
    ///
    /// `PDFView` tiles zoomed pages, so a tile is normally at most a few
    /// screenfuls; anything above this is pathological and renders untransformed
    /// rather than risking the allocation.
    private static let maxOffscreenPixels = 16 * 1024 * 1024

    /// Shared because `CIContext` creation is expensive and it is thread-safe —
    /// PDFKit renders pages off the main thread.
    private static let ciContext: CIContext = {
        // Apply the matrix to sRGB-encoded values, which is what the coefficients
        // were authored against and what Android's ColorMatrixColorFilter does.
        // CoreImage would otherwise convert to its linear working space first and
        // produce a different (and no longer involutive) result.
        let space = CGColorSpaceCreateDeviceRGB()
        return CIContext(options: [
            .workingColorSpace: space,
            .outputColorSpace: space,
            .cacheIntermediates: false,
        ])
    }()

    override func draw(with box: PDFDisplayBox, to context: CGContext) {
        guard let owner = document?.delegate as? FlutterPDFView, owner.isDarkMode else {
            super.draw(with: box, to: context)
            return
        }

        var didDrawThemed = false
        catchingNSException {
            didDrawThemed = drawInverted(with: box, to: context)
        } onException: { error in
            NSLog("Warning: Dark-mode page render failed: %@", error.pdfExceptionReason)
            didDrawThemed = false
        }

        if !didDrawThemed {
            // Nothing has been written to `context` yet on any failure path, so
            // the plain render is still safe to run.
            super.draw(with: box, to: context)
        }
    }

    /// Renders `super.draw` into an offscreen bitmap, runs the color matrix over
    /// it and draws the result into `context`.
    ///
    /// - Returns: `true` when the themed image was drawn, `false` when the caller
    ///   should fall back to a plain `super.draw`.
    private func drawInverted(with box: PDFDisplayBox, to context: CGContext) -> Bool {
        // Size to the clip, not to the page: `PDFView` tiles large or zoomed pages
        // and calls this once per tile, so a page-sized offscreen would scale with
        // the zoom factor.
        let clipRect = context.boundingBoxOfClipPath
        guard clipRect.width > 0, clipRect.height > 0 else { return false }

        // The CTM maps user space to the destination's backing store, so it
        // already carries the zoom and the screen scale.
        let ctm = context.ctm
        guard (ctm.a * ctm.d - ctm.b * ctm.c) != 0 else { return false }

        let deviceRect = clipRect.applying(ctm).integral
        let width = Int(deviceRect.width)
        let height = Int(deviceRect.height)
        guard width > 0, height > 0, width * height <= Self.maxOffscreenPixels else {
            return false
        }

        guard let offscreen = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
                | CGBitmapInfo.byteOrder32Little.rawValue
        ) else { return false }

        // `PDFPage.draw` does not clear its background — `PDFView.drawPage` erases
        // to white before calling it. Without the prefill the page margins would
        // stay transparent black and the matrix would render them white.
        offscreen.setFillColor(UIColor.white.cgColor)
        offscreen.fill(CGRect(x: 0, y: 0, width: width, height: height))

        // Reproduce the destination's user→device mapping, shifted so the tile's
        // device origin lands on the offscreen's origin.
        offscreen.translateBy(x: -deviceRect.origin.x, y: -deviceRect.origin.y)
        offscreen.concatenate(ctm)
        super.draw(with: box, to: offscreen)

        guard let rendered = offscreen.makeImage(),
              let inverted = Self.applyLuminanceInversion(to: rendered)
        else { return false }

        context.saveGState()
        // The tile was rasterised in device space, so undo the CTM and blit it
        // back 1:1 instead of re-deriving the rect in user space.
        context.concatenate(ctm.inverted())
        context.interpolationQuality = .none
        context.draw(inverted, in: deviceRect)
        context.restoreGState()
        return true
    }

    private static func applyLuminanceInversion(to image: CGImage) -> CGImage? {
        let filter = CIFilter.colorMatrix()
        filter.inputImage = CIImage(cgImage: image)
        filter.rVector = FPVColorMatrix.luminanceInvertR
        filter.gVector = FPVColorMatrix.luminanceInvertG
        filter.bVector = FPVColorMatrix.luminanceInvertB
        filter.aVector = FPVColorMatrix.luminanceInvertA
        filter.biasVector = FPVColorMatrix.luminanceInvertBias
        guard let output = filter.outputImage else { return nil }
        return ciContext.createCGImage(output, from: output.extent)
    }
}
