// The `FitPolicy` values have been SCREAMING_CAPS since the first release of the
// plugin. Renaming them would break every existing user, so the naming lint is
// suppressed for this file instead.
// ignore_for_file: constant_identifier_names

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

/// Why an encrypted document could not be opened.
enum PDFPasswordFailure {
  /// The document is encrypted and no password was supplied.
  missing,

  /// A password was supplied but it did not open the document.
  incorrect,
}

/// Signature for the callback that is invoked when an encrypted document could
/// not be opened, reporting why in [failure].
typedef PasswordRequiredCallback = void Function(PDFPasswordFailure failure);

/// Signature for the callback that is invoked when a link inside the document is
/// tapped, reporting the target [uri].
///
/// Only called when link navigation is prevented.
typedef LinkHandlerCallback = void Function(String? uri);

/// Signature for the callback that is invoked once the document has finished
/// loading, reporting the number of [pages] it contains.
typedef LoadCompleteCallback = void Function(int? pages);

/// Signature for the callback that is invoked while the document is drawn,
/// reporting the current horizontal offset, vertical offset and zoom scale.
typedef DrawCallback = void Function(double pdfXOffset, double pdfYOffset, double pdfScale);

/// Signature for the callback that is invoked when the user single-taps the
/// PDF view.
///
/// Flutter platform-view gesture arenas often fail to deliver `onTap` for
/// embedded native views
/// ([#133](https://github.com/endigo/flutter_pdfview/issues/133)), so the tap is
/// detected natively and reported through this callback instead.
typedef TapCallback = void Function();

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

/// One occurrence of a search string inside a PDF document.
///
/// Returned by the text-search methods on [PdfViewPlatformController]. See
/// [kPdfTextLayerUnsupportedCode] for how platforms without a text layer report
/// that they cannot search at all — an empty match list always means "searched,
/// found nothing", never "not supported here".
class PdfTextMatch {
  /// Creates a match description.
  const PdfTextMatch({required this.pageIndex, required this.matchIndex, this.text});

  /// Builds a match from its method-channel representation.
  factory PdfTextMatch.fromMap(Map<Object?, Object?> map) {
    return PdfTextMatch(
      pageIndex: (map['pageIndex'] as num?)?.toInt() ?? 0,
      matchIndex: (map['matchIndex'] as num?)?.toInt() ?? 0,
      text: map['text'] as String?,
    );
  }

  /// Zero-based page that contains this match.
  final int pageIndex;

  /// Zero-based index of this match in the full search result list.
  final int matchIndex;

  /// Matched string as reported by the platform, when available.
  final String? text;

  /// Serializes this match into its method-channel representation.
  Map<String, Object?> toMap() => <String, Object?>{
    'pageIndex': pageIndex,
    'matchIndex': matchIndex,
    'text': text,
  };

  @override
  bool operator ==(Object other) =>
      other is PdfTextMatch &&
      other.pageIndex == pageIndex &&
      other.matchIndex == matchIndex &&
      other.text == text;

  @override
  int get hashCode => Object.hash(pageIndex, matchIndex, text);

  @override
  String toString() => 'PdfTextMatch(pageIndex: $pageIndex, matchIndex: $matchIndex, text: $text)';
}

/// The `PlatformException.code` a platform implementation must use when it has
/// no text layer at all.
///
/// Implementations must fail this way rather than returning an empty result:
/// an empty list has to keep meaning "searched, found nothing", otherwise an app
/// on a platform without text support silently reads as "this document contains
/// no matches". [MethodChannelPdfViewController] translates this code into an
/// [UnsupportedError].
const String kPdfTextLayerUnsupportedCode = 'text_layer_unsupported';

/// Signature for the callback that is invoked when the user changes the text
/// selection in the PDF view.
///
/// [selectedText] is the selected string, or `null` when the selection is
/// cleared.
typedef TextSelectionChangedCallback = void Function(String? selectedText);

/// Signature for the callback that is invoked when the active search match
/// changes.
///
/// [currentIndex] is the zero-based index of the active match, or `-1` when
/// there is no active match. [total] is the number of matches.
typedef SearchResultChangedCallback = void Function(int currentIndex, int total);

/// Color theme for PDF page content and the gutter behind it.
///
/// - [light]: normal rendering (no inversion).
/// - [dark]: luminance-preserving inversion (white↔black, hue kept).
/// - [system]: follows the ambient app theme brightness. Resolved to [light] or
///   [dark] by the app-facing package before it reaches a platform
///   implementation, so implementations never observe this value.
enum PdfColorMode {
  /// Normal light rendering.
  light,

  /// Dark theme via luminance-preserving color inversion.
  dark,

  /// Follow the ambient app theme / platform brightness.
  system,
}
