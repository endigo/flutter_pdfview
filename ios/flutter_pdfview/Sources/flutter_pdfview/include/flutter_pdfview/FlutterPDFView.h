#import <Flutter/Flutter.h>
#import <PDFKit/PDFKit.h>

NS_ASSUME_NONNULL_BEGIN

API_AVAILABLE(ios(11.0))
@interface FLTPDFViewController : NSObject <FlutterPlatformView, PDFViewDelegate> 

- (instancetype)initWithFrame:(CGRect)frame
               viewIdentifier:(int64_t)viewId
                    arguments:(id _Nullable)args
              binaryMessenger:(NSObject<FlutterBinaryMessenger>*)messenger;
- (void)invokeChannelMethod:(NSString *)name arguments:(id)args;

- (UIView*)view;
@end

API_AVAILABLE(ios(11.0))
@interface FLTPDFView : UIView <FlutterPlatformView, PDFViewDelegate, UIGestureRecognizerDelegate, UIScrollViewDelegate>
- (instancetype)initWithFrame:(CGRect)frame
                    arguments:(id _Nullable)args
                    controller:(FLTPDFViewController*) controller;
- (void)layoutSubviews;
- (UIView*)view;
- (void)getPageCount:(FlutterMethodCall*)call result:(FlutterResult)result;
- (void)getCurrentPageSize:(FlutterMethodCall*)call result:(FlutterResult)result;
- (void)getPosition:(FlutterMethodCall*)call result:(FlutterResult)result;
- (void)getScale:(FlutterMethodCall*)call result:(FlutterResult)result;
- (void)setPosition:(FlutterMethodCall*)call result:(FlutterResult)result;
- (void)setScale:(FlutterMethodCall*)call result:(FlutterResult)result;
- (void)getCurrentPage:(FlutterMethodCall*)call result:(FlutterResult)result;
- (void)setPage:(FlutterMethodCall*)call result:(FlutterResult)result;
- (void)onUpdateSettings:(FlutterMethodCall*)call result:(FlutterResult)result;
- (void)setZoomLimits:(FlutterMethodCall*)call result:(FlutterResult)result;
- (void)reload:(FlutterMethodCall*)call result:(FlutterResult)result;
@end

API_AVAILABLE(ios(11.0))
@interface FLTPDFViewFactory : NSObject <FlutterPlatformViewFactory>
- (instancetype)initWithMessenger:(NSObject<FlutterBinaryMessenger>*)messenger;
@end

NS_ASSUME_NONNULL_END
