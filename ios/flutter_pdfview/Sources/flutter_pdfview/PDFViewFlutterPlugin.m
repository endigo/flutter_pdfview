#import "./include/flutter_pdfview/PDFViewFlutterPlugin.h"
#import "./include/flutter_pdfview/FlutterPDFView.h"

@implementation FLTPDFViewFlutterPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
    FLTPDFViewFactory* pdfViewFactory = [[FLTPDFViewFactory alloc] initWithMessenger:registrar.messenger];
    [registrar registerViewFactory:pdfViewFactory withId:@"plugins.endigo.io/pdfview"];
}
@end
