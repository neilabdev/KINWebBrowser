//
//  KINWebBrowserViewController.h
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

#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>
#import "KINWebBrowserAddressBar.h"

@class KINWebBrowserViewController;


/*
 
 UINavigationController+KINWebBrowserWrapper category enables access to casted KINWebBroswerViewController when set as rootViewController of UINavigationController
 
 */
@interface UINavigationController (KINWebBrowser)
// Returns rootViewController casted as KINWebBrowserViewController
- (KINWebBrowserViewController *)rootWebBrowser;
@end


@protocol KINWebBrowserView <NSObject>
@property(nonatomic, readonly, copy, nullable) NSString *title;
@property(nonatomic, readonly, copy, nullable) NSURL *URL;
@property(nonatomic, readonly, strong, nonnull) UIScrollView *scrollView;
@property(nonatomic, readonly) BOOL canGoForward;
@property(nonatomic, readonly) BOOL canGoBack;
@property(nonatomic, readonly, getter=isLoading) BOOL loading;

- (void)evaluateJavaScript:(NSString *)script then:(void (^ __nullable)(__nullable id, NSError *__nullable error))then;

- (void)loadURLRequest:(NSURLRequest *_Nonnull)request;

- (void)stopLoading;

- (void)refresh;
@end

@interface UIWebView (KINWebBrowserWebViewMethods)
@property(nonatomic, readonly, copy, nullable) NSURL *URL;
@property(nonatomic, readonly, getter=isLoading) BOOL loading;
@property(nonatomic, readonly, copy, nullable) NSString *title;

- (void)evaluateJavaScript:(NSString *)script then:(void (^ __nullable)(__nullable id, NSError *__nullable error))then;

- (void)refresh;
@end

@interface WKWebView (KINWebBrowserWebViewMethods)
- (void)evaluateJavaScript:(NSString *)script then:(void (^ __nullable)(__nullable id, NSError *__nullable error))then;

- (void)refresh;
@end


typedef NS_ENUM(NSInteger, KINBrowserNavigationType) {
    KINBrowserNavigationTypeLinkClicked,
    KINBrowserNavigationTypeFormSubmitted,
    KINBrowserNavigationTypeBackForward,
    KINBrowserNavigationTypeReload,
    KINBrowserNavigationTypeFormResubmitted,
    KINBrowserNavigationTypeOther
};

typedef NS_ENUM(NSInteger, KINBrowserToolbarButtonIndex) {
    KINBrowserToolbarButtonIndexBack = 0,
    KINBrowserToolbarButtonIndexFixedSeparator1 = 1,
    KINBrowserToolbarButtonIndexForward = 2,
    KINBrowserToolbarButtonIndexFixedSeparator2 = 3,
    KINBrowserToolbarButtonIndexRefresh = 4,
    KINBrowserToolbarButtonIndexStop = 4,
    KINBrowserToolbarButtonIndexFlexibleSeparator1 = 5,
    KINBrowserToolbarButtonIndexAction = 6
};

typedef NS_OPTIONS(NSInteger, KINBrowserSnapshotOption) {
    KINBrowserSnapshotOptionProgressive = 1 << 0,
    KINBrowserSnapshotOptionVisible = 1 << 1,
    KINBrowserSnapshotOptionFormatJPEG = 1 << 2,
    KINBrowserSnapshotOptionFormatPNG = 1 << 3,
    KINBrowserSnapshotOptionCompressionHigh = 1 << 4,
    KINBrowserSnapshotOptionCompressionMedium = 1 << 5,
    KINBrowserSnapshotOptionCompressionLow = 1 << 6,
    KINBrowserSnapshotOptionDefault = KINBrowserSnapshotOptionProgressive | KINBrowserSnapshotOptionFormatJPEG | KINBrowserSnapshotOptionCompressionLow
};


@interface KINWebBrowserSnapshotContext : NSObject
@property(nonatomic, readonly) NSInteger index;
@property(nonatomic, readonly) NSInteger pages;
@property(nonatomic, readonly) BOOL cancelled;
@property(nonatomic, readonly) NSArray <NSURL *> *snapshots;

- (UIImage *)snapshot;
- (NSData *) pdf;

- (void)cancel;
@end

typedef void(^KINBrowserSnapshotProgressBlock)(KINWebBrowserSnapshotContext *progress);

typedef void(^KINBrowserSnapshotCompletedBlock)(UIImage *image, KINWebBrowserSnapshotContext *context, BOOL finished);

@protocol KINWebBrowserDelegate <NSObject>
@optional
- (BOOL)webBrowser:(KINWebBrowserViewController *)webBrowser shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(KINBrowserNavigationType)navigationType;

- (void)webBrowser:(KINWebBrowserViewController *)webBrowser didStartLoadingURL:(NSURL *)URL;

- (void)webBrowser:(KINWebBrowserViewController *)webBrowser didFinishLoadingURL:(NSURL *)URL;

- (void)webBrowser:(KINWebBrowserViewController *)webBrowser didFailToLoadURL:(NSURL *)URL error:(NSError *)error;

- (void)webBrowserViewControllerWillDismiss:(KINWebBrowserViewController *)viewController;

- (NSArray *)webBrowserToolbarItems __deprecated;

- (NSArray *)webBrowser:(KINWebBrowserViewController *)webBrowser toolbarItems:(NSArray *)items;

@end


/*
 
 KINWebBrowserViewController is designed to be used inside of a UINavigationController.
 For convenience, two sets of static initializers are available.
 
 */
@interface KINWebBrowserViewController : UIViewController <WKNavigationDelegate, WKUIDelegate, UIWebViewDelegate>

#pragma mark - Public Properties

@property(nonatomic, weak) id <KINWebBrowserDelegate> delegate;
// The main and only UIProgressView
@property(nonatomic, strong) UIProgressView *progressView;


- (void)enableSnapshot:(BOOL)truth  __deprecated;

// The web views
// Depending on the version of iOS, one of these will be set
@property(nonatomic, strong) UIBarButtonItem *browserBackButtonItem, *browserForwardButtonItem, *browserRefreshButtonItem,
        *browserStopButtonItem, *browserFixedSeparator1, *browserFixedSeparator2, *browserActionButton,
        *browserFlexibleSeparator1, *browserFlexibleSeparator2;
@property(nonatomic, strong) WKWebView *wkWebView;
@property(nonatomic, strong) UIWebView *uiWebView;
@property(nonatomic, readonly) UIView <KINWebBrowserView> *webView;
@property(nonatomic, strong) UIView *browserHeaderView;
@property(nonatomic, strong) id <KINWebBrowserAddressBarAbility> addressBar; //todo: perhaps this should be weak?
@property(nonatomic, strong) Class browserViewClass;
@property(nonatomic, readonly, copy, nullable) NSURL *URL;
@property(nonatomic, readonly, getter=isLoading) BOOL loading;

- (id)initWithConfiguration:(WKWebViewConfiguration *)configuration NS_AVAILABLE_IOS(8_0);

#pragma mark - Static Initializers

/*
 Initialize a basic KINWebBrowserViewController instance for push onto navigation stack
 
 Ideal for use with UINavigationController pushViewController:animated: or initWithRootViewController:
 
 Optionally specify KINWebBrowser options or WKWebConfiguration
 */

+ (KINWebBrowserViewController *)webBrowser;

+ (KINWebBrowserViewController *)webBrowserWithConfiguration:(WKWebViewConfiguration *)configuration NS_AVAILABLE_IOS(8_0);

/*
 Initialize a UINavigationController with a KINWebBrowserViewController for modal presentation.
 
 Ideal for use with presentViewController:animated:
 
 Optionally specify KINWebBrowser options or WKWebConfiguration
 */

+ (UINavigationController *)navigationControllerWithWebBrowser;

+ (UINavigationController *)navigationControllerWithWebBrowserWithConfiguration:(WKWebViewConfiguration *)configuration NS_AVAILABLE_IOS(8_0);

@property(nonatomic, strong) UIBarButtonItem *actionButton __deprecated_msg("Use browserActionButton instead.");
@property(nonatomic, strong) UIColor *tintColor;
@property(nonatomic, strong) UIColor *barTintColor;
@property(nonatomic, assign) BOOL actionButtonHidden;
@property(nonatomic, assign) BOOL showsURLInNavigationBar;
@property(nonatomic, assign) BOOL showsPageTitleInNavigationBar;
@property(nonatomic, assign) CGFloat snapshotPadding;
@property(nonatomic, assign) NSTimeInterval  snapshotDelay;

//Allow for custom activities in the browser by populating this optional array
@property(nonatomic, strong) NSArray *customActivityItems;

#pragma mark - Public Interface
// Load a NSURLURLRequest to web view
// Can be called any time after initialization
- (void)loadRequest:(NSURLRequest *)request;

// Load a NSURL to web view
// Can be called any time after initialization
- (void)loadURL:(NSURL *)URL;

// Loads a URL as NSString to web view
// Can be called any time after initialization
- (void)loadURLString:(NSString *)URLString;

// Loads an string containing HTML to web view
// Can be called any time after initialization
- (void)loadHTMLString:(NSString *)HTMLString;

- (void)reload;

- (void)stopLoading;

- (void)goForward;

- (void)goBack;

- (void)performScreenshotWithOptions:(KINBrowserSnapshotOption)option
                            progress:(KINBrowserSnapshotProgressBlock)progress
                           completed:(KINBrowserSnapshotCompletedBlock)completedBlock;

- (void)performScreenshotWithOptions:(KINBrowserSnapshotOption)option
                            interval:(NSTimeInterval)interval
                            progress:(KINBrowserSnapshotProgressBlock)progressBlock
                           completed:(KINBrowserSnapshotCompletedBlock)completedBlock;
@end

