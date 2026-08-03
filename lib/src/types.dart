part of '../flutter_pdfview.dart';

// The `FitPolicy` values have been SCREAMING_CAPS since the first release of the
// plugin. Renaming them would break every existing user, so the naming lint is
// suppressed for this file instead.
// ignore_for_file: constant_identifier_names

/// Signature for the callback that is invoked once the native PDF view has been
/// created and its [PDFViewController] is ready to be used.
typedef PDFViewCreatedCallback = void Function(PDFViewController controller);

/// Signature for the callback that is invoked when the document has been
/// rendered, reporting the number of [pages] it contains.
typedef RenderCallback = void Function(int? pages);

/// Signature for the callback that is invoked when the visible page changes,
/// reporting the zero-based [page] index and the [total] number of pages.
typedef PageChangedCallback = void Function(int? page, int? total);

/// Signature for the callback that is invoked when the native viewer fails to
/// open a document, reporting the platform [error].
typedef ErrorCallback = void Function(dynamic error);

/// Signature for the callback that is invoked when a single page cannot be
/// rendered, reporting the zero-based [page] index and the platform [error].
typedef PageErrorCallback = void Function(int? page, dynamic error);

/// Signature for the callback that is invoked when a link inside the document is
/// tapped, reporting the target [uri].
///
/// Only called when [PDFView.preventLinkNavigation] is `true`.
typedef LinkHandlerCallback = void Function(String? uri);

/// Signature for the callback that is invoked once the document has finished
/// loading, reporting the number of [pages] it contains.
typedef LoadCompleteCallback = void Function(int? pages);

/// Signature for the callback that is invoked while the document is drawn,
/// reporting the current horizontal offset, vertical offset and zoom scale.
typedef DrawCallback = void Function(double pdfXOffset, double pdfYOffset, double pdfScale);

/// Determines how the pages of a document are scaled to fit the viewport.
enum FitPolicy {
  /// Scales each page so that its width fills the width of the viewport.
  WIDTH,

  /// Scales each page so that its height fills the height of the viewport.
  HEIGHT,

  /// Scales each page so that it fits entirely inside the viewport.
  BOTH,
}

/// How a document that is shorter than the viewport is placed inside it.
///
/// AndroidPdfViewer and PDFKit both center short documents by default. Use
/// [top] when free space should sit below the page (single-page PDFs, forms).
/// See [#250](https://github.com/endigo/flutter_pdfview/issues/250) and
/// [#272](https://github.com/endigo/flutter_pdfview/issues/272).
enum PageAlignment {
  /// Center the document in free space (historical default).
  center,

  /// Pin the document to the top of the viewport; free space is below.
  top,
}
