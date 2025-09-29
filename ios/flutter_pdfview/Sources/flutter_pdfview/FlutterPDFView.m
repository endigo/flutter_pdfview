// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
#import "./include/flutter_pdfview/FlutterPDFView.h"

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
    FLTPDFView* _pdfView;
    int64_t _viewId;
    FlutterMethodChannel* _channel;
}

- (instancetype)initWithFrame:(CGRect)frame
               viewIdentifier:(int64_t)viewId
                    arguments:(id _Nullable)args
              binaryMessenger:(NSObject<FlutterBinaryMessenger>*)messenger {
    self = [super init];
    _pdfView = [[FLTPDFView new] initWithFrame:frame arguments:args controller:self];
    _viewId = viewId;

    @try  {
        NSNumber* nightMode = args[@"nightMode"];
        NSNumber* nightModeBackgroundColor = args[@"nightModeBackgroundColor"];
        NSNumber* backgroundColor = args[@"backgroundColor"];
        UIColor* convertedColor = nil;
        if ([nightMode boolValue] && [nightModeBackgroundColor isKindOfClass:[NSNumber class]]) {
            convertedColor = [self colorFromARGB:[nightModeBackgroundColor unsignedIntValue]];
        } else if ([backgroundColor isKindOfClass:[NSNumber class]]) {
            convertedColor = [self colorFromARGB:[backgroundColor unsignedIntValue]];
        }
        if (convertedColor) {
            _pdfView.view.backgroundColor = convertedColor;
        }
    } @catch (NSException *exception) {
        NSLog(@"Exception while setting background color: %@", exception);
    }
// Helper function to convert ARGB integer to UIColor
- (UIColor*)colorFromARGB:(unsigned int)argb {
    CGFloat a = ((argb & 0xFF000000) >> 24) / 255.0;
    CGFloat r = ((argb & 0x00FF0000) >> 16) / 255.0;
    CGFloat g = ((argb & 0x0000FF00) >> 8) / 255.0;
    CGFloat b = (argb & 0x000000FF) / 255.0;
    return [UIColor colorWithRed:r green:g blue:b alpha:a];
}

    NSString* channelName = [NSString stringWithFormat:@"plugins.endigo.io/pdfview_%lld", viewId];
    _channel = [FlutterMethodChannel methodChannelWithName:channelName binaryMessenger:messenger];
    __weak __typeof__(self) weakSelf = self;
    [_channel setMethodCallHandler:^(FlutterMethodCall* call, FlutterResult result) {
        [weakSelf onMethodCall:call result:result];
    }];

    return self;
}

- (void)onMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
    if ([[call method] isEqualToString:@"pageCount"]) {
        [_pdfView getPageCount:call result:result];
    } else if ([[call method] isEqualToString:@"currentPage"]) {
        [_pdfView getCurrentPage:call result:result];
    } else if ([[call method] isEqualToString:@"setPage"]) {
        [_pdfView setPage:call result:result];
    } else if ([[call method] isEqualToString:@"updateSettings"]) {
        [_pdfView onUpdateSettings:call result:result];
    } else {
        result(FlutterMethodNotImplemented);
    }
}

- (void)invokeChannelMethod:(NSString *)name arguments:(id)args {
    [_channel invokeMethod:name arguments:args];
}

- (UIView*)view {
    return _pdfView;
}

@end

@implementation FLTPDFView {
    FLTPDFViewController* __weak _controller;
    PDFView* _pdfView;
    NSNumber* _pageCount;
    NSNumber* _currentPage;
    PDFDestination* _currentDestination;
    BOOL _preventLinkNavigation;
    BOOL _autoSpacing;
    PDFPage* _defaultPage;
    BOOL _defaultPageSet;
    BOOL _isIPad;
    BOOL _isScrolling;
}

- (instancetype)initWithFrame:(CGRect)frame
                    arguments:(id _Nullable)args
                    controller:(nonnull FLTPDFViewController *)controller {
    _controller = controller;

    // Detect if device is iPad
    _isIPad = (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad);
    _isScrolling = NO;

    _pdfView = [[PDFView alloc] initWithFrame: frame];
    _pdfView.delegate = self;

    _autoSpacing = [args[@"autoSpacing"] boolValue];
    BOOL pageFling = [args[@"pageFling"] boolValue];
    BOOL enableSwipe = [args[@"enableSwipe"] boolValue];
    _preventLinkNavigation = [args[@"preventLinkNavigation"] boolValue];

    NSInteger defaultPage = [args[@"defaultPage"] integerValue];

    NSString* filePath = args[@"filePath"];
    FlutterStandardTypedData* pdfData = args[@"pdfData"];

    PDFDocument* document;
    if ([filePath isKindOfClass:[NSString class]]) {
        NSURL* sourcePDFUrl = [NSURL fileURLWithPath:filePath];
        document = [[PDFDocument alloc] initWithURL: sourcePDFUrl];
    } else if ([pdfData isKindOfClass:[FlutterStandardTypedData class]]) {
        NSData* sourcePDFdata = [pdfData data];
        document = [[PDFDocument alloc] initWithData: sourcePDFdata];
    }


    if (document == nil) {
        [_controller invokeChannelMethod:@"onError" arguments:@{@"error" : @"cannot create document: File not in PDF format or corrupted."}];
    } else {
        _pdfView.autoresizesSubviews = YES;
        _pdfView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        
        BOOL swipeHorizontal = [args[@"swipeHorizontal"] boolValue];
        if (swipeHorizontal) {
            _pdfView.displayDirection = kPDFDisplayDirectionHorizontal;
        } else {
            _pdfView.displayDirection = kPDFDisplayDirectionVertical;
        }

        _pdfView.autoScales = _autoSpacing;

        // On iPad, avoid conflicting display modes with page view controller
        if (_isIPad && pageFling && enableSwipe) {
            // For iPad with both pageFling and enableSwipe, prefer page-based navigation
            [_pdfView usePageViewController:YES withViewOptions:nil];
            _pdfView.displayMode = kPDFDisplaySinglePage;
        } else {
            [_pdfView usePageViewController:pageFling withViewOptions:nil];
            _pdfView.displayMode = enableSwipe ? kPDFDisplaySinglePageContinuous : kPDFDisplaySinglePage;
        }
        _pdfView.document = document;

        _pdfView.maxScaleFactor = [args[@"maxZoom"] doubleValue];
        _pdfView.minScaleFactor = _pdfView.scaleFactorForSizeToFit;

        NSString* password = args[@"password"];
        if ([password isKindOfClass:[NSString class]] && [_pdfView.document isEncrypted]) {
            [_pdfView.document unlockWithPassword:password];
        }

        UITapGestureRecognizer *tapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onDoubleTap:)];
        tapGestureRecognizer.numberOfTapsRequired = 2;
        tapGestureRecognizer.numberOfTouchesRequired = 1;
        tapGestureRecognizer.delegate = self;
        tapGestureRecognizer.delaysTouchesBegan = NO;
        tapGestureRecognizer.delaysTouchesEnded = NO;
        [_pdfView addGestureRecognizer:tapGestureRecognizer];

        NSUInteger pageCount = [document pageCount];

        if (pageCount <= defaultPage) {
            defaultPage = pageCount - 1;
        }

        _defaultPage = [document pageAtIndex: defaultPage];
        __weak __typeof__(self) weakSelf = self;
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf handleRenderCompleted:[NSNumber numberWithUnsignedLong: [document pageCount]]];
        });
    }

    // Configure scroll view with defensive handling for iPad
    if (@available(iOS 11.0, *)) {
        // Delay scroll view configuration to avoid conflicts during initialization
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            @try {
                UIScrollView *scrollView = nil;

                for (id subview in self->_pdfView.subviews) {
                    if ([subview isKindOfClass: [UIScrollView class]]) {
                        scrollView = subview;
                        break;
                    }
                }

                if (scrollView != nil) {
                    // On iPad, use more conservative scroll configuration
                    if (self->_isIPad) {
                        // Allow system to manage insets on iPad for better compatibility
                        scrollView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentAutomatic;

                        // Set delegate to monitor scroll events
                        if ([scrollView.delegate isEqual:nil]) {
                            scrollView.delegate = (id<UIScrollViewDelegate>)self;
                        }
                    } else {
                        // iPhone keeps existing behavior
                        scrollView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
                        if (@available(iOS 13.0, *)) {
                            scrollView.automaticallyAdjustsScrollIndicatorInsets = NO;
                        }
                    }

                    // Ensure scroll view recognizes gestures properly
                    scrollView.delaysContentTouches = YES;
                    scrollView.canCancelContentTouches = YES;
                }
            } @catch (NSException *exception) {
                NSLog(@"Warning: Failed to configure PDF scroll view: %@", exception.reason);
            }
        });
    }

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handlePageChanged:) name:PDFViewPageChangedNotification object:_pdfView];
    [self addSubview:_pdfView];
        
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];

    // Skip layout updates during scrolling to prevent conflicts
    if (_isScrolling) {
        return;
    }

    // Wrap layout updates in try-catch for safety
    @try {
        _pdfView.frame = self.frame;
        _pdfView.minScaleFactor = _pdfView.scaleFactorForSizeToFit;
        _pdfView.maxScaleFactor = 4.0;
        if (_autoSpacing) {
            _pdfView.scaleFactor = _pdfView.scaleFactorForSizeToFit;
        }

        if (!_defaultPageSet && _defaultPage != nil) {
            [_pdfView goToPage: _defaultPage];
            _defaultPageSet = true;
        }
    } @catch (NSException *exception) {
        NSLog(@"Warning: Layout update failed: %@", exception.reason);
    }
}

- (UIView*)view {
    return _pdfView;
}


- (void)getPageCount:(FlutterMethodCall*)call result:(FlutterResult)result {
    _pageCount = [NSNumber numberWithUnsignedLong: [[_pdfView document] pageCount]];
    result(_pageCount);
}

- (void)getCurrentPage:(FlutterMethodCall*)call result:(FlutterResult)result {
    _currentPage = [NSNumber numberWithUnsignedLong: [_pdfView.document indexForPage: _pdfView.currentPage]];
    result(_currentPage);
}

- (void)setPage:(FlutterMethodCall*)call result:(FlutterResult)result {
    NSDictionary<NSString*, NSNumber*>* arguments = [call arguments];
    NSNumber* page = arguments[@"page"];
    
    [_pdfView goToPage: [_pdfView.document pageAtIndex: page.unsignedLongValue ]];
    result([NSNumber numberWithBool: YES]);
}

- (void)onUpdateSettings:(FlutterMethodCall*)call result:(FlutterResult)result {
    result(nil);
}

-(void)handlePageChanged:(NSNotification*)notification {
    [_controller invokeChannelMethod:@"onPageChanged" arguments:@{@"page" : [NSNumber numberWithUnsignedLong: [_pdfView.document indexForPage: _pdfView.currentPage]], @"total" : [NSNumber numberWithUnsignedLong: [_pdfView.document pageCount]]}];
}

-(void)handleRenderCompleted: (NSNumber*)pages {
    [_controller invokeChannelMethod:@"onRender" arguments:@{@"pages" : pages}];
}

- (void)PDFViewWillClickOnLink:(PDFView *)sender
                       withURL:(NSURL *)url{
    if (!_preventLinkNavigation){
        NSDictionary *options = @{};
        [[UIApplication sharedApplication] openURL:url options:options completionHandler:^(BOOL success) {
            if (success) {
                NSLog(@"URL opened successfully");
            } else {
                NSLog(@"Failed to open URL");
            }
        } ];
    }
    [_controller invokeChannelMethod:@"onLinkHandler" arguments:url.absoluteString];
}

- (void) onDoubleTap: (UITapGestureRecognizer *)recognizer {
    if (recognizer.state == UIGestureRecognizerStateEnded) {
        // Prevent zooming during scrolling
        if (_isScrolling) {
            return;
        }

        @try {
            if ([_pdfView scaleFactor] == _pdfView.scaleFactorForSizeToFit) {
                CGPoint point = [recognizer locationInView:_pdfView];
                PDFPage* page = [_pdfView pageForPoint:point nearest:YES];
                if (page != nil) {
                    PDFPoint pdfPoint = [_pdfView convertPoint:point toPage:page];
                    PDFRect rect = [page boundsForBox:kPDFDisplayBoxMediaBox];
                    PDFDestination* destination = [[PDFDestination alloc] initWithPage:page atPoint:CGPointMake(pdfPoint.x - (rect.size.width / 4),pdfPoint.y + (rect.size.height / 4))];
                    [UIView animateWithDuration:0.2 animations:^{
                        self-> _pdfView.scaleFactor = self->_pdfView.scaleFactorForSizeToFit * 2;
                        [self->_pdfView goToDestination:destination];
                    }];
                }
            } else {
                [UIView animateWithDuration:0.2 animations:^{
                    self->_pdfView.scaleFactor = self->_pdfView.scaleFactorForSizeToFit;
                }];
            }
        } @catch (NSException *exception) {
            NSLog(@"Warning: Double-tap zoom failed: %@", exception.reason);
        }
    }
}

#pragma mark - UIGestureRecognizerDelegate

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    // Allow double-tap to work with scroll gestures
    if ([gestureRecognizer isKindOfClass:[UITapGestureRecognizer class]]) {
        return YES;
    }
    return NO;
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer {
    // Prevent gesture conflicts during scrolling on iPad
    if (_isIPad && _isScrolling && [gestureRecognizer isKindOfClass:[UITapGestureRecognizer class]]) {
        return NO;
    }
    return YES;
}

#pragma mark - UIScrollViewDelegate

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    _isScrolling = YES;
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {
    if (!decelerate) {
        _isScrolling = NO;
    }
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
    _isScrolling = NO;
}

- (void)scrollViewDidEndScrollingAnimation:(UIScrollView *)scrollView {
    _isScrolling = NO;
}

@end
