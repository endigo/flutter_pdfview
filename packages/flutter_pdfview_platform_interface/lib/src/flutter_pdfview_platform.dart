import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'method_channel/method_channel_flutter_pdfview.dart';
import 'pdf_view_callbacks.dart';
import 'pdf_view_creation_params.dart';
import 'pdf_view_platform_controller.dart';

/// The interface every platform implementation of `flutter_pdfview` implements.
///
/// Implementations should extend this class rather than implement it, so that
/// new members do not break them. Extending also inherits the
/// [PlatformInterface] token verification.
abstract class FlutterPdfViewPlatform extends PlatformInterface {
  /// Constructs a [FlutterPdfViewPlatform].
  FlutterPdfViewPlatform() : super(token: _token);

  static final Object _token = Object();

  static FlutterPdfViewPlatform _instance = MethodChannelFlutterPdfView();

  /// The default instance to use.
  ///
  /// Defaults to [MethodChannelFlutterPdfView], which talks to the Android and
  /// iOS implementations bundled with the app-facing package.
  static FlutterPdfViewPlatform get instance => _instance;

  /// Sets the instance used by the app-facing package.
  ///
  /// Platform implementations should set this in their `registerWith` method.
  static set instance(FlutterPdfViewPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// Builds the widget that hosts the native PDF view.
  ///
  /// [onPlatformViewCreated] is invoked with the controller for the created view.
  /// It may be invoked after the widget has been removed from the tree — the
  /// app-facing package guards against that and disposes the stale controller.
  ///
  /// Implementations that do not support the current platform should return a
  /// widget explaining that rather than throwing.
  Widget buildView({
    Key? key,
    required PdfViewCreationParams creationParams,
    required PdfViewCallbacks callbacks,
    required void Function(PdfViewPlatformController controller) onPlatformViewCreated,
    Set<Factory<OneSequenceGestureRecognizer>>? gestureRecognizers,
    TextDirection layoutDirection = TextDirection.ltr,
  }) {
    throw UnimplementedError('buildView() has not been implemented.');
  }
}
