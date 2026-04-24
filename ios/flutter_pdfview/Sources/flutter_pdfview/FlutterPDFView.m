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
    _pdfView = [[FLTPDFView alloc] initWithFrame:frame arguments:args controller:self];
    _viewId = viewId;

    @try  {
        NSNumber* backgroundColor = args[@"backgroundColor"];
        if ([backgroundColor isKindOfClass:[NSNumber class]]) {
            unsigned int argb = [backgroundColor unsignedIntValue];
            CGFloat a = ((argb & 0xFF000000) >> 24) / 255.0;
            CGFloat r = ((argb & 0x00FF0000) >> 16) / 255.0;
            CGFloat g = ((argb & 0x0000FF00) >> 8) / 255.0;
            CGFloat b = (argb & 0x000000FF) / 255.0;
            _pdfView.view.backgroundColor = [UIColor colorWithRed:r green:g blue:b alpha:a];
        }
    } @catch (NSException *exception) {
        NSLog(@"Exception while setting background color: %@", exception);
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
    } else if ([[call method] isEqualToString:@"currentPageSize"]) {
        [_pdfView getCurrentPageSize:call result:result];
    } else if ([[call method] isEqualToString:@"getPosition"]) {
        [_pdfView getPosition:call result:result];
    } else if ([[call method] isEqualToString:@"getScale"]) {
        [_pdfView getScale:call result:result];
    } else if ([[call method] isEqualToString:@"setPosition"]) {
        [_pdfView setPosition:call result:result];
    } else if ([[call method] isEqualToString:@"setScale"]) {
        [_pdfView setScale:call result:result];
    } else if ([[call method] isEqualToString:@"currentPage"]) {
        [_pdfView getCurrentPage:call result:result];
    } else if ([[call method] isEqualToString:@"setPage"]) {
        [_pdfView setPage:call result:result];
    } else if ([[call method] isEqualToString:@"updateSettings"]) {
        [_pdfView onUpdateSettings:call result:result];
    } else if ([[call method] isEqualToString:@"setZoomLimits"]) {
        [_pdfView setZoomLimits:call result:result];
    } else if ([[call method] isEqualToString:@"reload"]) {
        [_pdfView reload:call result:result];
    } else if ([[call method] isEqualToString:@"getScreenshot"]) {
        result([FlutterError errorWithCode:@"UNSUPPORTED" message:@"getScreenshot is not implemented on iOS" details:nil]);
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
    PDFDocument* _document;
    UIScrollView* _scrollView;
    NSNumber* _pageCount;
    NSNumber* _currentPageIndex;
    PDFDestination* _currentDestination;
    BOOL _preventLinkNavigation;
    BOOL _autoSpacing;
    PDFPage* _defaultPage;
    PDFPage* _currentPage;
    int _pageNo;
    BOOL _defaultPageSet;
    BOOL _isIPad;
    BOOL _isScrolling;
    BOOL _didLoadComplete;
    BOOL _isObserving;
}

- (instancetype)initWithFrame:(CGRect)frame
                    arguments:(id _Nullable)args
                   controller:(nonnull FLTPDFViewController *)controller {

    self = [super initWithFrame:frame];
    if (self) {
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

        if ([filePath isKindOfClass:[NSString class]]) {
            NSURL* sourcePDFUrl = [NSURL fileURLWithPath:filePath];
            _document = [[PDFDocument alloc] initWithURL: sourcePDFUrl];
        } else if ([pdfData isKindOfClass:[FlutterStandardTypedData class]]) {
            NSData* sourcePDFdata = [pdfData data];
            _document = [[PDFDocument alloc] initWithData: sourcePDFdata];
        }


        if (_document == nil) {
            [_controller invokeChannelMethod:@"onError" arguments:@{@"error" : @"cannot create document: File not in PDF format or corrupted."}];
        } else {
            _pdfView.autoresizesSubviews = YES;
            _pdfView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
            _pdfView.backgroundColor = [UIColor colorWithWhite:0.95 alpha:1.0];

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
            _pdfView.displaysPageBreaks = NO;
            _pdfView.document = _document;

            _pdfView.maxScaleFactor = 4.0;
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

            NSUInteger pageCount = [_document pageCount];
            if (pageCount == 0) {
                [_controller invokeChannelMethod:@"onError" arguments:@{@"error" : @"PDF has no pages."}];
                return self;
            }
            if (pageCount <= defaultPage) {
                defaultPage = pageCount - 1;
            }

            _defaultPage = [_document pageAtIndex: defaultPage];

            // Configure scroll view with defensive handling for iPad
            if (@available(iOS 11.0, *)) {
                // Delay scroll view configuration to avoid conflicts during initialization
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    @try {
                        UIScrollView *scrollView = nil;

                        for (id subview in self->_pdfView.subviews) {
                            if ([subview isKindOfClass:[UIScrollView class]]) {
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
                                    scrollView.delegate = (id <UIScrollViewDelegate>) self;
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
                            self->_scrollView = scrollView;
                        }
                        __weak __typeof__(self) weakSelf = self;
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [weakSelf handleRenderCompleted:[NSNumber numberWithUnsignedLong: [self->_document pageCount]]];
                        });
                    } @catch (NSException *exception) {
                        NSLog(@"Warning: Failed to configure PDF scroll view: %@",
                              exception.reason);
                    }
                });
            }

            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handlePageChanged:) name:PDFViewPageChangedNotification object:_pdfView];
            [self addSubview:_pdfView];
        }
    }
    return self;
}

- (void)dealloc {
    [self stopObserving];
}

- (void)startObserving {
    if (_scrollView && !_isObserving) {
        [_scrollView addObserver:self
                      forKeyPath:@"contentOffset"
                         options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld
                         context:nil];
        _isObserving = YES;
    }
}

- (void)stopObserving {
    if (_scrollView && _isObserving) {
        @try
        {
            [_scrollView removeObserver:self forKeyPath:@"contentOffset"];
        }
        @catch (NSException * __unused exception) {}
        _isObserving = NO;
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary<NSKeyValueChangeKey,id> *)change
                       context:(void *)context {
    if ([keyPath isEqualToString:@"contentOffset"]) {
        CGPoint newOffset = [change[NSKeyValueChangeNewKey] CGPointValue];
        CGPoint oldOffset = [change[NSKeyValueChangeOldKey] CGPointValue];
        if (!CGPointEqualToPoint(newOffset, oldOffset)) {
            __weak __typeof__(self) weakSelf = self;
            dispatch_async(dispatch_get_main_queue(), ^{
                [weakSelf handleOnDraw];
            });
        }
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
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

    _currentPage = _pdfView.currentPage;
    _pageCount = [NSNumber numberWithUnsignedLong: _pdfView.document.pageCount];
    _pageNo = (int)[_pdfView.document indexForPage:_currentPage] + 1;
}

- (UIView*)view {
    return _pdfView;
}


- (void)getPageCount:(FlutterMethodCall*)call result:(FlutterResult)result {
    result(_pageCount);
}

- (void)getCurrentPageSize:(FlutterMethodCall*)call result:(FlutterResult)result {
    if (_pdfView.currentPage == nil) {
        result([FlutterError errorWithCode:@"INVALID_STATE"
                                   message:@"No page loaded"
                                   details:nil]);
        return;
    }
    CGRect bounds = [_pdfView.currentPage boundsForBox:kPDFDisplayBoxMediaBox];
    NSArray *size = @[[NSNumber numberWithFloat:bounds.size.width], [NSNumber numberWithFloat:bounds.size.height]];
    result(size);
}

- (NSArray *)calculatePosition {
  float x = 0.0;
  float y = 0.0;

  if (_scrollView) {
    if (@available(iOS 11.0, *)) {
      x = -(_scrollView.contentOffset.x + _scrollView.adjustedContentInset.left);
      y = -(_scrollView.contentOffset.y + _scrollView.adjustedContentInset.top);
    } else {
      x = -(_scrollView.contentOffset.x + _scrollView.contentInset.left);
      y = -(_scrollView.contentOffset.y + _scrollView.contentInset.top);
    }
  }

  return
      @[ [NSNumber numberWithFloat:MAX(x, 0)], [NSNumber numberWithFloat:y] ];
}

- (void)getPosition:(FlutterMethodCall*)call result:(FlutterResult)result {
    if (_currentPage == nil || _pageCount == nil) {
        result([FlutterError errorWithCode:@"INVALID_STATE" message:@"PDFView not ready" details:nil]);
        return;
    }
    NSArray *position = [self calculatePosition];
    result(position);
}

- (void)getScale:(FlutterMethodCall*)call result:(FlutterResult)result {
    NSNumber *scale = [NSNumber numberWithFloat:_pdfView.scaleFactor];
    result(scale);
}

- (void)setPosition:(FlutterMethodCall *)call result:(FlutterResult)result {
    if (_currentPage == nil || _pageCount == nil) {
        result([FlutterError errorWithCode:@"INVALID_STATE"
                                   message:@"PDFView not ready"
                                   details:nil]);
        return;
    }

    NSDictionary<NSString *, NSNumber *> *arguments = [call arguments];

    if (_scrollView) {
        float targetX = -arguments[@"xPos"].floatValue;
        float targetY = -arguments[@"yPos"].floatValue;

        CGPoint targetOffset = CGPointMake(targetX, targetY);

        float minOffsetY = 0.0;
        float maxOffsetY = 0.0;

        if (@available(iOS 11.0, *)) {
            targetOffset.x -= _scrollView.adjustedContentInset.left;
            targetOffset.y -= _scrollView.adjustedContentInset.top;
            minOffsetY = -_scrollView.adjustedContentInset.top;
            maxOffsetY = MAX(minOffsetY, _scrollView.contentSize.height - _scrollView.bounds.size.height + _scrollView.adjustedContentInset.bottom);
        } else {
            targetOffset.x -= _scrollView.contentInset.left;
            targetOffset.y -= _scrollView.contentInset.top;
            minOffsetY = -_scrollView.contentInset.top;
            maxOffsetY = MAX(minOffsetY, _scrollView.contentSize.height - _scrollView.bounds.size.height + _scrollView.contentInset.bottom);
        }

        if (targetOffset.y < minOffsetY) {
            targetOffset.y = minOffsetY;
        } else if (targetOffset.y > maxOffsetY) {
            targetOffset.y = maxOffsetY;
        }
        
        [_scrollView setContentOffset:targetOffset animated:NO];
    }

    result([NSNumber numberWithBool:YES]);
}

- (void)setScale:(FlutterMethodCall*)call result:(FlutterResult)result {
    NSNumber* scale = call.arguments[@"scale"];
    if (![scale isKindOfClass:[NSNumber class]] || scale.doubleValue <= 0.0) {
        result([FlutterError errorWithCode:@"INVALID_ARGS" message:@"scale must be > 0" details:nil]);
        return;
    }
    _pdfView.scaleFactor = scale.doubleValue;
    result([NSNumber numberWithBool: YES]);
}

- (void)getCurrentPage:(FlutterMethodCall*)call result:(FlutterResult)result {
    _currentPageIndex = [NSNumber numberWithUnsignedLong: [_pdfView.document indexForPage: _pdfView.currentPage]];
    result(_currentPageIndex);
}

- (void)reload:(FlutterMethodCall*)call result:(FlutterResult)result {
    _pdfView.document = _document;
    if (_document.pageCount > 0) {
        PDFPage *firstPage = [_document pageAtIndex:0];
        [_pdfView goToPage:firstPage];

        CGRect pageBounds = [firstPage boundsForBox:kPDFDisplayBoxMediaBox];
        [self->_pdfView goToRect:CGRectMake(0, pageBounds.size.height, 1, 1) onPage:firstPage];

        _pdfView.scaleFactor = _pdfView.scaleFactorForSizeToFit;
    }

    result([NSNumber numberWithBool: YES]);
}

- (void)setPage:(FlutterMethodCall*)call result:(FlutterResult)result {
    NSDictionary<NSString*, NSNumber*>* arguments = [call arguments];
    NSNumber* page = arguments[@"page"];
    NSUInteger pageIndex = page.unsignedLongValue;
    NSUInteger pageCount = [_pdfView.document pageCount];
    if (pageIndex >= pageCount) {
        result([FlutterError errorWithCode:@"INVALID_PAGE" message:@"Page index out of bounds" details:nil]);
        return;
    }

    [_pdfView goToPage: [_pdfView.document pageAtIndex: pageIndex ]];
    result([NSNumber numberWithBool: YES]);
}

- (void)onUpdateSettings:(FlutterMethodCall*)call result:(FlutterResult)result {
    result(nil);
}

- (void)setZoomLimits:(FlutterMethodCall*)call result:(FlutterResult)result {
    NSDictionary<NSString*, NSNumber*>* arguments = [call arguments];
    NSNumber* minZoom = arguments[@"minZoom"];
    NSNumber* maxZoom = arguments[@"maxZoom"];
    float minScale = minZoom.floatValue * _pdfView.scaleFactorForSizeToFit;
    float maxScale = maxZoom.floatValue * _pdfView.scaleFactorForSizeToFit;
    _pdfView.minScaleFactor = minScale != 0.0 ? minScale : minZoom.floatValue;
    _pdfView.maxScaleFactor = maxScale != 0.0 ? maxScale : maxZoom.floatValue;
    result([NSNumber numberWithBool: YES]);
}

-(void)handlePageChanged:(NSNotification*)notification {
    _currentPage = _pdfView.currentPage;
    _pageNo = (int)[_pdfView.document indexForPage:_currentPage] + 1;
    [_controller invokeChannelMethod:@"onPageChanged" arguments:@{@"page" : [NSNumber numberWithUnsignedLong: _pageNo - 1], @"total" : [NSNumber numberWithUnsignedLong: [_pdfView.document pageCount]]}];
}

-(void)handleRenderCompleted: (NSNumber*)pages {
    [_controller invokeChannelMethod:@"onRender" arguments:@{@"pages" : pages}];
    if (!_didLoadComplete) {
        _didLoadComplete = YES;
        [_controller invokeChannelMethod:@"onLoadComplete" arguments:@{@"pages" : pages}];
    }
    [self startObserving];
}

- (void)handleOnDraw {
    NSArray *position = [self calculatePosition];
    [_controller invokeChannelMethod:@"onDraw"
                           arguments:@{@"pdfXOffset" : [position objectAtIndex:0],
                                       @"pdfYOffset" :  [position objectAtIndex:1],
                                       @"pdfScale" : [NSNumber numberWithFloat:_pdfView.scaleFactor]}
    ];
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
