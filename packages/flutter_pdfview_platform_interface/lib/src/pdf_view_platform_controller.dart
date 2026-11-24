import 'dart:ui' show Offset, Size;

import 'pdf_view_callbacks.dart';
import 'types.dart';

/// Drives a single PDF view that a platform implementation has created.
///
/// One instance exists per created view. The app-facing `PDFViewController`
/// wraps an instance of this and is what users of the plugin actually hold.
abstract class PdfViewPlatformController {
  /// Returns the number of pages in the loaded document.
  Future<int?> getPageCount();

  /// Returns the zero-based index of the page that is currently displayed.
  Future<int?> getCurrentPage();

  /// Jumps to the zero-based [page] and returns whether the jump succeeded.
  ///
  /// When [withAnimation] is true, Android animates the scroll via
  /// `PDFView.jumpTo(page, withAnimation)`. iOS has no equivalent API and
  /// ignores the flag (instant jump either way). Defaults to `false`.
  Future<bool?> setPage(int page, {bool withAnimation = false});

  /// Returns the size, in points, of the page that is currently displayed.
  Future<Size> getCurrentPageSize();

  /// Returns the current scroll offset of the document.
  ///
  /// Implementations must let any pending [setPosition] call settle first, so
  /// the returned value reflects the latest requested position.
  Future<Offset> getPosition();

  /// Scrolls the document to [position] and returns whether the native view
  /// accepted the new offset.
  ///
  /// Implementations must serialize overlapping calls so platform order matches
  /// call order.
  Future<bool> setPosition(Offset position);

  /// Returns the current zoom scale of the document.
  ///
  /// Implementations must let any pending [setScale] call settle first.
  Future<double> getScale();

  /// Zooms the document to [scale] and returns whether the native view accepted
  /// the new scale.
  ///
  /// Implementations must serialize overlapping calls.
  Future<bool> setScale(double scale);

  /// Sets the minimum, middle and maximum zoom levels of the native view.
  Future<bool> setZoomLimits(double minZoom, double midZoom, double maxZoom);

  /// Captures the currently visible page and writes it to [fileName].
  ///
  /// Returns the path of the written image, or an empty string on failure.
  Future<String> getScreenshot(String fileName);

  /// Reopens the current document with [password] and returns whether it is now
  /// unlocked.
  Future<bool> unlock(String password);

  /// Reloads the current document and returns whether the reload succeeded.
  Future<bool> reload();

  /// Pushes the already-diffed [updates] to the native view.
  ///
  /// The map uses the same key names that `PdfViewSettings.toMap` produces.
  /// Implementations may assume it is non-empty.
  Future<void> updateSettings(Map<String, dynamic> updates);

  /// Whether this platform exposes a text layer at all.
  ///
  /// When `false`, every text method below throws [UnsupportedError] except
  /// [clearSearch] and [clearSelection], which stay no-ops because "clear
  /// nothing" is a truthful outcome.
  Future<bool> isTextLayerSupported();

  /// Searches the document for [query] and returns every match.
  ///
  /// The first match becomes the active one. An empty [query] clears the search
  /// and returns an empty list.
  ///
  /// An empty result always means "searched, found nothing". Implementations
  /// without a text layer must throw instead — see
  /// [kPdfTextLayerUnsupportedCode].
  Future<List<PdfTextMatch>> searchText(String query, {bool caseSensitive = false});

  /// Activates the next match, wrapping at the end.
  ///
  /// Returns `null` when there is no active search session.
  Future<PdfTextMatch?> nextMatch();

  /// Activates the previous match, wrapping at the start.
  ///
  /// Returns `null` when there is no active search session.
  Future<PdfTextMatch?> previousMatch();

  /// Activates the match at [index] of the last [searchText] result.
  ///
  /// Returns `null` when [index] is out of range.
  Future<PdfTextMatch?> setCurrentMatch(int index);

  /// Clears search highlights and forgets the last [searchText] result.
  Future<void> clearSearch();

  /// Returns the selected text, or `null` when nothing is selected.
  Future<String?> getSelectedText();

  /// Clears the current text selection, if any.
  Future<void> clearSelection();

  /// Replaces the callbacks this controller dispatches native events to.
  void updateCallbacks(PdfViewCallbacks callbacks);

  /// Detaches from the native view and stops delivering callbacks.
  ///
  /// Must be idempotent.
  void dispose();
}
