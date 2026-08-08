part of '../flutter_pdfview.dart';

/// Signature for the callback that is invoked once the native PDF view has been
/// created and its [PDFViewController] is ready to be used.
///
/// Every other callback signature, along with [FitPolicy], [PageAlignment],
/// [PdfColorMode] and [PDFPasswordFailure], is defined in
/// `package:flutter_pdfview_platform_interface` and re-exported by this library.
/// This one stays here because it hands back a [PDFViewController], which is
/// part of the app-facing API rather than the platform interface.
typedef PDFViewCreatedCallback = void Function(PDFViewController controller);
