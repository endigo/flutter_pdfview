#import "PDFViewFlutterPlugin.h"
#import "FlutterPDFView.h"

@implementation FLTPDFViewFlutterPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
    FLTPDFViewFactory* pdfViewFactory = [[FLTPDFViewFactory alloc] initWithMessenger:registrar.messenger];
    [registrar registerViewFactory:pdfViewFactory withId:@"plugins.endigo.io/pdfview"];
}
@end
