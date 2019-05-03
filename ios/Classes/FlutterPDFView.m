// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
#import "FlutterPDFView.h"

@implementation FLTPDFViewFactory {
    NSObject<FlutterBinaryMessenger>* _messenger;
}

- (instancetype)initWithMessenger:(NSObject<FlutterBinaryMessenger>*)messenger {
    self = [super init];
    if (self) {
        _messenger = messenger;
    }
    return self;
}

- (NSObject<FlutterMessageCodec>*)createArgsCodec {
    return [FlutterStandardMessageCodec sharedInstance];
}

- (NSObject<FlutterPlatformView>*)createWithFrame:(CGRect)frame
                                   viewIdentifier:(int64_t)viewId
                                        arguments:(id _Nullable)args {
    FLTPDFViewController* pdfviewController = [[FLTPDFViewController alloc] initWithFrame:frame
                                                                           viewIdentifier:viewId
                                                                                arguments:args
                                                                          binaryMessenger:_messenger];
    return pdfviewController;
}

@end

@implementation FLTPDFViewController {
    PDFView* _pdfView;
    int64_t _viewId;
    FlutterMethodChannel* _channel;
    NSString* _currentUrl;
}

- (instancetype)initWithFrame:(CGRect)frame
               viewIdentifier:(int64_t)viewId
                    arguments:(id _Nullable)args
              binaryMessenger:(NSObject<FlutterBinaryMessenger>*)messenger {
    if ([super init]) {
        _viewId = viewId;
        
        NSString* channelName = [NSString stringWithFormat:@"plugins.endigo.io/pdfview_%lld", viewId];
        _channel = [FlutterMethodChannel methodChannelWithName:channelName binaryMessenger:messenger];
        
        _pdfView = [[PDFView alloc] initWithFrame:frame];
        
        __weak __typeof__(self) weakSelf = self;
        [_channel setMethodCallHandler:^(FlutterMethodCall* call, FlutterResult result) {
            [weakSelf onMethodCall:call result:result];
        }];
//        NSDictionary<NSString*, id>* settings = args[@"settings"];
        
        NSString* filePath = args[@"filePath"];
        if ([filePath isKindOfClass:[NSString class]]) {
            NSURL * sourcePDFUrl = [NSURL fileURLWithPath:filePath];
            PDFDocument * document = [[PDFDocument alloc] initWithURL: sourcePDFUrl];
            
            _pdfView.document = document;
            _pdfView.displayMode = kPDFDisplaySinglePageContinuous;
//            _pdfView.displayDirection = kPDFDisplayDirectionHorizontal;
            _pdfView.displayDirection = kPDFDisplayDirectionVertical;
            _pdfView.backgroundColor = UIColor.whiteColor;
            [_pdfView usePageViewController:YES withViewOptions:nil];
        }
    }
    return self;
}

- (UIView*)view {
    return _pdfView;
}

- (void)onMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
    if ([[call method] isEqualToString:@"updateSettings"]) {
//        [self onUpdateSettings:call result:result];
    } else {
        result(FlutterMethodNotImplemented);
    }
}

@end
