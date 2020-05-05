import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../platform_interface.dart';
import 'pdfview_method_channel.dart';

/// Builds an Android webview.
///
/// This is used as the default implementation for [PDFView.platform] on Android. It uses
/// an [AndroidView] to embed the webview in the widget hierarchy, and uses a method channel to
/// communicate with the platform code.
class AndroidWebView implements PDFViewPlatform {
  @override
  Widget build({
    BuildContext context,
    CreationParams creationParams,
    @required PDFViewPlatformCallbacksHandler pdfViewPlatformCallbacksHandler,
    PDFViewPlatformCreatedCallback onPDFViewPlatformCreated,
    Set<Factory<OneSequenceGestureRecognizer>> gestureRecognizers,
  }) {
    assert(pdfViewPlatformCallbacksHandler != null);
    return GestureDetector(
      // We prevent text selection by intercepting the long press event.
      // This is a temporary stop gap due to issues with text selection on Android:
      // https://github.com/flutter/flutter/issues/24585 - the text selection
      // dialog is not responding to touch events.
      // https://github.com/flutter/flutter/issues/24584 - the text selection
      // handles are not showing.
      // TODO(amirh): remove this when the issues above are fixed.
      onLongPress: () {},
      excludeFromSemantics: true,
      child: AndroidView(
        viewType: 'plugins.endigo.io/pdfview',
        onPlatformViewCreated: (int id) {
          if (onPDFViewPlatformCreated == null) {
            return;
          }
          onPDFViewPlatformCreated(MethodChannelPDFViewPlatform(
              id, pdfViewPlatformCallbacksHandler));
        },
        gestureRecognizers: gestureRecognizers,
        // WebView content is not affected by the Android view's layout direction,
        // we explicitly set it here so that the widget doesn't require an ambient
        // directionality.
        layoutDirection: TextDirection.rtl,
        creationParams:
            MethodChannelPDFViewPlatform.creationParamsToMap(creationParams),
        creationParamsCodec: const StandardMessageCodec(),
      ),
    );
  }
}
