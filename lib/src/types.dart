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

/// Color theme for PDF page content and the gutter behind it.
///
/// - [light]: normal rendering (no inversion).
/// - [dark]: luminance-preserving inversion (white↔black, hue kept).
/// - [system]: follows the app [Theme] brightness (or platform brightness when
///   no [Theme] ancestor is present). Resolved in Dart before the value is
///   sent to the native view.
enum PdfColorMode {
  /// Normal light rendering.
  light,

  /// Dark theme via luminance-preserving color inversion.
  dark,

  /// Follow the ambient app theme / platform brightness.
  system,
}
