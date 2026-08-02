#import "./include/flutter_pdfview/FlutterPDFView.h"

@implementation FLTPDFViewFactory {
    NSObject<FlutterBinaryMessenger> *_messenger;
}

- (instancetype)initWithMessenger:(NSObject<FlutterBinaryMessenger> *)messenger {
    self = [super init];
    if (self) {
        _messenger = messenger;
    }
    return self;
}

- (NSObject<FlutterMessageCodec> *)createArgsCodec {
    return [FlutterStandardMessageCodec sharedInstance];
}

- (NSObject<FlutterPlatformView> *)createWithFrame:(CGRect)frame
                                    viewIdentifier:(int64_t)viewId
                                         arguments:(id _Nullable)args {
    FLTPDFViewController *pdfviewController =
        [[FLTPDFViewController alloc] initWithFrame:frame
                                     viewIdentifier:viewId
                                          arguments:args
                                    binaryMessenger:_messenger];
    return pdfviewController;
}

@end

@implementation FLTPDFViewController {
    FLTPDFView *_pdfView;
    int64_t _viewId;
    FlutterMethodChannel *_channel;
}

- (instancetype)initWithFrame:(CGRect)frame
               viewIdentifier:(int64_t)viewId
                    arguments:(id _Nullable)args
              binaryMessenger:(NSObject<FlutterBinaryMessenger> *)messenger {
    self = [super init];
    _pdfView = [[FLTPDFView alloc] initWithFrame:frame
                                       arguments:args
                                      controller:self];
    _viewId = viewId;

    @try {
        NSNumber *backgroundColor = args[@"backgroundColor"];
        if ([backgroundColor isKindOfClass:[NSNumber class]]) {
            unsigned int argb = [backgroundColor unsignedIntValue];
            CGFloat a = ((argb & 0xFF000000) >> 24) / 255.0;
            CGFloat r = ((argb & 0x00FF0000) >> 16) / 255.0;
            CGFloat g = ((argb & 0x0000FF00) >> 8) / 255.0;
            CGFloat b = (argb & 0x000000FF) / 255.0;
            _pdfView.view.backgroundColor = [UIColor colorWithRed:r
                                                            green:g
                                                             blue:b
                                                            alpha:a];
        }
    } @catch (NSException *exception) {
        NSLog(@"Exception while setting background color: %@", exception);
    }

    NSString *channelName =
        [NSString stringWithFormat:@"plugins.endigo.io/pdfview_%lld", viewId];
    _channel = [FlutterMethodChannel methodChannelWithName:channelName
                                           binaryMessenger:messenger];
    __weak __typeof__(self) weakSelf = self;
    [_channel
        setMethodCallHandler:^(FlutterMethodCall *call, FlutterResult result) {
          [weakSelf onMethodCall:call result:result];
        }];

    return self;
}

- (void)onMethodCall:(FlutterMethodCall *)call result:(FlutterResult)result {
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
        result([FlutterError
            errorWithCode:@"UNSUPPORTED"
                  message:@"getScreenshot is not implemented on iOS"
                  details:nil]);
    } else {
        result(FlutterMethodNotImplemented);
    }
}

- (void)invokeChannelMethod:(NSString *)name arguments:(id)args {
    [_channel invokeMethod:name arguments:args];
}

- (UIView *)view {
    return _pdfView;
}

- (void)dealloc {
    // Unregister from the messenger; otherwise the engine keeps one dead
    // handler per created platform view for the app's lifetime (#261).
    [_channel setMethodCallHandler:nil];
}

@end

/// How pages are scaled to the viewport (mirrors Dart [FitPolicy]).
typedef NS_ENUM(NSInteger, FLTPDFFitPolicy) {
    FLTPDFFitPolicyWidth = 0,
    FLTPDFFitPolicyHeight = 1,
    FLTPDFFitPolicyBoth = 2,
};

@implementation FLTPDFView {
    FLTPDFViewController *__weak _controller;
    PDFView *_pdfView;
    PDFDocument *_document;
    UIScrollView *_scrollView;
    NSNumber *_pageCount;
    NSNumber *_currentPageIndex;
    PDFDestination *_currentDestination;
    BOOL _preventLinkNavigation;
    BOOL _autoSpacing;
    FLTPDFFitPolicy _fitPolicy;
    PDFPage *_defaultPage;
    PDFPage *_currentPage;
    int _pageNo;
    BOOL _defaultPageSet;
    BOOL _isIPad;
    BOOL _isScrolling;
    BOOL _didLoadComplete;
    BOOL _isObserving;
    CGFloat _maxScaleFactor;
    CGFloat _minScaleFactor;
    BOOL _hasSentInitialPage;
    /// Last view size we laid out against — used to re-fit after the temporary
    /// non-zero frame (#268) expands to the real Flutter bounds (#150).
    CGSize _lastLayoutSize;
    /// Fit scale applied for `_lastLayoutSize` (before user zoom multiplier).
    CGFloat _lastFitScale;
    /// Whether we have successfully applied an initial fit at a real size.
    BOOL _hasAppliedInitialFit;
}

- (instancetype)initWithFrame:(CGRect)frame
                    arguments:(id _Nullable)args
                   controller:(nonnull FLTPDFViewController *)controller {

    self = [super initWithFrame:frame];
    if (self) {
        _controller = controller;

        // Detect if device is iPad
        _isIPad = ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad);
        _isScrolling = NO;

        // #268: PDFKit emits NaN CoreGraphics errors when PDFView is created with a
        // zero / empty frame (common for Flutter platform views before first layout).
        // Use a temporary non-zero frame; layoutSubviews will size it correctly.
        CGRect pdfFrame = frame;
        if (CGRectIsEmpty(pdfFrame) || pdfFrame.size.width <= 0 || pdfFrame.size.height <= 0) {
            pdfFrame = CGRectMake(0, 0, 100, 100);
        }
        _pdfView = [[PDFView alloc] initWithFrame:pdfFrame];
        _pdfView.delegate = self;

        _autoSpacing = [args[@"autoSpacing"] boolValue];
        _fitPolicy = [self fitPolicyFromArguments:args];
        _lastLayoutSize = CGSizeZero;
        _lastFitScale = 0;
        _hasAppliedInitialFit = NO;
        BOOL pageFling = [args[@"pageFling"] boolValue];
        BOOL enableSwipe = [args[@"enableSwipe"] boolValue];
        _preventLinkNavigation = [args[@"preventLinkNavigation"] boolValue];

        NSInteger defaultPage = [args[@"defaultPage"] integerValue];

        NSString *filePath = args[@"filePath"];
        FlutterStandardTypedData *pdfData = args[@"pdfData"];

        if ([filePath isKindOfClass:[NSString class]]) {
            // Support plain paths and file:// URIs (#266 parity with Android).
            // URLWithString returns nil for unescaped characters (spaces, etc.);
            // never fall back to fileURLWithPath on a full "file://..." string.
            NSURL *sourcePDFUrl = [self pdfURLFromFilePath:filePath];
            _document = [[PDFDocument alloc] initWithURL:sourcePDFUrl];
        } else if ([pdfData isKindOfClass:[FlutterStandardTypedData class]]) {
            NSData *sourcePDFdata = [pdfData data];
            _document = [[PDFDocument alloc] initWithData:sourcePDFdata];
        }

        if (_document == nil) {
            __weak __typeof__(self) weakSelf = self;
            dispatch_async(dispatch_get_main_queue(), ^{
              __strong __typeof__(weakSelf) strongSelf = weakSelf;
              if (strongSelf == nil) {
                  return;
              }
              [strongSelf->_controller
                  invokeChannelMethod:@"onError"
                            arguments:@{
                                @"error" : @"cannot create document: File not "
                                           @"in PDF format or corrupted."
                            }];
            });
        } else {
            _pdfView.autoresizesSubviews = YES;
            _pdfView.autoresizingMask = UIViewAutoresizingFlexibleWidth |
                                        UIViewAutoresizingFlexibleHeight;
            // #204: Prefer explicit backgroundColor from Flutter; otherwise white
            // (grey 0.95 made continuous pages look non-continuous vs Android).
            NSNumber *bgColorNum = args[@"backgroundColor"];
            if ([bgColorNum isKindOfClass:[NSNumber class]]) {
                unsigned int argb = [bgColorNum unsignedIntValue];
                CGFloat a = ((argb & 0xFF000000) >> 24) / 255.0;
                CGFloat r = ((argb & 0x00FF0000) >> 16) / 255.0;
                CGFloat g = ((argb & 0x0000FF00) >> 8) / 255.0;
                CGFloat b = (argb & 0x000000FF) / 255.0;
                UIColor *bg = [UIColor colorWithRed:r green:g blue:b alpha:a];
                _pdfView.backgroundColor = bg;
                self.backgroundColor = bg;
            } else {
                _pdfView.backgroundColor = [UIColor whiteColor];
                self.backgroundColor = [UIColor whiteColor];
            }

            BOOL swipeHorizontal = [args[@"swipeHorizontal"] boolValue];
            if (swipeHorizontal) {
                _pdfView.displayDirection = kPDFDisplayDirectionHorizontal;
            } else {
                _pdfView.displayDirection = kPDFDisplayDirectionVertical;
            }

            BOOL showScrollIndicators = [args[@"showScrollIndicators"] boolValue];

            // Manage scale ourselves so fitPolicy and autoSpacing stay independent
            // (#150). PDFKit's autoScales always does "fit both" and used to be
            // incorrectly tied to autoSpacing.
            _pdfView.autoScales = NO;

            // UIPageViewController flips one page at a time — only match the API
            // for horizontal book-style paging. Vertical layouts scroll
            // continuously so iOS behaves like Android (#204).
            BOOL useHorizontalPaging = pageFling && swipeHorizontal && enableSwipe;
            [_pdfView usePageViewController:useHorizontalPaging withViewOptions:nil];
            if (enableSwipe && !useHorizontalPaging) {
                _pdfView.displayMode = kPDFDisplaySinglePageContinuous;
            } else {
                _pdfView.displayMode = kPDFDisplaySinglePage;
            }
            // autoSpacing only controls gaps between pages — never zoom/fit (#150).
            _pdfView.displaysPageBreaks = _autoSpacing;
            if (_autoSpacing) {
                _pdfView.pageBreakMargins = UIEdgeInsetsMake(4, 0, 4, 0);
            } else {
                _pdfView.pageBreakMargins = UIEdgeInsetsZero;
            }
            _pdfView.document = _document;

            double maxZoomArg = [args[@"maxZoom"] doubleValue];
            double minZoomArg = [args[@"minZoom"] doubleValue];
            if (maxZoomArg <= 0) {
                maxZoomArg = 4.0;
            }
            if (minZoomArg <= 0) {
                minZoomArg = 1.0;
            }
            _maxScaleFactor = maxZoomArg;
            _minScaleFactor = minZoomArg;

            NSString *password = args[@"password"];
            if ([_pdfView.document isEncrypted]) {
                if ([password isKindOfClass:[NSString class]]) {
                    [_pdfView.document unlockWithPassword:password];
                }
                if ([_pdfView.document isLocked]) {
                    // Android reports a PdfPasswordException through onError;
                    // without this the iOS view just stays blank.
                    __weak __typeof__(self) weakSelf = self;
                    dispatch_async(dispatch_get_main_queue(), ^{
                      __strong __typeof__(weakSelf) strongSelf = weakSelf;
                      if (strongSelf == nil) {
                          return;
                      }
                      [strongSelf->_controller
                          invokeChannelMethod:@"onError"
                                    arguments:@{
                                        @"error" : @"Password required or "
                                                   @"incorrect password."
                                    }];
                    });
                }
            }

            UITapGestureRecognizer *tapGestureRecognizer =
                [[UITapGestureRecognizer alloc]
                    initWithTarget:self
                            action:@selector(onDoubleTap:)];
            tapGestureRecognizer.numberOfTapsRequired = 2;
            tapGestureRecognizer.numberOfTouchesRequired = 1;
            tapGestureRecognizer.delegate = self;
            tapGestureRecognizer.delaysTouchesBegan = NO;
            tapGestureRecognizer.delaysTouchesEnded = NO;
            [_pdfView addGestureRecognizer:tapGestureRecognizer];

            NSUInteger pageCount = [_document pageCount];
            if (pageCount == 0) {
                // Defer like the nil-document path: the Dart handler is only
                // attached after the platform view is created.
                __weak __typeof__(self) weakSelf = self;
                dispatch_async(dispatch_get_main_queue(), ^{
                  __strong __typeof__(weakSelf) strongSelf = weakSelf;
                  if (strongSelf == nil) {
                      return;
                  }
                  [strongSelf->_controller
                      invokeChannelMethod:@"onError"
                                arguments:@{@"error" : @"PDF has no pages."}];
                });
                return self;
            }
            if (pageCount <= defaultPage) {
                defaultPage = pageCount - 1;
            }

            _defaultPage = [_document pageAtIndex:defaultPage];

            // Configure scroll view with defensive handling for iPad.
            // PDFKit may not expose its scroll view immediately; retry a few
            // times instead of a single fixed delay. Capture weakly so a
            // disposed view is not reconfigured (#261).
            if (@available(iOS 11.0, *)) {
                __weak __typeof__(self) weakSelf = self;
                const NSInteger maxAttempts = 5;
                const NSTimeInterval retryDelay = 0.05;
                __block void (^configureScrollView)(NSInteger) = nil;
                configureScrollView = ^(NSInteger attempt) {
                  __strong __typeof__(weakSelf) strongSelf = weakSelf;
                  if (strongSelf == nil) {
                      configureScrollView = nil;
                      return;
                  }
                  @try {
                      UIScrollView *scrollView =
                          [strongSelf findScrollView:strongSelf->_pdfView];
                      if (scrollView == nil && attempt + 1 < maxAttempts) {
                          dispatch_after(
                              dispatch_time(DISPATCH_TIME_NOW,
                                            (int64_t)(retryDelay * NSEC_PER_SEC)),
                              dispatch_get_main_queue(), ^{
                                configureScrollView(attempt + 1);
                              });
                          return;
                      }

                      if (scrollView != nil) {
                          if (strongSelf->_isIPad) {
                              scrollView.contentInsetAdjustmentBehavior =
                                  UIScrollViewContentInsetAdjustmentAutomatic;
                              if (scrollView.delegate == nil) {
                                  scrollView.delegate =
                                      (id<UIScrollViewDelegate>)strongSelf;
                              }
                          } else {
                              scrollView.contentInsetAdjustmentBehavior =
                                  UIScrollViewContentInsetAdjustmentNever;
                              if (@available(iOS 13.0, *)) {
                                  scrollView.automaticallyAdjustsScrollIndicatorInsets = NO;
                              }
                          }

                          scrollView.delaysContentTouches = YES;
                          scrollView.canCancelContentTouches = YES;
                          // Indicators cannot be shown while the page-view
                          // controller manages paging (swaps scroll views).
                          BOOL shouldShow =
                              showScrollIndicators && !useHorizontalPaging;
                          scrollView.showsHorizontalScrollIndicator = shouldShow;
                          scrollView.showsVerticalScrollIndicator = shouldShow;
                          strongSelf->_scrollView = scrollView;
                      }
                      // Always report render completion after the configure path
                      // finishes (even if the scroll view was never found).
                      dispatch_async(dispatch_get_main_queue(), ^{
                        __strong __typeof__(weakSelf) innerSelf = weakSelf;
                        if (innerSelf == nil || innerSelf->_document == nil) {
                            return;
                        }
                        [innerSelf handleRenderCompleted:
                         [NSNumber numberWithUnsignedLong:
                              [innerSelf->_document pageCount]]];
                      });
                  } @catch (NSException *exception) {
                      NSLog(@"Warning: Failed to configure PDF scroll view: %@",
                            exception.reason);
                      dispatch_async(dispatch_get_main_queue(), ^{
                        __strong __typeof__(weakSelf) innerSelf = weakSelf;
                        if (innerSelf == nil || innerSelf->_document == nil) {
                            return;
                        }
                        [innerSelf handleRenderCompleted:
                         [NSNumber numberWithUnsignedLong:
                              [innerSelf->_document pageCount]]];
                      });
                  }
                  configureScrollView = nil;
                };
                // Defer the first attempt one run-loop turn so PDFKit can finish
                // installing its internal hierarchy after addSubview.
                dispatch_async(dispatch_get_main_queue(), ^{
                  configureScrollView(0);
                });
            }

            [[NSNotificationCenter defaultCenter]
                addObserver:self
                   selector:@selector(handlePageChanged:)
                       name:PDFViewPageChangedNotification
                     object:_pdfView];
            [self addSubview:_pdfView];
        }
    }
    return self;
}

- (void)dealloc {
    // #261: Tear down observers/document so PdfKit resources are released when
    // the Flutter platform view is disposed (e.g. user presses back).
    [self stopObserving];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    if (_scrollView != nil &&
        _scrollView.delegate == (id<UIScrollViewDelegate>)self) {
        _scrollView.delegate = nil;
    }
    if (_pdfView != nil) {
        _pdfView.delegate = nil;
        _pdfView.document = nil;
        [_pdfView removeFromSuperview];
        _pdfView = nil;
    }
    _document = nil;
    _scrollView = nil;
    _defaultPage = nil;
    _currentPage = nil;
    _currentDestination = nil;
}

- (UIScrollView *)findScrollView:(UIView *)view {
    if ([view isKindOfClass:[UIScrollView class]]) {
        return (UIScrollView *)view;
    }
    for (UIView *subview in view.subviews) {
        UIScrollView *scrollView = [self findScrollView:subview];
        if (scrollView) {
            return scrollView;
        }
    }
    return nil;
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
        @try {
            [_scrollView removeObserver:self forKeyPath:@"contentOffset"];
        } @catch (NSException *__unused exception) {
        }
        _isObserving = NO;
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary<NSKeyValueChangeKey, id> *)change
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
        [super observeValueForKeyPath:keyPath
                             ofObject:object
                               change:change
                              context:context];
    }
}

- (void)layoutSubviews {
    [super layoutSubviews];

    // Skip layout updates during scrolling to prevent conflicts
    if (_isScrolling) {
        return;
    }

    // Guard against zero bounds — PDFKit NaN paths (#268).
    if (self.bounds.size.width <= 0 || self.bounds.size.height <= 0 ||
        _pdfView == nil) {
        return;
    }

    // Wrap layout updates in try-catch for safety
    @try {
        _pdfView.frame = self.bounds;

        // Need a page to compute WIDTH/HEIGHT fit; BOTH can use PDFKit helper.
        if (_pdfView.document == nil) {
            return;
        }
        if (!_defaultPageSet && _defaultPage != nil) {
            [_pdfView goToPage:_defaultPage];
            _defaultPageSet = true;
        }

        CGFloat fitScale = [self fitScaleForCurrentPolicy];
        // Fit scale can be 0/NaN before the document lays out.
        if (!isfinite(fitScale) || fitScale <= 0) {
            return;
        }
        CGFloat minScale = fitScale * _minScaleFactor;
        CGFloat maxScale = fitScale * _maxScaleFactor;
        if (!isfinite(minScale) || !isfinite(maxScale)) {
            return;
        }
        _pdfView.minScaleFactor = minScale;
        _pdfView.maxScaleFactor = fmax(maxScale, minScale);

        // #150: Fit is independent of autoSpacing. Re-apply when:
        //  - we have not yet applied a fit at a real size, or
        //  - the view size changed (placeholder 100x100 → real bounds, or
        //    rotation) and the user is still at the previous fit scale, or
        //  - the view size changed and the user was zoomed — preserve relative
        //    zoom against the new fit baseline.
        CGSize boundsSize = self.bounds.size;
        BOOL sizeChanged =
            fabs(boundsSize.width - _lastLayoutSize.width) > 0.5 ||
            fabs(boundsSize.height - _lastLayoutSize.height) > 0.5;
        BOOL nearPreviousFit =
            _lastFitScale > 0 &&
            fabs(_pdfView.scaleFactor - _lastFitScale) <=
                fmax(0.02, _lastFitScale * 0.02);

        CGFloat targetScale = fitScale;
        BOOL shouldSetScale = NO;
        if (!_hasAppliedInitialFit) {
            shouldSetScale = YES;
        } else if (sizeChanged) {
            shouldSetScale = YES;
            if (!nearPreviousFit && _lastFitScale > 0) {
                CGFloat relative = _pdfView.scaleFactor / _lastFitScale;
                if (isfinite(relative) && relative > 0) {
                    targetScale = fitScale * relative;
                }
            }
        }

        if (shouldSetScale) {
            CGFloat clampedScale =
                fmin(fmax(targetScale, _pdfView.minScaleFactor),
                     _pdfView.maxScaleFactor);
            if (isfinite(clampedScale) && clampedScale > 0) {
                _pdfView.scaleFactor = clampedScale;
            }
            _lastFitScale = fitScale;
            _lastLayoutSize = boundsSize;
            _hasAppliedInitialFit = YES;
        } else {
            // Still track size so a later change is detected; keep fit baseline.
            _lastLayoutSize = boundsSize;
            _lastFitScale = fitScale;
        }

        if (!_hasSentInitialPage && _defaultPageSet &&
            _pdfView.document != nil && _pdfView.currentPage != nil) {
            _hasSentInitialPage = YES;
            NSUInteger currentPageIndex =
                [_pdfView.document indexForPage:_pdfView.currentPage];
            NSUInteger pageCount = [_pdfView.document pageCount];
            [_controller
                invokeChannelMethod:@"onPageChanged"
                          arguments:@{
                              @"page" : [NSNumber
                                  numberWithUnsignedLong:currentPageIndex],
                              @"total" :
                                  [NSNumber numberWithUnsignedLong:pageCount]
                          }];
        }
    } @catch (NSException *exception) {
        NSLog(@"Warning: Layout update failed: %@", exception.reason);
    }

    _currentPage = _pdfView.currentPage;
    _pageCount = [NSNumber numberWithUnsignedLong:_pdfView.document.pageCount];
    if (_currentPage != nil && _pdfView.document != nil) {
        NSUInteger idx = [_pdfView.document indexForPage:_currentPage];
        if (idx != NSNotFound) {
            _pageNo = (int)idx + 1;
        }
    }
}

/// Parses Dart's `FitPolicy.WIDTH|HEIGHT|BOTH` creation argument.
- (FLTPDFFitPolicy)fitPolicyFromArguments:(NSDictionary *)args {
    id raw = args[@"fitPolicy"];
    if (![raw isKindOfClass:[NSString class]]) {
        return FLTPDFFitPolicyWidth;
    }
    NSString *policy = (NSString *)raw;
    if ([policy isEqualToString:@"FitPolicy.HEIGHT"]) {
        return FLTPDFFitPolicyHeight;
    }
    if ([policy isEqualToString:@"FitPolicy.BOTH"]) {
        return FLTPDFFitPolicyBoth;
    }
    // WIDTH and any unknown value → width (matches Dart default).
    return FLTPDFFitPolicyWidth;
}

/// Scale that fits the current (or default) page per `_fitPolicy`.
- (CGFloat)fitScaleForCurrentPolicy {
    if (_pdfView == nil || _pdfView.document == nil) {
        return 0;
    }

    CGSize viewSize = _pdfView.bounds.size;
    if (viewSize.width <= 0 || viewSize.height <= 0) {
        viewSize = self.bounds.size;
    }
    if (viewSize.width <= 0 || viewSize.height <= 0) {
        return 0;
    }

    PDFPage *page = _pdfView.currentPage;
    if (page == nil) {
        page = _defaultPage;
    }
    if (page == nil && _pdfView.document.pageCount > 0) {
        page = [_pdfView.document pageAtIndex:0];
    }
    if (page == nil) {
        return 0;
    }

    CGRect pageRect = [page boundsForBox:_pdfView.displayBox];
    if (pageRect.size.width <= 0 || pageRect.size.height <= 0) {
        return 0;
    }

    // Account for page rotation so landscape pages fit correctly (#247).
    NSInteger rotation = page.rotation;
    CGFloat pageWidth = pageRect.size.width;
    CGFloat pageHeight = pageRect.size.height;
    if (rotation == 90 || rotation == 270) {
        CGFloat tmp = pageWidth;
        pageWidth = pageHeight;
        pageHeight = tmp;
    }

    CGFloat scaleWidth = viewSize.width / pageWidth;
    CGFloat scaleHeight = viewSize.height / pageHeight;
    CGFloat scale = 0;
    switch (_fitPolicy) {
    case FLTPDFFitPolicyHeight:
        scale = scaleHeight;
        break;
    case FLTPDFFitPolicyBoth: {
        // Prefer PDFKit's geometry (handles display mode / insets) when ready.
        CGFloat pdfKitFit = _pdfView.scaleFactorForSizeToFit;
        if (isfinite(pdfKitFit) && pdfKitFit > 0) {
            scale = pdfKitFit;
        } else {
            scale = fmin(scaleWidth, scaleHeight);
        }
        break;
    }
    case FLTPDFFitPolicyWidth:
    default:
        scale = scaleWidth;
        break;
    }

    if (!isfinite(scale) || scale <= 0) {
        return 0;
    }
    return scale;
}

- (UIView *)view {
    return _pdfView;
}

- (void)getPageCount:(FlutterMethodCall *)call result:(FlutterResult)result {
    result(_pageCount);
}

- (void)getCurrentPageSize:(FlutterMethodCall *)call
                    result:(FlutterResult)result {
    if (_pdfView.currentPage == nil) {
        result([FlutterError errorWithCode:@"INVALID_STATE"
                                   message:@"No page loaded"
                                   details:nil]);
        return;
    }
    CGRect bounds = [_pdfView.currentPage boundsForBox:kPDFDisplayBoxMediaBox];
    NSArray *size = @[
        [NSNumber numberWithFloat:bounds.size.width],
        [NSNumber numberWithFloat:bounds.size.height]
    ];
    result(size);
}

- (NSArray *)calculatePosition {
    float x = 0.0;
    float y = 0.0;

    if (_scrollView) {
        if (@available(iOS 11.0, *)) {
            x = -(_scrollView.contentOffset.x +
                  _scrollView.adjustedContentInset.left);
            y = -(_scrollView.contentOffset.y +
                  _scrollView.adjustedContentInset.top);
        } else {
            x = -(_scrollView.contentOffset.x + _scrollView.contentInset.left);
            y = -(_scrollView.contentOffset.y + _scrollView.contentInset.top);
        }
    }

    return @[ [NSNumber numberWithFloat:x], [NSNumber numberWithFloat:y] ];
}

- (void)getPosition:(FlutterMethodCall *)call result:(FlutterResult)result {
    if (_scrollView == nil) {
        result([FlutterError errorWithCode:@"INVALID_STATE"
                                   message:@"PDFView not ready"
                                   details:nil]);
        return;
    }
    NSArray *position = [self calculatePosition];
    result(position);
}

- (void)getScale:(FlutterMethodCall *)call result:(FlutterResult)result {
    NSNumber *scale = [NSNumber numberWithFloat:_pdfView.scaleFactor];
    result(scale);
}

- (void)setPosition:(FlutterMethodCall *)call result:(FlutterResult)result {
    if (_scrollView == nil) {
        result([FlutterError errorWithCode:@"INVALID_STATE"
                                   message:@"PDFView not ready"
                                   details:nil]);
        return;
    }

    NSDictionary<NSString *, NSNumber *> *arguments = [call arguments];

    float targetX = -arguments[@"xPos"].floatValue;
    float targetY = -arguments[@"yPos"].floatValue;

    CGPoint targetOffset = CGPointMake(targetX, targetY);

    float minOffsetY = 0.0;
    float maxOffsetY = 0.0;

    if (@available(iOS 11.0, *)) {
        targetOffset.x -= _scrollView.adjustedContentInset.left;
        targetOffset.y -= _scrollView.adjustedContentInset.top;
        minOffsetY = -_scrollView.adjustedContentInset.top;
        maxOffsetY = MAX(minOffsetY, _scrollView.contentSize.height -
                         _scrollView.bounds.size.height +
                         _scrollView.adjustedContentInset.bottom);
    } else {
        targetOffset.x -= _scrollView.contentInset.left;
        targetOffset.y -= _scrollView.contentInset.top;
        minOffsetY = -_scrollView.contentInset.top;
        maxOffsetY = MAX(minOffsetY, _scrollView.contentSize.height -
                                         _scrollView.bounds.size.height +
                                         _scrollView.contentInset.bottom);
    }

    if (targetOffset.y < minOffsetY) {
        targetOffset.y = minOffsetY;
    } else if (targetOffset.y > maxOffsetY) {
        targetOffset.y = maxOffsetY;
    }

    [_scrollView setContentOffset:targetOffset animated:NO];

    result([NSNumber numberWithBool:YES]);
}

- (void)setScale:(FlutterMethodCall *)call result:(FlutterResult)result {
    NSNumber *scale = call.arguments[@"scale"];
    if (![scale isKindOfClass:[NSNumber class]] || scale.doubleValue <= 0.0) {
        result([FlutterError errorWithCode:@"INVALID_ARGS"
                                   message:@"scale must be > 0"
                                   details:nil]);
        return;
    }
    _pdfView.scaleFactor = scale.doubleValue;
    result([NSNumber numberWithBool:YES]);
}

- (void)getCurrentPage:(FlutterMethodCall *)call result:(FlutterResult)result {
    PDFPage *currentPage = _pdfView.currentPage;
    if (_pdfView.document == nil || currentPage == nil) {
        result(nil);
        return;
    }
    NSUInteger pageIndex = [_pdfView.document indexForPage:currentPage];
    if (pageIndex == NSNotFound) {
        result(nil);
        return;
    }
    _currentPageIndex = [NSNumber numberWithUnsignedLong:pageIndex];
    result(_currentPageIndex);
}

- (void)reload:(FlutterMethodCall *)call result:(FlutterResult)result {
    _pdfView.document = _document;
    _hasAppliedInitialFit = NO;
    _lastFitScale = 0;
    _lastLayoutSize = CGSizeZero;
    if (_document.pageCount > 0) {
        PDFPage *firstPage = [_document pageAtIndex:0];
        [_pdfView goToPage:firstPage];

        CGRect pageBounds = [firstPage boundsForBox:kPDFDisplayBoxMediaBox];
        [self->_pdfView goToRect:CGRectMake(0, pageBounds.size.height, 1, 1)
                          onPage:firstPage];

        CGFloat fitScale = [self fitScaleForCurrentPolicy];
        if (isfinite(fitScale) && fitScale > 0) {
            _pdfView.scaleFactor = fitScale;
            _lastFitScale = fitScale;
            _lastLayoutSize = self.bounds.size;
            _hasAppliedInitialFit = YES;
        }
    }

    result([NSNumber numberWithBool:YES]);
}

- (void)setPage:(FlutterMethodCall *)call result:(FlutterResult)result {
    NSDictionary<NSString *, NSNumber *> *arguments = [call arguments];
    NSNumber *page = arguments[@"page"];
    NSUInteger pageIndex = page.unsignedLongValue;
    NSUInteger pageCount = [_pdfView.document pageCount];
    if (pageIndex >= pageCount) {
        result([FlutterError errorWithCode:@"INVALID_PAGE"
                                   message:@"Page index out of bounds"
                                   details:nil]);
        return;
    }

    [_pdfView goToPage:[_pdfView.document pageAtIndex:pageIndex]];
    result([NSNumber numberWithBool:YES]);
}

- (void)onUpdateSettings:(FlutterMethodCall *)call
                  result:(FlutterResult)result {
    result(nil);
}

- (void)setZoomLimits:(FlutterMethodCall *)call result:(FlutterResult)result {
    NSDictionary<NSString *, NSNumber *> *arguments = [call arguments];
    NSNumber *minZoom = arguments[@"minZoom"];
    NSNumber *maxZoom = arguments[@"maxZoom"];
    CGFloat fitScale = [self fitScaleForCurrentPolicy];
    if (!isfinite(fitScale) || fitScale <= 0) {
        fitScale = _pdfView.scaleFactorForSizeToFit;
    }
    float minScale = minZoom.floatValue * fitScale;
    float maxScale = maxZoom.floatValue * fitScale;
    _pdfView.minScaleFactor = minScale != 0.0 ? minScale : minZoom.floatValue;
    _pdfView.maxScaleFactor = maxScale != 0.0 ? maxScale : maxZoom.floatValue;
    _minScaleFactor = minZoom.floatValue;
    _maxScaleFactor = maxZoom.floatValue;
    result([NSNumber numberWithBool:YES]);
}

/// Resolves a Flutter-provided path or `file:` / `file://` URI to a file URL.
///
/// `URLWithString` returns nil for unescaped characters (spaces, etc.). Falling
/// back to `fileURLWithPath:` on the full `file://...` string would treat the
/// scheme as part of the filesystem path and fail to open the document.
- (NSURL *)pdfURLFromFilePath:(NSString *)filePath {
    if (![filePath hasPrefix:@"file:"]) {
        return [NSURL fileURLWithPath:filePath];
    }

    NSURL *url = [NSURL URLWithString:filePath];
    if (url != nil && url.isFileURL && url.path.length > 0) {
        return url;
    }

    // Strip file: / file:// and optional host, then treat the remainder as a path.
    NSString *path = filePath;
    if ([path hasPrefix:@"file://"]) {
        path = [path substringFromIndex:7];
    } else {
        path = [path substringFromIndex:5];
    }

    // file://localhost/Users/... → /Users/...
    if ([path hasPrefix:@"localhost/"]) {
        path = [path substringFromIndex:9];
    } else if (path.length > 0 && [path characterAtIndex:0] != '/') {
        // file://hostname/path → /path
        NSRange slash = [path rangeOfString:@"/"];
        if (slash.location != NSNotFound) {
            path = [path substringFromIndex:slash.location];
        }
    }

    NSString *decoded = [path stringByRemovingPercentEncoding];
    if (decoded != nil) {
        path = decoded;
    }
    return [NSURL fileURLWithPath:path];
}

- (void)handlePageChanged:(NSNotification *)notification {
    PDFDocument *document = _pdfView.document;
    PDFPage *currentPage = _pdfView.currentPage;
    if (document == nil || currentPage == nil) {
        return;
    }
    NSUInteger pageIndex = [document indexForPage:currentPage];
    if (pageIndex == NSNotFound) {
        return;
    }
    _hasSentInitialPage = YES;
    _currentPage = currentPage;
    _pageNo = (int)pageIndex + 1;
    [_controller
        invokeChannelMethod:@"onPageChanged"
                  arguments:@{
                      @"page" : [NSNumber numberWithUnsignedLong:pageIndex],
                      @"total" :
                          [NSNumber numberWithUnsignedLong:[document pageCount]]
                  }];
}

- (void)handleRenderCompleted:(NSNumber *)pages {
    [_controller invokeChannelMethod:@"onRender" arguments:@{@"pages" : pages}];
    if (!_didLoadComplete) {
        _didLoadComplete = YES;
        [_controller invokeChannelMethod:@"onLoadComplete"
                               arguments:@{@"pages" : pages}];
    }
    [self startObserving];
}

- (void)handleOnDraw {
    NSArray *position = [self calculatePosition];
    [_controller invokeChannelMethod:@"onDraw"
                           arguments:@{
                               @"pdfXOffset" : [position objectAtIndex:0],
                               @"pdfYOffset" : [position objectAtIndex:1],
                               @"pdfScale" : [NSNumber
                                   numberWithFloat:_pdfView.scaleFactor]
                           }];
}

- (void)PDFViewWillClickOnLink:(PDFView *)sender withURL:(NSURL *)url {
    if (!_preventLinkNavigation) {
        NSDictionary *options = @{};
        [[UIApplication sharedApplication] openURL:url
                                           options:options
                                 completionHandler:^(BOOL success) {
                                   if (success) {
                                       NSLog(@"URL opened successfully");
                                   } else {
                                       NSLog(@"Failed to open URL");
                                   }
                                 }];
    }
    [_controller invokeChannelMethod:@"onLinkHandler"
                           arguments:url.absoluteString];
}

- (void)onDoubleTap:(UITapGestureRecognizer *)recognizer {
    if (recognizer.state == UIGestureRecognizerStateEnded) {
        // Prevent zooming during scrolling
        if (_isScrolling) {
            return;
        }

        @try {
            CGFloat fitScale = [self fitScaleForCurrentPolicy];
            if (!isfinite(fitScale) || fitScale <= 0) {
                fitScale = _pdfView.scaleFactorForSizeToFit;
            }
            if (!isfinite(fitScale) || fitScale <= 0) {
                return;
            }
            BOOL atFit = fabs([_pdfView scaleFactor] - fitScale) <=
                         fmax(0.02, fitScale * 0.02);
            if (atFit) {
                CGPoint point = [recognizer locationInView:_pdfView];
                PDFPage *page = [_pdfView pageForPoint:point nearest:YES];
                if (page != nil) {
                    PDFPoint pdfPoint = [_pdfView convertPoint:point toPage:page];
                    PDFRect rect = [page boundsForBox:kPDFDisplayBoxMediaBox];
                    PDFDestination *destination = [[PDFDestination alloc]
                        initWithPage:page
                             atPoint:CGPointMake(
                                         pdfPoint.x - (rect.size.width / 4),
                                         pdfPoint.y + (rect.size.height / 4))];
                    [UIView
                        animateWithDuration:0.2
                                 animations:^{
                                   self->_pdfView.scaleFactor = fitScale * 2;
                                   [self->_pdfView goToDestination:destination];
                                 }];
                }
            } else {
                [UIView animateWithDuration:0.2
                                 animations:^{
                                   self->_pdfView.scaleFactor = fitScale;
                                   self->_lastFitScale = fitScale;
                                 }];
            }
        } @catch (NSException *exception) {
            NSLog(@"Warning: Double-tap zoom failed: %@", exception.reason);
        }
    }
}

#pragma mark - UIGestureRecognizerDelegate

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer
    shouldRecognizeSimultaneouslyWithGestureRecognizer:
        (UIGestureRecognizer *)otherGestureRecognizer {
    // Allow double-tap to work with scroll gestures. Also allow PDF scroll
    // gestures to compete with a parent Flutter ScrollView (#265) — the
    // Flutter-side EagerGestureRecognizer (if set) still owns claim priority.
    if ([gestureRecognizer isKindOfClass:[UITapGestureRecognizer class]]) {
        return YES;
    }
    if ([gestureRecognizer isKindOfClass:[UIPanGestureRecognizer class]] ||
        [otherGestureRecognizer isKindOfClass:[UIPanGestureRecognizer class]]) {
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
