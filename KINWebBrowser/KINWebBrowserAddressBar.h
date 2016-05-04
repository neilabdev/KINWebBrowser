//
// Created by James Whitfield on 3/12/16.
// Copyright (c) 2016 IC2MEDIA, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol KINWebBrowserDelegate;
@class KINWebBrowserViewController;
#define KINADDRESSBAR_NOTIFICATION NSStringFromSelector(@selector(onAddressBar:text:action:))
#define POST_KINADDRESSBAR_NOTIFICATION(text,action)  \
    [[NSNotificationCenter defaultCenter] postNotificationName:KINADDRESSBAR_NOTIFICATION \
        object: self userInfo:@{@"text": (text ? text : [NSNull null]),@"action":@(action),@"onAddressBar":self}];

typedef NS_OPTIONS(NSInteger, KINAddressBarStatus) {
    KINAddressBarStatusNone = 0,
    KINAddressBarStatusCanGoBack = 1 << 0,
    KINAddressBarStatusCanGoForward = 1 << 1,
    KINAddressBarStatusCanRefresh = 1 << 2,
    KINAddressBarStatusCanCancel = 1 << 3,
    KINAddressBarStatusIsLoading = 1 << 4, //webView is loading
    KINAddressBarStatusIsNotLoading = 1 << 5, // webView is not loading
    KINAddressBarStatusIsBlank = 1 << 6 //webView has no url
};

typedef NS_OPTIONS(NSInteger, KINAddressBarButtonItem) {
    KINAddressBarButtonItemNone = 0,
    KINAddressBarButtonItemAddress = 1 << 0,
    KINAddressBarButtonItemGoForward = 1 << 1,
    KINAddressBarButtonItemGoBack = 1 << 2
};


typedef NS_ENUM(NSInteger, KINAddressBarAction) { //actions are sent from the addressbar to its listeners
    KINAddressBarActionNone,
    KINAddressBarActionLoad ,
    KINAddressBarActionCancel,

    KINAddressBarActionBackward ,
    KINAddressBarActionForward,
    KINAddressBarActionRefresh,
};

typedef NS_ENUM(NSInteger, KINAddressBarSearchService) {
    KINAddressBarSearchGoogle,
    KINAddressBarSearchDuckDuckGo
};



@interface KINAddressBarTextField : UITextField

@end

@protocol KINWebBrowserAddressBarAbility <NSObject> //used if creating your own statusBar withotu subclass
//set url of addressbar
@required
- (void) updateAddressBarBrowser: (KINWebBrowserViewController *) browser status:(KINAddressBarStatus) status;
- (void) postAddressBarText:(NSString*) text action:(KINAddressBarAction) action; //should be called internally to send notfications to all listeners. SEE POST_KINADDRESSBAR_NOTIFICATION macro if implementation details
- (void)setAccessoryItems: (NSArray*)items animated:(BOOL)animated;
@end

@protocol KINWebBrowserAddressBarDelegate <NSObject>
-(void) onAddressBar:(id <KINWebBrowserAddressBarAbility>) addressBar text:(NSString*) text action:(KINAddressBarAction) action;
@end

@interface KINWebBrowserAddressBar : UIToolbar <KINWebBrowserAddressBarAbility, UITextFieldDelegate>
- (instancetype _Nonnull)initWithFrame:(CGRect)aRect items: (KINAddressBarButtonItem) items;
@property (nonatomic, weak) id <KINWebBrowserAddressBarDelegate> addressBarDelegate;
@property (nonatomic,assign) KINAddressBarSearchService searchService;
@property (nonatomic,retain) UIBarButtonItem *addressFieldItem;
@property (nonatomic,retain, readonly) UIBarButtonItem *forwardButtonItem;
@property (nonatomic,retain, readonly) UIBarButtonItem *backwardButtonItem;
- (void) updateAddressBarBrowser: (KINWebBrowserViewController *) browser status:(KINAddressBarStatus) status;
- (void)setAccessoryItems: (NSArray*)items animated:(BOOL)animated;
@end