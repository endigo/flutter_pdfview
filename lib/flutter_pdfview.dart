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
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

part 'src/pdf_view.dart';
part 'src/pdf_view_controller.dart';
part 'src/pdf_view_settings.dart';
part 'src/types.dart';
