/// A Flutter plugin that renders PDF documents with the platform's native
/// viewer: PDFKit on iOS and AndroidPdfViewer on Android.
///
/// Add a [PDFView] to the widget tree with either a [PDFView.filePath] pointing
/// at a file on disk or the raw bytes in [PDFView.pdfData], then drive the
/// document from Dart through the [PDFViewController] handed to
/// [PDFView.onViewCreated]:
///
/// ```dart
/// PDFView(
///   filePath: path,
///   fitPolicy: FitPolicy.BOTH,
///   pageAlignment: PageAlignment.top, // optional; default centers short docs
///   onViewCreated: (PDFViewController controller) async {
///     final int? pages = await controller.getPageCount();
///     await controller.setPage(0);
///   },
/// )
/// ```
///
/// Importing `package:flutter_pdfview/flutter_pdfview.dart` exposes the entire
/// public API of the plugin; the libraries under `src/` are implementation
/// details and must not be imported directly.
///
/// The native views are reached through
/// `package:flutter_pdfview_platform_interface`. Apps do not need to depend on
/// it — only alternative platform implementations do.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart' show Theme;
import 'package:flutter/widgets.dart';
import 'package:flutter_pdfview_platform_interface/flutter_pdfview_platform_interface.dart';

// The public value types live in the platform interface so that every
// implementation shares them, but they stay part of this package's public API.
export 'package:flutter_pdfview_platform_interface/flutter_pdfview_platform_interface.dart'
    show
        DrawCallback,
        ErrorCallback,
        FitPolicy,
        LinkHandlerCallback,
        LoadCompleteCallback,
        PDFPasswordFailure,
        PageAlignment,
        PageChangedCallback,
        PageErrorCallback,
        PasswordRequiredCallback,
        PdfColorMode,
        PdfTextMatch,
        RenderCallback,
        SearchResultChangedCallback,
        TapCallback,
        TextSelectionChangedCallback;

part 'src/pdf_view.dart';
part 'src/pdf_view_controller.dart';
part 'src/pdf_view_settings.dart';
part 'src/types.dart';
