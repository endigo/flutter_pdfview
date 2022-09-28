// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

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
@interface FLTPDFView : UIView <FlutterPlatformView, PDFViewDelegate>
- (instancetype)initWithFrame:(CGRect)frame
                    arguments:(id _Nullable)args
                    controler:(FLTPDFViewController*)controler;
- (void)layoutSubviews;
- (UIView*)view;
- (void)getPageCount:(FlutterMethodCall*)call result:(FlutterResult)result;
- (void)getCurrentPage:(FlutterMethodCall*)call result:(FlutterResult)result;
- (void)setPage:(FlutterMethodCall*)call result:(FlutterResult)result;
- (void)onUpdateSettings:(FlutterMethodCall*)call result:(FlutterResult)result;
@end

API_AVAILABLE(ios(11.0))
@interface FLTPDFViewFactory : NSObject <FlutterPlatformViewFactory>
- (instancetype)initWithMessenger:(NSObject<FlutterBinaryMessenger>*)messenger;
@end

NS_ASSUME_NONNULL_END
