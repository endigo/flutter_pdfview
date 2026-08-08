import Flutter
import UIKit

/// Entry point registered by Flutter's generated plugin registrant.
///
/// The Objective-C name is pinned to `FLTPDFViewFlutterPlugin` because that is
/// the `pluginClass` declared in `pubspec.yaml`; `GeneratedPluginRegistrant`
/// looks the class up under exactly that name.
@objc(FLTPDFViewFlutterPlugin)
public final class PDFViewFlutterPlugin: NSObject, FlutterPlugin {
    public static func register(with registrar: FlutterPluginRegistrar) {
        let pdfViewFactory = PDFViewFactory(messenger: registrar.messenger())
        registrar.register(pdfViewFactory, withId: "plugins.endigo.io/pdfview")
    }
}
