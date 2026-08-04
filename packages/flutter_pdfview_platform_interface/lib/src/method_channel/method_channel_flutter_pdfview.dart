import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../flutter_pdfview_platform.dart';
import '../pdf_view_callbacks.dart';
import '../pdf_view_creation_params.dart';
import '../pdf_view_platform_controller.dart';
import 'method_channel_pdf_view_controller.dart';

/// The view type registered by the native plugins on both platforms.
const String kPdfViewType = 'plugins.endigo.io/pdfview';

/// The default [FlutterPdfViewPlatform], backed by method channels.
///
/// It embeds the Android and iOS views bundled with the app-facing package. On
/// any other platform [buildView] returns an explanatory [Text] instead of a
/// platform view.
class MethodChannelFlutterPdfView extends FlutterPdfViewPlatform {
  @override
  Widget buildView({
    Key? key,
    required PdfViewCreationParams creationParams,
    required PdfViewCallbacks callbacks,
    required void Function(PdfViewPlatformController controller) onPlatformViewCreated,
    Set<Factory<OneSequenceGestureRecognizer>>? gestureRecognizers,
    TextDirection layoutDirection = TextDirection.ltr,
  }) {
    final Map<String, dynamic> params = creationParams.toMap();

    void handleCreated(int id) {
      onPlatformViewCreated(MethodChannelPdfViewController(id, callbacks));
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      return PlatformViewLink(
        key: key,
        viewType: kPdfViewType,
        surfaceFactory: (BuildContext context, PlatformViewController controller) {
          return AndroidViewSurface(
            controller: controller as AndroidViewController,
            gestureRecognizers:
                gestureRecognizers ?? const <Factory<OneSequenceGestureRecognizer>>{},
            hitTestBehavior: PlatformViewHitTestBehavior.opaque,
          );
        },
        onCreatePlatformView: (PlatformViewCreationParams viewParams) {
          // True hybrid composition embeds the real android.view.View instead of
          // mirroring via SurfaceTexture. Texture mode (initSurfaceAndroidView)
          // crashes under load ("Surface was already locked!", EGL_NO_DISPLAY)
          // and blanks/glitches on rotation, dialogs, and some GPUs
          // (#9, #182, #263, #280, #298, #306).
          return PlatformViewsService.initExpensiveAndroidView(
              id: viewParams.id,
              viewType: kPdfViewType,
              layoutDirection: layoutDirection,
              creationParams: params,
              creationParamsCodec: const StandardMessageCodec(),
            )
            ..addOnPlatformViewCreatedListener(viewParams.onPlatformViewCreated)
            ..addOnPlatformViewCreatedListener(handleCreated)
            ..create();
        },
      );
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      return UiKitView(
        key: key,
        viewType: kPdfViewType,
        onPlatformViewCreated: handleCreated,
        gestureRecognizers: gestureRecognizers,
        creationParams: params,
        creationParamsCodec: const StandardMessageCodec(),
      );
    }
    return Text('$defaultTargetPlatform is not yet supported by the pdfview_flutter plugin');
  }
}
