/// The common platform interface for the `flutter_pdfview` plugin.
///
/// Platform implementations should extend [FlutterPdfViewPlatform] and register
/// themselves by assigning to [FlutterPdfViewPlatform.instance]. App authors
/// should depend on `package:flutter_pdfview/flutter_pdfview.dart` instead of
/// this package.
library;

export 'src/flutter_pdfview_platform.dart';
export 'src/method_channel/method_channel_flutter_pdfview.dart';
export 'src/method_channel/method_channel_pdf_view_controller.dart';
export 'src/pdf_view_callbacks.dart';
export 'src/pdf_view_creation_params.dart';
export 'src/pdf_view_platform_controller.dart';
export 'src/pdf_view_settings.dart';
export 'src/types.dart';
