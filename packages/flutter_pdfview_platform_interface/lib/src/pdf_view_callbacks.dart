import 'types.dart';

/// The callbacks a platform implementation invokes as the native viewer reports
/// events.
///
/// The app-facing package rebuilds this bundle whenever the owning widget
/// changes, so an implementation must always read the callbacks through the
/// instance it currently holds rather than capturing individual closures.
class PdfViewCallbacks {
  /// Creates a bundle of viewer event callbacks. Every entry is optional.
  const PdfViewCallbacks({
    this.onRender,
    this.onPageChanged,
    this.onError,
    this.onPageError,
    this.onPasswordRequired,
    this.onLinkHandler,
    this.onLoadComplete,
    this.onDraw,
    this.onTap,
    this.onTextSelectionChanged,
    this.onSearchResultChanged,
  });

  /// Invoked when the document has been rendered, with its page count.
  final RenderCallback? onRender;

  /// Invoked when the visible page changes.
  final PageChangedCallback? onPageChanged;

  /// Invoked on an error that was handled in native code.
  final ErrorCallback? onError;

  /// Invoked when a single page cannot be rendered.
  final PageErrorCallback? onPageError;

  /// Invoked when the document is encrypted and the supplied password, if any,
  /// did not open it.
  final PasswordRequiredCallback? onPasswordRequired;

  /// Invoked when a link is tapped and link navigation is prevented.
  final LinkHandlerCallback? onLinkHandler;

  /// Invoked once the document has finished loading, with its page count.
  final LoadCompleteCallback? onLoadComplete;

  /// Invoked while the document is drawn, with the current offsets and scale.
  final DrawCallback? onDraw;

  /// Invoked when the user single-taps the view.
  final TapCallback? onTap;

  /// Invoked when the user changes the text selection.
  final TextSelectionChangedCallback? onTextSelectionChanged;

  /// Invoked when the active search match changes.
  final SearchResultChangedCallback? onSearchResultChanged;
}
