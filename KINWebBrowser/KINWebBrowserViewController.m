//
//  KINWebBrowserViewController.m
//
//  KINWebBrowser
//
//  Created by David F. Muir V
//  dfmuir@gmail.com
//  Co-Founder & Engineer at Kinwa, Inc.
//  http://www.kinwa.co
//
//  The MIT License (MIT)
//
//  Copyright (c) 2014 David Muir
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy of
//  this software and associated documentation files (the "Software"), to deal in
//  the Software without restriction, including without limitation the rights to
//  use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
//  the Software, and to permit persons to whom the Software is furnished to do so,
//  subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
//  FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
//  COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
//  IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
//  CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//

#import "KINWebBrowserViewController.h"
#import "TUSafariActivity.h"
#import "ARChromeActivity.h"


//typedef void(^KINSnapshotWorkBlock)(void);

@interface KINSnapshotOperation : NSOperation
@property(copy, nullable) void (^workBlock)(void);
@end

@implementation KINSnapshotOperation {
    BOOL _work_done;
}
- (void)main {
    if (self.workBlock)
        self.workBlock();

    [self willChangeValueForKey:@"isFinished"];
    _work_done = YES;
    [self didChangeValueForKey:@"isFinished"];
}

- (BOOL)isFinished {
    return _work_done;
}
@end

#pragma mark - KINWebBrowserSnapshotContext

@interface KINWebBrowserSnapshotContext () {
    NSInteger _index;
    NSInteger _pages;
    BOOL _cancelled;
    NSMutableArray *_snapshots;
}

@property(nonatomic, assign) BOOL initialUserInteractionEnabled;
@property(nonatomic, assign) BOOL initialScrollEnabled;
@property(nonatomic, assign) CGRect initialWebViewFrame;
@property(nonatomic, assign) CGSize initialContentSize;
@property(nonatomic, assign) CGPoint initialContentOffset;
@property(nonatomic, assign) CGFloat snapshotHeight;
@property(nonatomic, copy) KINBrowserSnapshotProgressBlock progressBlock;
@property(nonatomic, copy) KINBrowserSnapshotCompletedBlock completedBlock;
@property(nonatomic, getter=pages, setter=setTotalPages:) NSInteger total_pages;
@property(nonatomic, getter=index, setter=setCurrentIndex:) NSInteger current_index;
@property(nonatomic, assign) KINBrowserSnapshotOption option;
@property(nonatomic, assign) CGFloat compression;
@end

@implementation KINWebBrowserSnapshotContext
- (instancetype)init {
    self = [super init];
    if (self) {
        _snapshots = [NSMutableArray array];
        _compression = 1.0;
    }

    return self;
}

- (void)dealloc {
    for (NSURL *file in _snapshots) {
        NSError *error;
        NSFileManager *fileManager = [NSFileManager defaultManager];
        if (![fileManager removeItemAtURL:file error:&error]) {
            NSLog(@"unable to remove screenshot at path: %@", [file path]);
        }
    }
}

- (NSData *)_convertImageToPDF:(UIImage *)image withHorizontalResolution:(CGFloat)horzRes verticalResolution:(CGFloat)vertRes {
    if ((horzRes <= 0) || (vertRes <= 0)) {
        return nil;
    }

    CGFloat pageWidth = image.size.width * image.scale * 72 / horzRes;
    CGFloat pageHeight = image.size.height * image.scale * 72 / vertRes;

    NSMutableData *pdfFile = [[NSMutableData alloc] init];
    CGDataConsumerRef pdfConsumer = CGDataConsumerCreateWithCFData((__bridge CFMutableDataRef) pdfFile);
    // The page size matches the image, no white borders.
    CGRect mediaBox = CGRectMake(0, 0, pageWidth, pageHeight);
    CGContextRef pdfContext = CGPDFContextCreate(pdfConsumer, &mediaBox, NULL);

    CGContextBeginPage(pdfContext, &mediaBox);
    switch (image.imageOrientation) {
        case UIImageOrientationDown:
            CGContextTranslateCTM(pdfContext, pageWidth, pageHeight);
            CGContextScaleCTM(pdfContext, -1, -1);
            break;

        case UIImageOrientationLeft:
            mediaBox.size.width = pageHeight;
            mediaBox.size.height = pageWidth;
            CGContextTranslateCTM(pdfContext, pageWidth, 0);
            CGContextRotateCTM(pdfContext, M_PI / 2);
            break;

        case UIImageOrientationRight:
            mediaBox.size.width = pageHeight;
            mediaBox.size.height = pageWidth;
            CGContextTranslateCTM(pdfContext, 0, pageHeight);
            CGContextRotateCTM(pdfContext, -M_PI / 2);
            break;

        case UIImageOrientationUp:
        default:
            break;

    }
    CGContextDrawImage(pdfContext, mediaBox, [image CGImage]);
    CGContextEndPage(pdfContext);
    CGContextRelease(pdfContext);
    CGDataConsumerRelease(pdfConsumer);

    return pdfFile;
}

- (NSData *)pdf {
    return [self _convertImageToPDF:[self snapshot] withHorizontalResolution:300 verticalResolution:300];
}

- (UIImage *)snapshot {
    UIImage *finalImage = nil;
    CGSize size = CGSizeMake(self.initialWebViewFrame.size.width, self.initialWebViewFrame.size.height * self.pages);
    CGFloat y_offset = 0.0;

    UIGraphicsBeginImageContext(size);
    for (NSURL *file in self.snapshots) {
        @autoreleasepool {
            UIImage *image = [UIImage imageWithData:[NSData dataWithContentsOfURL:file]];
            [image drawInRect:CGRectMake(0, y_offset, size.width, image.size.height)];
            y_offset += image.size.height;
        }
    }
    finalImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return finalImage;
}

- (void)addScreenshot:(NSURL *)url {
    [_snapshots addObject:url];
}

- (NSArray<NSURL *> *)snapshots {
    return _snapshots;
}

- (void)setCurrentIndex:(NSInteger)i {
    _index = i;
}

- (void)setTotalPages:(NSInteger)i {
    _pages = i;
}

- (NSInteger)index {
    return _index;
}

- (NSInteger)pages {
    return _pages;
}

- (BOOL)cancelled {
    return _cancelled;
}

- (void)cancel {
    _cancelled = YES;
    NSError *error =
            [NSError errorWithDomain:@"KINWebBrowser" code:100 userInfo:@{@"message" : @"snapshot was cancelled"}];
    if (self.completedBlock)
        self.completedBlock(nil, error, NO);
}

- (CGFloat)compression {
    if ((_option & KINBrowserSnapshotOptionCompressionHigh) == KINBrowserSnapshotOptionCompressionHigh) {
        _compression = 0.3;
    } else if ((_option & KINBrowserSnapshotOptionCompressionHigh) == KINBrowserSnapshotOptionCompressionMedium) {
        _compression = 0.5;
    } else if ((_option & KINBrowserSnapshotOptionCompressionHigh) == KINBrowserSnapshotOptionCompressionLow) {
        _compression = 0.8;
    } else {
        _compression = 1.0;
    }

    return _compression;
}
@end

#pragma mark - UIWebView (KINWebBrowserWebViewMethods)

@implementation UIWebView (KINWebBrowserWebViewMethods)
- (NSURL *)URL {
    return self.request.URL;
}

- (void)loadURLRequest:(NSURLRequest *_Nonnull)request {
    [self loadRequest:request];
}

- (void)evaluateJavaScript:(NSString *)script then:(void (^ __nullable)(__nullable id, NSError *__nullable error))then {
    __block NSString *value = nil;
    __block NSError *error = nil;

    if ([NSThread isMainThread]) {
        value = [self stringByEvaluatingJavaScriptFromString:script];
        error = value ? nil : [NSError errorWithDomain:@"kinwebbrowser" code:1776 userInfo:@{script : script}];
    } else
        dispatch_sync(dispatch_get_main_queue(), ^{
            value = [self stringByEvaluatingJavaScriptFromString:script];
            error = value ? nil : [NSError errorWithDomain:@"kinwebbrowser" code:1776 userInfo:@{script : script}];
        });

    if (then)
        then(value, error);
}

- (NSString *)title {
    __block NSString *value = nil;//[self stringByEvaluatingJavaScriptFromString:@"document.title"];
    [self evaluateJavaScript:@"document.title" then:^(id o, NSError *error) {
        value = o;
    }];

    return value;
}

- (void)refresh {
    [self reload];
}
@end

@implementation WKWebView (KINWebBrowserWebViewMethods)
- (void)evaluateJavaScript:(NSString *)script then:(void (^ __nullable)(__nullable id, NSError *__nullable error))then {
    [self evaluateJavaScript:script completionHandler:then];
}

- (void)loadURLRequest:(NSURLRequest *_Nonnull)request {
    [self loadRequest:request];
}

- (void)refresh {
    [self reload];
}
@end


static void *KINWebBrowserContext = &KINWebBrowserContext;

@interface KINWebBrowserViewController () <UIAlertViewDelegate>

@property(nonatomic, assign) BOOL previousNavigationControllerToolbarHidden, previousNavigationControllerNavigationBarHidden;

@property(nonatomic, strong) NSTimer *fakeProgressTimer;
@property(nonatomic, strong) UIPopoverController *actionPopoverController;
@property(nonatomic, assign) BOOL uiWebViewIsLoading;
@property(nonatomic, strong) NSURL *uiWebViewCurrentURL;
@property(nonatomic, strong) NSURL *uiWebViewLoadedURL;
@property(nonatomic, strong) NSURL *URLToLaunchWithPermission;
@property(nonatomic, strong) UIAlertView *externalAppPermissionAlertView;
@property(nonatomic, strong) WKWebViewConfiguration *configuration;
@property(nonatomic, strong) NSMutableDictionary *requestBalance;
@property(nonatomic, strong) NSMutableDictionary *loadedURLS;
@property(nonatomic, strong) NSArray *defaultBrowserToolbarItems;
@property(nonatomic, assign) BOOL configuredAutolayout;
@property(nonatomic, retain) NSMutableArray *progressViewConstraints;
@property(nonatomic, retain) NSMutableArray *webViewConstraints;
@property(nonatomic, retain) NSMutableArray *headerViewConstraints;

@property(nonatomic, retain) NSLayoutConstraint *browserViewBottomConstraint;
@property(nonatomic, retain) NSLayoutConstraint *browserViewHeightConstraint;

/*
 *    progress: (KINBrowserSnapshotProgressBlock) progress
                           completed: (KINBrowserSnapshotCompletedBlock) completedBlock {
 */


- (NSArray *)loadWebBrowserToolbarItems;
@end


@implementation KINWebBrowserViewController {
    id <KINWebBrowserAddressBarAbility> _addressBar;
    BOOL _isActiveBrowser;
}

#pragma mark - Static Initializers

@synthesize browserHeaderView = _browserHeaderView;

- (UIView <KINWebBrowserView> *)webView {
    UIView <KINWebBrowserView> *webView = (self.wkWebView ? self.wkWebView : self.uiWebView);
    return webView;
}

+ (KINWebBrowserViewController *)webBrowser {
    KINWebBrowserViewController *webBrowserViewController =
            [[KINWebBrowserViewController alloc] initWithNibName:nil bundle:nil];
    return webBrowserViewController;
}

+ (KINWebBrowserViewController *)webBrowserWithConfiguration:(WKWebViewConfiguration *)configuration {
    KINWebBrowserViewController *webBrowserViewController = [[self alloc] initWithConfiguration:configuration];
    return webBrowserViewController;
}

+ (UINavigationController *)navigationControllerWithWebBrowser {
    KINWebBrowserViewController *webBrowserViewController = [[self alloc] initWithNibName:nil bundle:nil];
    return [KINWebBrowserViewController navigationControllerWithBrowser:webBrowserViewController];
}

+ (UINavigationController *)navigationControllerWithWebBrowserWithConfiguration:(WKWebViewConfiguration *)configuration {
    KINWebBrowserViewController *webBrowserViewController = [[self alloc] initWithConfiguration:configuration];
    return [KINWebBrowserViewController navigationControllerWithBrowser:webBrowserViewController];
}

+ (UINavigationController *)navigationControllerWithBrowser:(KINWebBrowserViewController *)webBrowser {
    UIBarButtonItem *doneButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:webBrowser action:@selector(doneButtonPressed:)];
    [webBrowser.navigationItem setRightBarButtonItem:doneButton];

    UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:webBrowser];
    return navigationController;
}

#pragma mark - Initializers

- (void)setup {
    [self setupToolbarItems];
    self.requestBalance = [NSMutableDictionary dictionary];
    self.loadedURLS = [NSMutableDictionary dictionary];
    // self.configuration = configuration;
    self.actionButtonHidden = NO;
    self.showsURLInNavigationBar = NO;
    self.showsPageTitleInNavigationBar = YES;
    self.externalAppPermissionAlertView = [[UIAlertView alloc] initWithTitle:@"Leave this app?"
                                                                     message:@"This web page is trying to open an outside app. Are you sure you want to open it?"
                                                                    delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"Open App", nil];

    self.progressViewConstraints = [NSMutableArray array];
    self.headerViewConstraints = [NSMutableArray array];
    self.webViewConstraints = [NSMutableArray array];

    _isActiveBrowser = NO;
}

- (void)setupWebView {
    if (self.wkWebView || self.uiWebView)
        return;
    NSString *version = [UIDevice currentDevice].systemVersion;

    if ([version floatValue] < 8.0f || // note: Defaults to WKWebview if no browserClass is specified, unless < ver 8.0
            (self.browserViewClass && self.browserViewClass == [UIWebView class])) {
        self.uiWebView = [[UIWebView alloc] init];
    } else {
        self.wkWebView = [[WKWebView alloc] init];
    }
}

- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    if (self = [super initWithNibName:nil bundle:nil]) {
        [self setup];
    }
    return self;
}

- (id)initWithConfiguration:(WKWebViewConfiguration *)configuration {
    if (self = [super initWithNibName:nil bundle:nil]) {
        self.browserViewClass = [WKWebView class];
        self.configuration = configuration;
        [self setup];
    }
    return self;
}

#pragma mark - View Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setupWebView];

    self.previousNavigationControllerToolbarHidden = self.navigationController.toolbarHidden;
    self.previousNavigationControllerNavigationBarHidden = self.navigationController.navigationBarHidden;
    self.automaticallyAdjustsScrollViewInsets = NO;
    if (self.wkWebView) {
        [self.wkWebView setFrame:self.view.bounds];
        [self.wkWebView setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight];
        [self.wkWebView setNavigationDelegate:self];
        [self.wkWebView setUIDelegate:self];
        [self.wkWebView setMultipleTouchEnabled:YES];
        [self.wkWebView setAutoresizesSubviews:YES];
        [self.wkWebView.scrollView setAlwaysBounceVertical:YES];
        [self.view addSubview:self.wkWebView];
        [self.wkWebView addObserver:self
                         forKeyPath:NSStringFromSelector(@selector(estimatedProgress))
                            options:0 context:KINWebBrowserContext];
    } else if (self.uiWebView) {
        [self.uiWebView setFrame:self.view.bounds];
        [self.uiWebView setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight];
        [self.uiWebView setDelegate:self];
        [self.uiWebView setMultipleTouchEnabled:YES];
        [self.uiWebView setAutoresizesSubviews:YES];
        [self.uiWebView setScalesPageToFit:YES];
        [self.uiWebView.scrollView setAlwaysBounceVertical:YES];
        [self.view addSubview:self.uiWebView];
    }

    self.progressView = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
    [self.progressView setTrackTintColor:[UIColor colorWithWhite:1.0f alpha:0.0f]];
    [self.view addSubview:self.progressView];
    [self.view setNeedsUpdateConstraints];
}

- (void)resetViewConstraints {
    self.configuredAutolayout = NO;
    [self.view setNeedsUpdateConstraints];
}

- (void)updateViewConstraints {
    [super updateViewConstraints];


    if (!self.configuredAutolayout) {
        UIView *topView = self.progressView;

        if ([self.progressViewConstraints count] > 0) {
            [self.view removeConstraints:self.progressViewConstraints];
            [self.progressViewConstraints removeAllObjects];
        }

        if ([self.webViewConstraints count] > 0) {
            [self.view removeConstraints:self.webViewConstraints];
            [self.webViewConstraints removeAllObjects];
        }
        if ([self.headerViewConstraints count] > 0) {
            [self.view removeConstraints:self.headerViewConstraints];
            [self.headerViewConstraints removeAllObjects];
        }

        self.progressView.translatesAutoresizingMaskIntoConstraints = NO;

        NSLayoutConstraint *progressViewRightConstraint =
                [NSLayoutConstraint constraintWithItem:self.progressView
                                             attribute:NSLayoutAttributeRight
                                             relatedBy:NSLayoutRelationEqual
                                                toItem:self.view
                                             attribute:NSLayoutAttributeRight multiplier:1 constant:0];
        NSLayoutConstraint *progressViewLeftConstraint =
                [NSLayoutConstraint constraintWithItem:self.progressView
                                             attribute:NSLayoutAttributeLeft
                                             relatedBy:NSLayoutRelationEqual
                                                toItem:self.view
                                             attribute:NSLayoutAttributeLeft multiplier:1 constant:0];
        NSLayoutConstraint *progressViewTopConstraint =
                [NSLayoutConstraint constraintWithItem:self.progressView
                                             attribute:NSLayoutAttributeTop
                                             relatedBy:NSLayoutRelationEqual
                                                toItem:self.topLayoutGuide
                                             attribute:NSLayoutAttributeBottom multiplier:1 constant:0];
        NSLayoutConstraint *progressViewWidthConstraint =
                [NSLayoutConstraint constraintWithItem:self.progressView
                                             attribute:NSLayoutAttributeWidth
                                             relatedBy:NSLayoutRelationEqual
                                                toItem:self.view
                                             attribute:NSLayoutAttributeWidth multiplier:1 constant:0];

        [self.progressViewConstraints addObjectsFromArray:
                @[
                        progressViewLeftConstraint,
                        progressViewTopConstraint,
                        progressViewWidthConstraint
                ]
        ];
        [self.view addConstraints:self.progressViewConstraints];

        if (self.browserHeaderView) {
            topView = self.browserHeaderView;
            self.browserHeaderView.translatesAutoresizingMaskIntoConstraints = NO;
            NSLayoutConstraint *headerViewRightConstraint =
                    [NSLayoutConstraint constraintWithItem:self.browserHeaderView
                                                 attribute:NSLayoutAttributeRight
                                                 relatedBy:NSLayoutRelationEqual
                                                    toItem:self.view
                                                 attribute:NSLayoutAttributeRight multiplier:1 constant:0];

            NSLayoutConstraint *headerViewTopConstraint =
                    [NSLayoutConstraint constraintWithItem:self.browserHeaderView
                                                 attribute:NSLayoutAttributeTop
                                                 relatedBy:NSLayoutRelationEqual
                                                    toItem:self.progressView
                                                 attribute:NSLayoutAttributeBottom multiplier:1 constant:0];

            NSLayoutConstraint *headerViewWidthConstraint =
                    [NSLayoutConstraint constraintWithItem:self.browserHeaderView
                                                 attribute:NSLayoutAttributeWidth
                                                 relatedBy:NSLayoutRelationEqual
                                                    toItem:self.view
                                                 attribute:NSLayoutAttributeWidth multiplier:1 constant:0];
            [self.headerViewConstraints addObjectsFromArray:
                    @[headerViewRightConstraint, headerViewTopConstraint, headerViewWidthConstraint]
            ];

            [self.view addConstraints:self.headerViewConstraints];
        }

        NSLayoutConstraint *browserViewRightConstraint =
                [NSLayoutConstraint constraintWithItem:self.webView
                                             attribute:NSLayoutAttributeRight
                                             relatedBy:NSLayoutRelationEqual
                                                toItem:self.view
                                             attribute:NSLayoutAttributeRight multiplier:1 constant:0];

        NSLayoutConstraint *browserViewTopConstraint =
                [NSLayoutConstraint constraintWithItem:self.webView
                                             attribute:NSLayoutAttributeTop
                                             relatedBy:NSLayoutRelationEqual
                                                toItem:topView
                                             attribute:NSLayoutAttributeBottom multiplier:1 constant:0];

        NSLayoutConstraint *browserViewWidthConstraint =
                [NSLayoutConstraint constraintWithItem:self.webView
                                             attribute:NSLayoutAttributeWidth
                                             relatedBy:NSLayoutRelationEqual
                                                toItem:self.view
                                             attribute:NSLayoutAttributeWidth multiplier:1 constant:0];

        self.browserViewBottomConstraint =
                [NSLayoutConstraint constraintWithItem:self.webView
                                             attribute:NSLayoutAttributeBottom
                                             relatedBy:NSLayoutRelationEqual
                                                toItem:self.bottomLayoutGuide
                                             attribute:NSLayoutAttributeTop multiplier:1 constant:0];

        self.browserViewBottomConstraint.priority = UILayoutPriorityDefaultHigh;

        CGSize webViewContentSize = self.webView.scrollView.contentSize;

        self.browserViewHeightConstraint =
                [NSLayoutConstraint constraintWithItem:self.webView
                                             attribute:NSLayoutAttributeHeight
                                             relatedBy:NSLayoutRelationEqual
                                                toItem:nil
                                             attribute:NSLayoutAttributeNotAnAttribute multiplier:1 constant:webViewContentSize.height];

        self.browserViewHeightConstraint.priority = UILayoutPriorityDefaultLow;
        //browserViewHeightConstraint.active

        self.webView.translatesAutoresizingMaskIntoConstraints = NO;

        [self.webViewConstraints addObjectsFromArray:
                @[browserViewRightConstraint, browserViewTopConstraint, browserViewWidthConstraint,
                        self.browserViewBottomConstraint, self.browserViewHeightConstraint] //browserViewHeightConstraint
        ];

        [self.view addConstraints:self.webViewConstraints];
        self.configuredAutolayout = YES;
    }
}

- (void)enableSnapshot:(BOOL)truth {

    if (truth) {
        self.browserViewBottomConstraint.active = NO;
        self.browserViewHeightConstraint.constant = self.webView.scrollView.contentSize.height;

    } else {
        self.browserViewBottomConstraint.active = YES;
        self.browserViewHeightConstraint.constant = self.webView.scrollView.contentSize.height;
    }
}


- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    _isActiveBrowser = YES;

    //  [self.uiWebView setDelegate:self]; //oroginal code set viewDidDisappar delegates to nil, but not reassign upon viewWillAppear?
    //  [self.wkWebView setNavigationDelegate:self];
    //   [self.wkWebView setUIDelegate:self];

    [self.navigationController setNavigationBarHidden:NO animated:YES];

    if (!self.hidesBottomBarWhenPushed)
        [self.navigationController setToolbarHidden:NO animated:YES];
    //  [self.navigationController.navigationBar addSubview:self.progressView]; //todo: perhaps make visiable?
    [self updateToolbarState];
}

- (NSArray *)loadWebBrowserToolbarItems {

    if ([self.delegate conformsToProtocol:@protocol(KINWebBrowserDelegate)] &&
            [self.delegate respondsToSelector:@selector(webBrowser:toolbarItems:)]) {
        return [self.delegate webBrowser:self toolbarItems:self.defaultBrowserToolbarItems];
    }

    if ([self.delegate conformsToProtocol:@protocol(KINWebBrowserDelegate)] &&
            [self.delegate respondsToSelector:@selector(webBrowserToolbarItems)]) {
        return [self.delegate webBrowserToolbarItems];
    }

    return self.defaultBrowserToolbarItems;
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    _isActiveBrowser = NO;
    [self.navigationController setNavigationBarHidden:self.previousNavigationControllerNavigationBarHidden animated:animated];
    [self.navigationController setToolbarHidden:self.previousNavigationControllerToolbarHidden animated:animated];
    [self stopLoading]; // no need to continue loading if will become invisible. Hopefully deleages are called bore they are assigned nill
}


- (void)setBrowserHeaderView:(UIView *)browserHeaderView {
    if (browserHeaderView != _browserHeaderView) {
        [_browserHeaderView removeFromSuperview];
        if (browserHeaderView) {
            [browserHeaderView setAutoresizingMask:UIViewAutoresizingFlexibleWidth];

            [self.view addSubview:browserHeaderView];
        }
        [self.view setNeedsLayout];
        [self resetViewConstraints];
    }

    _browserHeaderView = browserHeaderView;
    if ([_browserHeaderView conformsToProtocol:@protocol(KINWebBrowserAddressBarAbility)])
        self.addressBar = (id <KINWebBrowserAddressBarAbility>) _browserHeaderView;
}


#pragma mark - Public Interface

- (void)loadRequest:(NSURLRequest *)request {
    [self stopLoading]; //todo: if WebView not loaded, load it.
    if (self.wkWebView) {
        [self.wkWebView loadRequest:request];
    } else if (self.uiWebView) {
        self.uiWebViewCurrentURL = request.URL;
        self.uiWebViewLoadedURL = nil;
        [self.uiWebView loadRequest:request];
    }
}

- (void)goBack {
    [self stopLoading];
    if (self.wkWebView) {
        [self.wkWebView goBack];
    } else if (self.uiWebView) {
        [self.uiWebView goBack];
    }
}

- (void)goForward {
    [self stopLoading];
    if (self.wkWebView) {
        [self.wkWebView goForward];
    } else if (self.uiWebView) {
        [self.uiWebView goForward];
    }
}

- (void)reload {
    [self stopLoading];
    if (self.wkWebView) {
        [self.wkWebView reload];
    } else if (self.uiWebView) {
        [self.uiWebView reload];
    }
}

- (void)stopLoading {
    [self setupWebView]; //note: every call uses this function, so checks for init here. will move eventually
    self.uiWebViewIsLoading = NO;
    self.uiWebViewLoadedURL = nil;
    [self.requestBalance removeAllObjects];
    [self.loadedURLS removeAllObjects];
    [self.webView stopLoading];
    [self updateToolbarState];
}

- (void)loadURL:(NSURL *)URL {
    [self loadRequest:[NSURLRequest requestWithURL:URL]];
}

- (void)loadURLString:(NSString *)URLString {
    NSURL *URL = [NSURL URLWithString:URLString];
    [self loadURL:URL];
}

- (void)loadHTMLString:(NSString *)HTMLString {
    [self stopLoading];
    if (self.wkWebView) {
        [self.wkWebView loadHTMLString:HTMLString baseURL:nil];
    }
    else if (self.uiWebView) {
        [self.uiWebView loadHTMLString:HTMLString baseURL:nil];
    }
}

- (NSURL *)URL {
    if (self.wkWebView) {
        return self.wkWebView.URL;
    } else if (self.uiWebView) {
        return self.uiWebViewLoadedURL ? self.uiWebViewLoadedURL : self.uiWebViewCurrentURL;
    }
}

- (BOOL)isLoading {
    if (self.wkWebView) {
        return self.wkWebView.loading;
    } else if (self.uiWebView) {
        NSNumber *urlLoaded = self.loadedURLS[self.URL.absoluteString];
        NSNumber *urlBalance = self.requestBalance[self.URL.absoluteString];

        if (urlBalance)
            return [urlBalance integerValue] > 0;

        if (urlLoaded)
            return ![urlLoaded boolValue];
        return self.uiWebViewIsLoading;
    }
}

- (void)setTintColor:(UIColor *)tintColor {
    _tintColor = tintColor;
    [self.progressView setTintColor:tintColor];
    [self.navigationController.navigationBar setTintColor:tintColor];
    [self.navigationController.toolbar setTintColor:tintColor];
}

- (void)setBarTintColor:(UIColor *)barTintColor {
    _barTintColor = barTintColor;
    [self.navigationController.navigationBar setBarTintColor:barTintColor];
    [self.navigationController.toolbar setBarTintColor:barTintColor];
}

- (void)setActionButtonHidden:(BOOL)actionButtonHidden {
    _actionButtonHidden = actionButtonHidden;
    [self updateToolbarState];
}

#pragma mark - Depricated properties

- (UIBarButtonItem *)actionButton {
    return self.browserActionButton;
}

- (void)setActionButton:(UIBarButtonItem *)actionButton {
    self.browserActionButton = actionButton;
}


#pragma mark - UIWebViewDelegate

- (void)webViewHistoryDidChange:(NSNotification *)notification { //todo: depreciate
    NSLog(@"webViewHistoryDidChange");
    return;
}

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType {
    if (webView == self.uiWebView) {
        NSURL *url = webView.URL; //webView.URL;
        NSURL *requestUrl = webView.request.URL;
        NSURL *mainDocumentURL = webView.request.mainDocumentURL;
        NSLog(@"+webView:shouldStartLoadWithRequest: loading=%@ (%@)\n\turl = %@\n\trequestUrl = %@\n\tmainDocument=%@", @(webView.isLoading), self.requestBalance[url.absoluteString], url, requestUrl, mainDocumentURL);


        if ([self.delegate respondsToSelector:@selector(webBrowser:shouldStartLoadWithRequest:navigationType:)]) {
            KINBrowserNavigationType browserNavigationType;

            switch (navigationType) {
                case UIWebViewNavigationTypeLinkClicked:
                    browserNavigationType = KINBrowserNavigationTypeLinkClicked;

                    break;
                case UIWebViewNavigationTypeFormSubmitted:
                    browserNavigationType = KINBrowserNavigationTypeFormSubmitted;
                    break;
                case UIWebViewNavigationTypeBackForward:
                    browserNavigationType = KINBrowserNavigationTypeBackForward;
                    break;
                case UIWebViewNavigationTypeReload:
                    browserNavigationType = KINBrowserNavigationTypeReload;
                    break;
                case UIWebViewNavigationTypeFormResubmitted:
                    browserNavigationType = KINBrowserNavigationTypeFormResubmitted;
                    break;
                case UIWebViewNavigationTypeOther:
                    browserNavigationType = KINBrowserNavigationTypeOther;
                    break;
                default:
                    browserNavigationType = KINBrowserNavigationTypeOther;
                    break;
            }

            if (![self.delegate webBrowser:self shouldStartLoadWithRequest:request navigationType:browserNavigationType])
                return NO;
        }

        switch (navigationType) { //todo: refactor
            case UIWebViewNavigationTypeLinkClicked:
            case UIWebViewNavigationTypeBackForward:
            case UIWebViewNavigationTypeReload:
                self.uiWebViewCurrentURL = webView.URL;
                break;
        }

        // if(![self externalAppRequiredToOpenURL:request.URL]) {
        // self.uiWebViewCurrentURL = request.URL;
        self.uiWebViewIsLoading = YES;
        [self updateToolbarState];
        [self fakeProgressViewStartLoading];
        return YES;
        /*  } else {
              [self launchExternalAppWithURL:request.URL];
              return NO;
          } */
    }
    return NO;
}

- (void)webViewDidStartLoad:(UIWebView *_Nonnull)webView {
    if (webView == self.uiWebView) {
        NSURL *url = webView.URL; //webView.URL;
        NSURL *requestUrl = webView.request.URL;
        NSURL *mainDocumentURL = webView.request.mainDocumentURL;
        [self incrementURL:requestUrl balanceBy:0]; //resets count to 0 in case it was cancelled

        NSLog(@"+webViewDidStartLoad: loading=%@ (%@)\n\turl = %@\n\trequestUrl = %@\n\tmainDocument=%@", @(webView.isLoading), self.requestBalance[url.absoluteString], url, requestUrl, mainDocumentURL);

        if ([self.delegate respondsToSelector:@selector(webBrowser:didStartLoadingURL:)]) {
            [self.delegate webBrowser:self didStartLoadingURL:webView.request.URL];
        }
    }
}

- (void)webViewDidFinishLoad:(UIWebView *)webView {
    if (webView == self.uiWebView) {

        NSURL *url = webView.URL; //webView.URL;
        NSURL *requestUrl = webView.request.URL;
        NSURL *mainDocumentURL = webView.request.mainDocumentURL;
        [self incrementURL:requestUrl balanceBy:-1];
        NSLog(@"-webViewDidFinishLoad: loading=%@ (%@)\n\turl = %@\n\trequestUrl = %@\n\tmainDocument=%@", @(webView.isLoading), self.requestBalance[url.absoluteString], url, requestUrl, mainDocumentURL);

        if (!self.uiWebView.isLoading) {
            self.uiWebViewLoadedURL = webView.URL;
            self.uiWebViewIsLoading = NO;
            self.loadedURLS[webView.URL.absoluteString] = [NSNumber numberWithBool:YES];
            [self fakeProgressBarStopLoading];
        }

        // if(!self.isLoading)
        [self updateToolbarState];

        if ([self.delegate respondsToSelector:@selector(webBrowser:didFinishLoadingURL:)]) {
            [self.delegate webBrowser:self didFinishLoadingURL:self.uiWebView.request.URL];
        }
    }
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error {
    if (webView == self.uiWebView) {
        NSURL *url = webView.URL; //webView.URL;
        NSURL *requestUrl = webView.request.URL;
        NSURL *mainDocumentURL = webView.request.mainDocumentURL;
        [self incrementURL:url balanceBy:-1];

        NSLog(@"-didFailLoadWithError: loading=%@ (%@)\n\turl = %@\n\trequestUrl = %@\n\tmainDocument=%@", @(webView.isLoading), self.requestBalance[url.absoluteString], url, requestUrl, mainDocumentURL);

        if (!self.uiWebView.isLoading) {
            self.uiWebViewIsLoading = NO;
            [self fakeProgressBarStopLoading];
        }

        [self updateToolbarState];

        if ([self.delegate respondsToSelector:@selector(webBrowser:didFailToLoadURL:error:)]) {
            [self.delegate webBrowser:self didFailToLoadURL:self.uiWebView.request.URL error:error];
        }
    }
}

#pragma mark - WKNavigationDelegate

- (void)webView:(WKWebView *)webView didStartProvisionalNavigation:(WKNavigation *)navigation {
    if (webView == self.wkWebView) {
        [self updateToolbarState];

        if ([self.delegate respondsToSelector:@selector(webBrowser:didStartLoadingURL:)]) {
            [self.delegate webBrowser:self didStartLoadingURL:self.wkWebView.URL];
        }
    }
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    if (webView == self.wkWebView) {
        [self updateToolbarState];

        if ([self.delegate respondsToSelector:@selector(webBrowser:didFinishLoadingURL:)]) {
            [self.delegate webBrowser:self didFinishLoadingURL:self.wkWebView.URL];
        }
    }
}

- (void)webView:(WKWebView *)webView didFailProvisionalNavigation:(WKNavigation *)navigation
      withError:(NSError *)error {
    if (webView == self.wkWebView) {

        [self updateToolbarState];
        if ([self.delegate respondsToSelector:@selector(webBrowser:didFailToLoadURL:error:)]) {
            [self.delegate webBrowser:self didFailToLoadURL:self.wkWebView.URL error:error];
        }
    }
}

- (void)webView:(WKWebView *)webView didFailNavigation:(WKNavigation *)navigation
      withError:(NSError *)error {
    if (webView == self.wkWebView) {
        [self updateToolbarState];
        if ([self.delegate respondsToSelector:@selector(webBrowser:didFailToLoadURL:error:)]) {
            [self.delegate webBrowser:self didFailToLoadURL:self.wkWebView.URL error:error];
        }
    }
}

- (void)webView:(WKWebView *_Nonnull)webView didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *_Nonnull)challenge completionHandler:(void (^ _Nonnull)(NSURLSessionAuthChallengeDisposition disposition, NSURLCredential *_Nullable credential))completionHandler {
//NSURLSessionAuthChallengeUseCredential
    NSString *url = webView.URL.absoluteString;
    NSURLCredential *cred = [[NSURLCredential alloc] initWithTrust:challenge.protectionSpace.serverTrust];
    completionHandler(NSURLSessionAuthChallengeUseCredential, cred);
}

- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
    if (webView == self.wkWebView) {

        if ([self.delegate respondsToSelector:@selector(webBrowser:shouldStartLoadWithRequest:navigationType:)]) {
            KINBrowserNavigationType browserNavigationType = KINBrowserNavigationTypeOther;
            switch (navigationAction.navigationType) {
                case WKNavigationTypeLinkActivated:
                    browserNavigationType = KINBrowserNavigationTypeLinkClicked;
                    break;
                case WKNavigationTypeFormSubmitted:
                    browserNavigationType = KINBrowserNavigationTypeFormSubmitted;
                    break;
                case WKNavigationTypeBackForward:
                    browserNavigationType = KINBrowserNavigationTypeBackForward;
                    break;
                case WKNavigationTypeReload:
                    browserNavigationType = KINBrowserNavigationTypeReload;
                    break;
                case WKNavigationTypeFormResubmitted:
                    browserNavigationType = KINBrowserNavigationTypeFormResubmitted;
                    break;
                case WKNavigationTypeOther:
                    browserNavigationType = KINBrowserNavigationTypeOther;
                    break;
                default:
                    browserNavigationType = KINBrowserNavigationTypeOther;
                    break;
            }

            if (![self.delegate webBrowser:self shouldStartLoadWithRequest:navigationAction.request
                            navigationType:browserNavigationType]) {
                decisionHandler(WKNavigationActionPolicyCancel);
                return;
            }
        }
/* //todo: reintroduce this, rather annonying functionality
        NSURL *URL = navigationAction.request.URL;
        if(![self externalAppRequiredToOpenURL:URL]) {
            if(!navigationAction.targetFrame) {
                [self loadURL:URL];
                decisionHandler(WKNavigationActionPolicyCancel);
                return;
            }
        }
        else if([[UIApplication sharedApplication] canOpenURL:URL]) {
            [self launchExternalAppWithURL:URL];
            decisionHandler(WKNavigationActionPolicyCancel);
            return;
        } */
    }
    decisionHandler(WKNavigationActionPolicyAllow);
}

#pragma mark - WKUIDelegate

- (WKWebView *)webView:(WKWebView *)webView createWebViewWithConfiguration:(WKWebViewConfiguration *)configuration forNavigationAction:(WKNavigationAction *)navigationAction windowFeatures:(WKWindowFeatures *)windowFeatures {
    if (!navigationAction.targetFrame.isMainFrame) {
        [webView loadRequest:navigationAction.request];
    }
    return nil;
}

#pragma mark - AddressBArNotifications

- (void)processAddressBarNotification:(NSNotification *)notification {
    if (!_isActiveBrowser)
        return;

    NSNumber *actionNumber = notification.userInfo[@"action"];
    KINAddressBarAction action = (KINAddressBarAction) [actionNumber integerValue];
    NSString *text = [notification.userInfo[@"text"] isKindOfClass:[NSString class]] ? notification.userInfo[@"text"] : nil;

    switch (action) {
        case KINAddressBarActionLoad:
            [self loadURLString:text];
            break;
        case KINAddressBarActionRefresh:
            [self reload];
            break;
        case KINAddressBarActionForward:
            [self goForward];
            break;
        case KINAddressBarActionBackward:
            [self goBack];
            break;
        case KINAddressBarActionCancel:
            [self stopLoading];
            break;
    }

    return;
}

- (id <KINWebBrowserAddressBarAbility>)addressBar {
    return _addressBar;
}

- (void)setAddressBar:(id <KINWebBrowserAddressBarAbility>)addressBar {
    if (_addressBar && addressBar != _addressBar) {
        [[NSNotificationCenter defaultCenter] removeObserver:self name:KINADDRESSBAR_NOTIFICATION object:_addressBar];
    }

    _addressBar = addressBar;
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(processAddressBarNotification:)
                                                 name:KINADDRESSBAR_NOTIFICATION object:_addressBar];
}


#pragma mark - Toolbar State

- (void)updateToolbarState {
    KINAddressBarStatus addressBarStatues = KINAddressBarStatusNone;
    BOOL canGoBack = self.webView.canGoBack;
    BOOL canGoForward = self.webView.canGoForward;

    if (canGoBack)
        addressBarStatues |= KINAddressBarStatusCanGoBack;
    if (canGoForward)
        addressBarStatues |= KINAddressBarStatusCanGoForward;

    if (self.isLoading)
        addressBarStatues |= KINAddressBarStatusCanCancel | KINAddressBarStatusIsLoading;
    else
        addressBarStatues |= KINAddressBarStatusCanRefresh | KINAddressBarStatusIsNotLoading; //todo: this should only be true if successfully loaded once

    [self.browserBackButtonItem setEnabled:canGoBack];
    [self.browserForwardButtonItem setEnabled:canGoForward];

    //  NSArray *barButtonItems;
    if (self.isLoading) {
        self.defaultBrowserToolbarItems = @[self.browserBackButtonItem, self.browserFixedSeparator1, self.browserForwardButtonItem, self.browserFixedSeparator2, self.browserStopButtonItem, self.browserFlexibleSeparator1];

        if (self.showsURLInNavigationBar) {
            NSString *URLString = [self.URL absoluteString];
            URLString = [URLString stringByReplacingOccurrencesOfString:@"http://" withString:@""];
            URLString = [URLString stringByReplacingOccurrencesOfString:@"https://" withString:@""];
            URLString = [URLString substringToIndex:[URLString length] - 1];
            self.navigationItem.title = URLString;
        }
    } else {
        self.defaultBrowserToolbarItems = @[self.browserBackButtonItem, self.browserFixedSeparator1, self.browserForwardButtonItem, self.browserFixedSeparator2, self.browserRefreshButtonItem, self.browserFlexibleSeparator1];

        if (self.showsPageTitleInNavigationBar) {
            if (self.wkWebView) {
                self.navigationItem.title = self.wkWebView.title;
            } else if (self.uiWebView) {
                self.navigationItem.title = [self.uiWebView stringByEvaluatingJavaScriptFromString:@"document.title"];
            }
        }
    }

    if (!self.actionButtonHidden) {
        NSMutableArray *mutableBarButtonItems = [NSMutableArray arrayWithArray:self.defaultBrowserToolbarItems];
        [mutableBarButtonItems addObject:self.browserActionButton];
        self.defaultBrowserToolbarItems = mutableBarButtonItems;
    }

    NSArray *barButtonItems = [self loadWebBrowserToolbarItems];

    if (barButtonItems)
        [self setToolbarItems:barButtonItems animated:YES];

    self.tintColor = self.tintColor;
    self.barTintColor = self.barTintColor;

    [self.addressBar updateAddressBarBrowser:self status:addressBarStatues];
}

- (void)setupToolbarItems {
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];

    self.browserRefreshButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh target:self action:@selector(refreshButtonPressed:)];
    self.browserStopButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemStop target:self action:@selector(stopButtonPressed:)];

    UIImage *backbuttonImage = [UIImage imageWithContentsOfFile:[bundle pathForResource:@"backbutton" ofType:@"png"]];
    self.browserBackButtonItem = [[UIBarButtonItem alloc] initWithImage:backbuttonImage style:UIBarButtonItemStylePlain target:self action:@selector(backButtonPressed:)];

    UIImage *forwardbuttonImage = [UIImage imageWithContentsOfFile:[bundle pathForResource:@"forwardbutton" ofType:@"png"]];
    self.browserForwardButtonItem = [[UIBarButtonItem alloc] initWithImage:forwardbuttonImage style:UIBarButtonItemStylePlain target:self action:@selector(forwardButtonPressed:)];
    self.browserForwardButtonItem.tag = KINBrowserToolbarButtonIndexForward;
    self.browserActionButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction target:self action:@selector(actionButtonPressed:)];
    self.browserActionButton.tag = KINBrowserToolbarButtonIndexAction;
    self.browserFixedSeparator1 = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace target:nil action:nil];
    self.browserFixedSeparator1.tag = KINBrowserToolbarButtonIndexFixedSeparator1;
    self.browserFixedSeparator1.width = 50.0f;
    self.browserFixedSeparator2 = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace target:nil action:nil];
    self.browserFixedSeparator2.width = 50.0f;
    self.browserFixedSeparator2.tag = KINBrowserToolbarButtonIndexFixedSeparator2;
    self.browserFlexibleSeparator1 = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    self.browserFlexibleSeparator1.tag = KINBrowserToolbarButtonIndexFlexibleSeparator1;
    self.browserFlexibleSeparator2 = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
}

#pragma mark - Done Button Action

- (void)doneButtonPressed:(id)sender {
    [self dismissAnimated:YES];
}

#pragma mark - UIBarButtonItem Target Action Methods

- (void)backButtonPressed:(id)sender {
    [self goBack];
    [self updateToolbarState];
}

- (void)forwardButtonPressed:(id)sender {
    [self goForward];
    [self updateToolbarState];
}

- (void)refreshButtonPressed:(id)sender {
    [self reload];
    [self updateToolbarState];
}

- (void)stopButtonPressed:(id)sender {
    [self stopLoading];
}

- (void)actionButtonPressed:(id)sender {
    NSURL *URLForActivityItem;
    NSString *URLTitle;
    if (self.wkWebView) {
        URLForActivityItem = self.wkWebView.URL;
        URLTitle = self.wkWebView.title;
    } else if (self.uiWebView) {
        URLForActivityItem = self.uiWebView.request.URL;
        URLTitle = [self.uiWebView stringByEvaluatingJavaScriptFromString:@"document.title"];
    }
    if (URLForActivityItem) {
        dispatch_async(dispatch_get_main_queue(), ^{
            TUSafariActivity *safariActivity = [[TUSafariActivity alloc] init];
            ARChromeActivity *chromeActivity = [[ARChromeActivity alloc] init];

            NSMutableArray *activities = [[NSMutableArray alloc] init];
            [activities addObject:safariActivity];
            [activities addObject:chromeActivity];
            if (self.customActivityItems != nil) {
                [activities addObjectsFromArray:self.customActivityItems];
            }

            UIActivityViewController *controller = [[UIActivityViewController alloc] initWithActivityItems:@[URLForActivityItem] applicationActivities:activities];

            if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
                if (self.actionPopoverController) {
                    [self.actionPopoverController dismissPopoverAnimated:YES];
                }
                self.actionPopoverController = [[UIPopoverController alloc] initWithContentViewController:controller];
                [self.actionPopoverController presentPopoverFromBarButtonItem:self.browserActionButton permittedArrowDirections:UIPopoverArrowDirectionAny animated:YES];
            }
            else {
                [self presentViewController:controller animated:YES completion:NULL];
            }
        });
    }
}


#pragma mark - Estimated Progress KVO (WKWebView)

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if ([keyPath isEqualToString:NSStringFromSelector(@selector(estimatedProgress))] && object == self.wkWebView) {
        [self.progressView setAlpha:1.0f];
        BOOL animated = self.wkWebView.estimatedProgress > self.progressView.progress;
        [self.progressView setProgress:self.wkWebView.estimatedProgress animated:animated];

        // Once complete, fade out UIProgressView
        if (self.wkWebView.estimatedProgress >= 1.0f) {
            [UIView animateWithDuration:0.3f delay:0.3f options:UIViewAnimationOptionCurveEaseOut animations:^{
                [self.progressView setAlpha:0.0f];
            }                completion:^(BOOL finished) {
                [self.progressView setProgress:0.0f animated:NO];
            }];
        }
    }
    else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}


#pragma mark - Fake Progress Bar Control (UIWebView)

- (void)fakeProgressViewStartLoading {
    [self.progressView setProgress:0.0f animated:NO];
    [self.progressView setAlpha:1.0f];

    if (!self.fakeProgressTimer) {
        self.fakeProgressTimer = [NSTimer scheduledTimerWithTimeInterval:1.0f / 60.0f target:self selector:@selector(fakeProgressTimerDidFire:) userInfo:nil repeats:YES];
    }
}

- (void)fakeProgressBarStopLoading {
    if (self.fakeProgressTimer) {
        [self.fakeProgressTimer invalidate];
    }

    if (self.progressView) {
        [self.progressView setProgress:1.0f animated:YES];
        [UIView animateWithDuration:0.3f delay:0.3f options:UIViewAnimationOptionCurveEaseOut animations:^{
            [self.progressView setAlpha:0.0f];
        }                completion:^(BOOL finished) {
            [self.progressView setProgress:0.0f animated:NO];
        }];
    }
}

- (void)fakeProgressTimerDidFire:(id)sender {
    CGFloat increment = 0.005 / (self.progressView.progress + 0.2);
    if ([self.uiWebView isLoading]) {
        CGFloat progress = (self.progressView.progress < 0.75f) ? self.progressView.progress + increment : self.progressView.progress + 0.0005;
        if (self.progressView.progress < 0.95) {
            [self.progressView setProgress:progress animated:YES];
        }
    }
}

#pragma mark - Balance Manipulation

- (NSInteger)incrementURL:(NSURL *)url balanceBy:(NSInteger)amount {
    NSNumber *number = self.requestBalance[url.absoluteString];
    NSInteger updatedNumber = amount == 0 ? 1 : (number ? [number integerValue] : 0) + amount;

    if (updatedNumber < 1) {
        self.requestBalance[url.absoluteString] = @(0); // nil;
    } else {
        self.requestBalance[url.absoluteString] = @(updatedNumber);
    }

    return updatedNumber;
}

- (NSInteger)balanceForURL:(NSURL *)url {
    NSString *urlString = url.absoluteString;
    NSNumber *number = self.requestBalance[url.absoluteString];
    NSInteger count = number ? [number integerValue] : 0;
    return count;
}

- (BOOL)finishedLoadingURL:(NSURL *)url {
    NSString *urlString = url.absoluteString;
    NSNumber *number = self.requestBalance[url.absoluteString];
    NSInteger count = number ? [number integerValue] : 0;
    return count > 0 ? NO : YES;
}

#pragma mark - External App Support

- (BOOL)externalAppRequiredToOpenURL:(NSURL *)URL {
    NSSet *validSchemes = [NSSet setWithArray:@[@"http", @"https", @"about"]];
    return ![validSchemes containsObject:URL.scheme];
}

- (void)launchExternalAppWithURL:(NSURL *)URL {
    self.URLToLaunchWithPermission = URL;
    if (![self.externalAppPermissionAlertView isVisible]) {
        [self.externalAppPermissionAlertView show];
    }

}

#pragma mark - UIAlertViewDelegate

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
    if (alertView == self.externalAppPermissionAlertView) {
        if (buttonIndex != alertView.cancelButtonIndex) {
            [[UIApplication sharedApplication] openURL:self.URLToLaunchWithPermission];
        }
        self.URLToLaunchWithPermission = nil;
    }
}

#pragma mark - Dismiss

- (void)dismissAnimated:(BOOL)animated {
    if ([self.delegate respondsToSelector:@selector(webBrowserViewControllerWillDismiss:)]) {
        [self.delegate webBrowserViewControllerWillDismiss:self];
    }
    [self.navigationController dismissViewControllerAnimated:animated completion:nil];
}

#pragma mark - Interface Orientation

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskAllButUpsideDown;
}

- (BOOL)shouldAutorotate {
    return YES;
}

#pragma mark - Snapshot

- (void)performScreenshotWithOptions:(KINBrowserSnapshotOption)option
                            progress:(KINBrowserSnapshotProgressBlock)progressBlock
                           completed:(KINBrowserSnapshotCompletedBlock)completedBlock {
    [self performScreenshotWithOptions:option interval:0.5 progress:progressBlock completed:completedBlock];
}

- (void)performScreenshotWithOptions:(KINBrowserSnapshotOption)option
                            interval:(NSTimeInterval)interval
                            progress:(KINBrowserSnapshotProgressBlock)progressBlock
                           completed:(KINBrowserSnapshotCompletedBlock)completedBlock {
    NSOperationQueue *mainQueue = [NSOperationQueue new]; // [NSOperationQueue mainQueue];
    KINWebBrowserSnapshotContext *progress = [KINWebBrowserSnapshotContext new];
    NSTimeInterval snapshotDelay = interval;
    NSInteger remainder = 0;
    BOOL progressiveSnapshot = (option & KINBrowserSnapshotOptionProgressive) == KINBrowserSnapshotOptionProgressive;
    BOOL isJPEGSnapshot = (option & KINBrowserSnapshotOptionFormatJPEG) == KINBrowserSnapshotOptionFormatJPEG;

    mainQueue.maxConcurrentOperationCount = 1;
    progress.option = option;
    progress.progressBlock = progressBlock;
    progress.completedBlock = completedBlock;
    progress.initialContentSize = self.webView.scrollView.contentSize;
    progress.initialContentOffset = self.webView.scrollView.contentOffset;
    progress.initialWebViewFrame = self.webView.frame;
    progress.initialScrollEnabled = self.webView.scrollView.scrollEnabled;
    progress.initialUserInteractionEnabled = self.webView.userInteractionEnabled;

    remainder = (int) progress.initialContentSize.height % (int) progress.initialWebViewFrame.size.height;
    progress.total_pages =
            (int) progress.initialContentSize.height / (int) progress.initialWebViewFrame.size.height + (remainder > 0 ? 1 : 0);
    progress.current_index = 0;
    progress.snapshotHeight = progress.pages * progress.initialWebViewFrame.size.height;

    if (progressiveSnapshot) {
        NSOperation *lastOperation = nil;
        NSMutableArray <NSOperation * > *operations = [NSMutableArray array];
        KINSnapshotOperation *firstOperation = [KINSnapshotOperation new];
        firstOperation.workBlock = ^{
            [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                self.webView.scrollView.contentSize = CGSizeMake(0, progress.snapshotHeight * 2);
                self.webView.scrollView.contentOffset = CGPointZero;
                self.browserViewBottomConstraint.active = NO;
                self.browserViewHeightConstraint.constant = progress.snapshotHeight;
                self.webView.scrollView.scrollEnabled = NO;
                self.webView.userInteractionEnabled = NO;
                [self.webView setNeedsDisplay];
            }];
            [NSThread sleepForTimeInterval:snapshotDelay];
        };

        [mainQueue addOperation:firstOperation];
        [operations addObject:firstOperation];

        for (int i = 0, l = progress.pages; i < l; i++) {
            KINSnapshotOperation *operation = [KINSnapshotOperation new];
            operation.workBlock = ^{
                if (progress.cancelled) {
                    [mainQueue cancelAllOperations];
                    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                        [self restoreWebBrowser:progress];
                        //  NSLog(@"+performScreenshotWithOptions: finish: %d", progress.index);
                    }];
                    return;
                }

                [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                    NSInteger next_page = progress.index + 1;
                    CGPoint nextScrollPosition = CGPointMake(0, progress.index * progress.initialWebViewFrame.size.height);
                    progress.current_index = next_page;
                    self.webView.scrollView.contentOffset = nextScrollPosition;
                    [self.webView.scrollView setContentOffset:nextScrollPosition animated:NO];
                    //    [self.webView setNeedsDisplay];

                    if (progress.progressBlock)
                        progress.progressBlock(progress);
                }];

                [NSThread sleepForTimeInterval:snapshotDelay];

                [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                    [self performBrowserSnapshot:progress];
                }];
            };

            [operation addDependency:lastOperation ? lastOperation : firstOperation];
            [operations addObject:operation];
            [mainQueue addOperation:operation];
            lastOperation = operation;
        }

        KINSnapshotOperation *finishOperation = [KINSnapshotOperation new];
        finishOperation.workBlock = ^{
            [NSThread sleepForTimeInterval:snapshotDelay];
            [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                [self restoreWebBrowser:progress];
            }];
        };

        [finishOperation addDependency:[operations lastObject]];
        [mainQueue addOperation:finishOperation];
    } else {
        // [self performSelector:@selector(performBrowserSnapshot) withObject:nil afterDelay:0];
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            if (progress.cancelled)
                return;
            [self performBrowserSnapshot:progress];
        }];

    }
}

- (void)restoreWebBrowser:(KINWebBrowserSnapshotContext *)progress {
    self.webView.scrollView.contentSize = progress.initialContentSize;
    self.webView.scrollView.contentOffset = progress.initialContentOffset;
    self.webView.scrollView.scrollEnabled = progress.initialScrollEnabled;
    self.webView.userInteractionEnabled = progress.initialUserInteractionEnabled;
    self.browserViewBottomConstraint.active = YES;
    self.browserViewHeightConstraint.constant = progress.initialWebViewFrame.size.height;
    [self.webView setNeedsDisplay];
}

- (void)performBrowserSnapshot:(KINWebBrowserSnapshotContext *)progress {
    @autoreleasepool {
        BOOL finished = progress.index == (progress.pages - 1);
        UIImage *image = nil;
        BOOL renderInContext = YES;
        BOOL useSnapshotView = NO;
        UIView *captureView = useSnapshotView ? [self.webView snapshotViewAfterScreenUpdates: YES] : self.webView;
        //captureView = captureView.window;
        UIGraphicsBeginImageContextWithOptions(progress.initialWebViewFrame.size, YES, 0.0); //[UIScreen mainScreen].scale

        if (renderInContext)
            [captureView.layer renderInContext:UIGraphicsGetCurrentContext()]; //on device: CGImageCreateWithImageProvider: invalid image provider: NULL
        else
            [captureView drawViewHierarchyInRect:CGRectMake(0, 0, progress.initialWebViewFrame.size.width, progress.initialWebViewFrame.size.height) afterScreenUpdates:YES];

        image = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();

        if (image) {
            NSError *error;
            NSData *imageData =  UIImagePNGRepresentation(image);
            NSString *imageName = [NSString stringWithFormat:@"snapshot_%p_%d.%@", self.view, progress.index, @"png"];
            NSURL *imageDir = [NSURL fileURLWithPath:NSTemporaryDirectory()];
            NSURL *fullPathURL = [imageDir URLByAppendingPathComponent:imageName];
            [[NSFileManager defaultManager] createDirectoryAtURL:imageDir
                                     withIntermediateDirectories:YES attributes:@{} error:&error];
            BOOL success = [imageData writeToURL:fullPathURL atomically:YES];

            NSAssert(success,@"Unable to write snapshot to path: %@",fullPathURL);
            NSLog(@"+logging file to: %@", fullPathURL);
            [progress addScreenshot:fullPathURL];
        }


        if (progress.completedBlock)
            progress.completedBlock(image, progress, finished);
    }
}

#pragma mark - Dealloc

- (void)dealloc {
    [self.webView stopLoading];
    [self.uiWebView setDelegate:nil];
    [self.wkWebView setNavigationDelegate:nil];
    [self.wkWebView setUIDelegate:nil];
    if ([self isViewLoaded]) {
        [self.wkWebView removeObserver:self forKeyPath:NSStringFromSelector(@selector(estimatedProgress))];
    }
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}
@end

@implementation UINavigationController (KINWebBrowser)
- (KINWebBrowserViewController *)rootWebBrowser {
    UIViewController *rootViewController = [self.viewControllers objectAtIndex:0];
    return (KINWebBrowserViewController *) rootViewController;
}
@end
