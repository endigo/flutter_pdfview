import 'dart:typed_data';

import 'pdf_view_settings.dart';

/// The parameters handed to a native PDF view when it is first created.
///
/// Exactly one document source is expected: [filePath], pointing at a file on
/// disk, or [pdfData], holding the raw bytes of the document.
class PdfViewCreationParams {
  /// Creates the creation parameters for a native PDF view.
  PdfViewCreationParams({this.filePath, this.pdfData, required this.settings});

  /// The path of the document to load from disk.
  final String? filePath;

  /// The binary data of a PDF document.
  final Uint8List? pdfData;

  /// The initial settings of the view.
  final PdfViewSettings settings;

  /// Serializes the document source and every setting into the wire format
  /// expected by the native view factories.
  Map<String, dynamic> toMap() {
    return <String, dynamic>{'filePath': filePath, 'pdfData': pdfData, ...settings.toMap()};
  }
}
