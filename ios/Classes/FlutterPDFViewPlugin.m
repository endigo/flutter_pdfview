#import "FlutterPDFViewPlugin.h"
#import "FlutterPDFView.h"

@implementation FLTPDFViewPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
    FLTPDFViewFactory* pdfViewFactory = [[FLTPDFViewFactory alloc] initWithMessenger:registrar.messenger];
    [registrar registerViewFactory:pdfViewFactory withId:@"plugins.endigo.io/pdfview"];
}
@end
