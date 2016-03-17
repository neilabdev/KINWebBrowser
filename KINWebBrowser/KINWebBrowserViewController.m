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
        error = value ? nil : [NSError errorWithDomain:@"venttastic" code:1776 userInfo:@{script : script}];
    } else
        dispatch_sync(dispatch_get_main_queue(), ^{
            value = [self stringByEvaluatingJavaScriptFromString:script];
            error = value ? nil : [NSError errorWithDomain:@"venttastic" code:1776 userInfo:@{script : script}];
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
@property(nonatomic, strong) UIBarButtonItem *backButton, *forwardButton, *refreshButton, *stopButton, *fixedSeparator, *flexibleSeparator;
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
    KINWebBrowserViewController *webBrowserViewController = [KINWebBrowserViewController webBrowserWithConfiguration:nil];
    return webBrowserViewController;
}

+ (KINWebBrowserViewController *)webBrowserWithConfiguration:(WKWebViewConfiguration *)configuration {
    KINWebBrowserViewController *webBrowserViewController = [[self alloc] initWithConfiguration:configuration];
    return webBrowserViewController;
}

+ (UINavigationController *)navigationControllerWithWebBrowser {
    KINWebBrowserViewController *webBrowserViewController = [[self alloc] initWithConfiguration:nil];
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
- (void) setup {
    self.requestBalance = [NSMutableDictionary dictionary];
    self.loadedURLS = [NSMutableDictionary dictionary];
    // self.configuration = configuration;
    self.actionButtonHidden = NO;
    self.showsURLInNavigationBar = NO;
    self.showsPageTitleInNavigationBar = YES;
    self.externalAppPermissionAlertView = [[UIAlertView alloc] initWithTitle:@"Leave this app?"
                                                                     message:@"This web page is trying to open an outside app. Are you sure you want to open it?"
                                                                    delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"Open App", nil];
    _isActiveBrowser = NO;
}
- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    if (self = [super initWithNibName:nil bundle:nil]) {
        [self setup];
    }
    return self;
}


- (id)initWithConfiguration:(WKWebViewConfiguration *)configuration {
    if (self = [super initWithNibName:nil bundle:nil]) {
        [self setup];
        self.configuration = configuration;
    }
    return self;
}

#pragma mark - View Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];

    self.previousNavigationControllerToolbarHidden = self.navigationController.toolbarHidden;
    self.previousNavigationControllerNavigationBarHidden = self.navigationController.navigationBarHidden;

    if ((self.browserViewClass &&
            self.browserViewClass == [WKWebView class]) || (!self.browserViewClass && [WKWebView class])) {
        if (self.configuration) {
            self.wkWebView = [[WKWebView alloc] initWithFrame:CGRectZero configuration:self.configuration];
        } else {
            self.wkWebView = [[WKWebView alloc] init];
        }
    } else {
        self.uiWebView = [[UIWebView alloc] init];
    }

    if (self.wkWebView) {
        [self.wkWebView setFrame:self.view.bounds];
        [self.wkWebView setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight];
        [self.wkWebView setNavigationDelegate:self];
        [self.wkWebView setUIDelegate:self];
        [self.wkWebView setMultipleTouchEnabled:YES];
        [self.wkWebView setAutoresizesSubviews:YES];
        [self.wkWebView.scrollView setAlwaysBounceVertical:YES];
        [self.view addSubview:self.wkWebView];
        [self.wkWebView addObserver:self forKeyPath:NSStringFromSelector(@selector(estimatedProgress)) options:0 context:KINWebBrowserContext];
    } else if (self.uiWebView) {
        [self.uiWebView setFrame:self.view.bounds];
        [self.uiWebView setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight];
        [self.uiWebView setDelegate:self];
        [self.uiWebView setMultipleTouchEnabled:YES];
        [self.uiWebView setAutoresizesSubviews:YES];
        [self.uiWebView setScalesPageToFit:YES];
        [self.uiWebView.scrollView setAlwaysBounceVertical:YES];
        [self.view addSubview:self.uiWebView];

        /*  [[NSNotificationCenter defaultCenter] addObserver:self
                                                   selector:@selector(webViewHistoryDidChange:)
                                                       name:@"WebHistoryItemChangedNotification"
                                                     object:nil]; */

    }

    self.progressView = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
    [self.progressView setTrackTintColor:[UIColor colorWithWhite:1.0f alpha:0.0f]];
    [self.progressView setFrame:CGRectMake(0, self.navigationController.navigationBar.frame.size.height - self.progressView.frame.size.height, self.view.frame.size.width, self.progressView.frame.size.height)];
    [self.progressView setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin];

    [self organizeViews];
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

    [self.navigationController.navigationBar addSubview:self.progressView];
    [self updateToolbarState];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    _isActiveBrowser = NO;
    [self.navigationController setNavigationBarHidden:self.previousNavigationControllerNavigationBarHidden animated:animated];
    [self.navigationController setToolbarHidden:self.previousNavigationControllerToolbarHidden animated:animated];
    [self stopLoading]; // no need to continue loading if will become invisible. Hopefully deleages are called bore they are assigned nill
    //  [self.uiWebView setDelegate:nil];
    //  [self.wkWebView setUIDelegate:nil];
    //  [self.wkWebView setNavigationDelegate:nil];
    [self.progressView removeFromSuperview];
}

- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];
    [self organizeViews];
}

- (void)organizeViews {
    UIView *browserWindow = self.webView;
    CGFloat y_offset = 0;
    if (self.browserHeaderView && ![self.browserHeaderView isHidden]) {
        browserWindow.frame = CGRectMake(0, 0, self.view.bounds.size.width, y_offset = self.browserHeaderView.bounds.size.height);
    }

    browserWindow.frame = CGRectMake(0, y_offset, self.view.bounds.size.width, self.view.bounds.size.height);
}

- (void)setBrowserHeaderView:(UIView *)browserHeaderView {
    if (browserHeaderView != _browserHeaderView) {
        [_browserHeaderView removeFromSuperview];
        if (browserHeaderView) {
            [browserHeaderView setAutoresizingMask:UIViewAutoresizingFlexibleWidth];

            [self.view addSubview:browserHeaderView];
        }
        [self.view setNeedsLayout];
    }

    _browserHeaderView = browserHeaderView;
    if ([_browserHeaderView conformsToProtocol:@protocol(KINWebBrowserAddressBarAbility)])
        self.addressBar = (id <KINWebBrowserAddressBarAbility>) _browserHeaderView;
}


#pragma mark - Public Interface

- (void)loadRequest:(NSURLRequest *)request {
    [self stopLoading];
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

- (void)webView:(WKWebView * _Nonnull)webView didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge * _Nonnull)challenge completionHandler:(void (^ _Nonnull)(NSURLSessionAuthChallengeDisposition disposition, NSURLCredential * _Nullable credential))completionHandler {
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
    BOOL canGoBack = self.wkWebView.canGoBack || self.uiWebView.canGoBack;
    BOOL canGoForward = self.wkWebView.canGoForward || self.uiWebView.canGoForward;

    if (canGoBack)
        addressBarStatues |= KINAddressBarStatusCanGoBack;
    if (canGoForward)
        addressBarStatues |= KINAddressBarStatusCanGoForward;

    if (self.isLoading)
        addressBarStatues |= KINAddressBarStatusCanCancel | KINAddressBarStatusIsLoading;
    else
        addressBarStatues |= KINAddressBarStatusCanRefresh | KINAddressBarStatusIsNotLoading; //todo: this should only be true if successfully loaded once

    [self.backButton setEnabled:canGoBack];
    [self.forwardButton setEnabled:canGoForward];

    if (!self.backButton) {
        [self setupToolbarItems];
    }

    NSArray *barButtonItems;
    if (self.isLoading) {
        barButtonItems = @[self.backButton, self.fixedSeparator, self.forwardButton, self.fixedSeparator, self.stopButton, self.flexibleSeparator];

        if (self.showsURLInNavigationBar) {
            NSString *URLString = [self.URL absoluteString];
            URLString = [URLString stringByReplacingOccurrencesOfString:@"http://" withString:@""];
            URLString = [URLString stringByReplacingOccurrencesOfString:@"https://" withString:@""];
            URLString = [URLString substringToIndex:[URLString length] - 1];
            self.navigationItem.title = URLString;
        }
    } else {
        barButtonItems = @[self.backButton, self.fixedSeparator, self.forwardButton, self.fixedSeparator, self.refreshButton, self.flexibleSeparator];

        if (self.showsPageTitleInNavigationBar) {
            if (self.wkWebView) {
                self.navigationItem.title = self.wkWebView.title;
            }
            else if (self.uiWebView) {
                self.navigationItem.title = [self.uiWebView stringByEvaluatingJavaScriptFromString:@"document.title"];
            }
        }
    }

    if (!self.actionButtonHidden) {
        NSMutableArray *mutableBarButtonItems = [NSMutableArray arrayWithArray:barButtonItems];
        [mutableBarButtonItems addObject:self.actionButton];
        barButtonItems = [NSArray arrayWithArray:mutableBarButtonItems];
    }

    [self setToolbarItems:barButtonItems animated:YES];

    self.tintColor = self.tintColor;
    self.barTintColor = self.barTintColor;

    [self.addressBar updateAddressBarBrowser:self status:addressBarStatues];
}

- (void)setupToolbarItems {
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];

    self.refreshButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh target:self action:@selector(refreshButtonPressed:)];
    self.stopButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemStop target:self action:@selector(stopButtonPressed:)];

    UIImage *backbuttonImage = [UIImage imageWithContentsOfFile:[bundle pathForResource:@"backbutton" ofType:@"png"]];
    self.backButton = [[UIBarButtonItem alloc] initWithImage:backbuttonImage style:UIBarButtonItemStylePlain target:self action:@selector(backButtonPressed:)];

    UIImage *forwardbuttonImage = [UIImage imageWithContentsOfFile:[bundle pathForResource:@"forwardbutton" ofType:@"png"]];
    self.forwardButton = [[UIBarButtonItem alloc] initWithImage:forwardbuttonImage style:UIBarButtonItemStylePlain target:self action:@selector(forwardButtonPressed:)];
    self.actionButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction target:self action:@selector(actionButtonPressed:)];
    self.fixedSeparator = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace target:nil action:nil];
    self.fixedSeparator.width = 50.0f;
    self.flexibleSeparator = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
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
                [self.actionPopoverController presentPopoverFromBarButtonItem:self.actionButton permittedArrowDirections:UIPopoverArrowDirectionAny animated:YES];
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
