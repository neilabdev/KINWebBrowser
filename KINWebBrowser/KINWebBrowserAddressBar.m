//
// Created by James Whitfield on 3/12/16.
// Copyright (c) 2016 IC2MEDIA, LLC. All rights reserved.
//

#import "KINWebBrowserAddressBar.h"
#import "KINWebBrowserViewController.h"

static NSString *const kGoogleServiceRequestPath     = @"https://www.google.com/search?q=";
static NSString *const kDuckDuckGoServiceRequestPath = @"https://duckduckgo.com/?q=";
static NSString *const kHostnameRegex                = @"((\\w)*|([0-9]*)|([-|_])*)+"
        "([\\.|/]((\\w)*|([0-9]*)|([-|_])*))+";

typedef NS_ENUM(NSInteger, KINAddressBarState) {
    KINAddressBarStateNone,
    KINAddressBarStateIntitial, //displays playholder text with search
    KINAddressBarStateLoading, //url is being loaded, show cancel button
    KINAddressBarStateLoaded
};
@implementation KINAddressBarTextField
//todo: style textfield, however
@end

@interface KINWebBrowserAddressBar ()
@property(nonatomic, retain) KINAddressBarTextField *addressField;
@property(nonatomic, retain) UIButton *actionButton; //refresh/cancell
@property(nonatomic, retain) UIButton *statusButton; //search/or url



@property(nonatomic, retain) UIButton *forwardButton;
@property(nonatomic, retain) UIButton *backButton;

@property(nonatomic, retain) UIImage *refreshActionImage;
@property(nonatomic, retain) UIImage *cancelActionImage; //stop loading page
@property(nonatomic, retain) UIImage *webStatusImage; //indicates text is/or should be url
@property(nonatomic, retain) UIImage *backButtonImage;
@property(nonatomic, retain) UIImage *forwardButtonImage;
@end

@implementation KINWebBrowserAddressBar {
    KINAddressBarState actionState;
    KINAddressBarButtonItem defaultItemMask;
}
@synthesize forwardButtonItem = _forwardButtonItem;
@synthesize backwardButtonItem = _backwardButtonItem;

- (instancetype _Nonnull)initWithFrame:(CGRect)frame items: (KINAddressBarButtonItem) defaultItems {
    if (self = [super initWithFrame:frame]) {
        self.searchService = KINAddressBarSearchGoogle;
        defaultItemMask = defaultItems;
        CGFloat addressFieldWidth = (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) ? self.self.bounds.size.width / 2 : self.self.bounds.size.width * 0.8;
        UITextField *addressField = self.addressField =
                [[KINAddressBarTextField alloc] initWithFrame:CGRectMake(0, 0, addressFieldWidth, 30)];

        addressField.borderStyle = UITextBorderStyleRoundedRect; //UITextBorderStyleLine;// UITextBorderStyleBezel; // UITextBorderStyleRoundedRect;
        addressField.tintColor = [UIColor redColor];
        addressField.backgroundColor = [[UIColor lightGrayColor] colorWithAlphaComponent:0.25f];
        addressField.rightViewMode = UITextFieldViewModeUnlessEditing;
        addressField.leftViewMode = UITextFieldViewModeAlways;
        addressField.textAlignment = NSTextAlignmentCenter;
        addressField.delegate = self;
        addressField.autocorrectionType = UITextAutocorrectionTypeNo;
        actionState = KINAddressBarStateIntitial;
        self.refreshActionImage = [self loadBundleImageName:@"reloadbutton"];
        self.cancelActionImage = [self loadBundleImageName:@"cancelbutton"];
        self.backButtonImage = [self loadBundleImageName:@"backbutton"];
        self.forwardButtonImage = [self loadBundleImageName:@"forwardbutton"];
        self.webStatusImage = [self loadBundleImageName:@"webbutton"];

        if ((self.actionButton = [UIButton buttonWithType:UIButtonTypeCustom])) { //also true, just any easy way to group without a method
            [self.actionButton addTarget:self action:@selector(onActionTouchEvent:) forControlEvents:UIControlEventTouchUpInside];
            [self.actionButton setFrame:CGRectMake(0.f, 0.f, self.refreshActionImage.size.width, self.refreshActionImage.size.height)];
            [self.actionButton setImage:self.refreshActionImage forState:UIControlStateNormal];
        }

        if ((self.statusButton = [UIButton buttonWithType:UIButtonTypeCustom])) { //also true, just any easy way to group without a method
            [self.statusButton addTarget:self action:@selector(onStatusTouchEvent:) forControlEvents:UIControlEventTouchUpInside];
            [self.statusButton setFrame:CGRectMake(0.f, 0.f, self.webStatusImage.size.width, self.webStatusImage.size.height)];
            [self.statusButton setImage:self.webStatusImage forState:UIControlStateNormal];
        }

        self.forwardButton = [UIButton buttonWithType:UIButtonTypeCustom];
        [self.forwardButton addTarget:self action:@selector(onFowardTouchEvent:) forControlEvents:UIControlEventTouchUpInside];
        [self.forwardButton setFrame:CGRectMake(0.f, 0.f, self.forwardButtonImage.size.width + 10, self.forwardButtonImage.size.height)];
        [self.forwardButton setImage:self.forwardButtonImage forState:UIControlStateNormal];

        self.backButton = [UIButton buttonWithType:UIButtonTypeCustom];
        [self.backButton addTarget:self action:@selector(onBackwardTouchEvent:) forControlEvents:UIControlEventTouchUpInside];
        [self.backButton setFrame:CGRectMake(0.f, 0.f, self.backButtonImage.size.width + 10, self.backButtonImage.size.height)];
        [self.backButton setImage:self.backButtonImage forState:UIControlStateNormal];

        _forwardButtonItem = [[UIBarButtonItem alloc] initWithCustomView:self.forwardButton];
        _backwardButtonItem = [[UIBarButtonItem alloc] initWithCustomView:self.backButton];


        self.addressFieldItem = [[UIBarButtonItem alloc] initWithCustomView:addressField];
        // [self.actionButton se]
        addressField.rightViewMode = UITextFieldViewModeAlways;
        addressField.leftViewMode = UITextFieldViewModeAlways;
        addressField.rightView = self.actionButton;
        addressField.leftView = self.statusButton;

        self.items = [self defaultAddressBarItems];

        [self updateAddressBarText:@"" state:actionState status:KINAddressBarStateNone];
    }

    return self;
}
- (instancetype)initWithFrame:(CGRect)frame {
if(self = [self initWithFrame:frame items:KINAddressBarButtonItemAddress | KINAddressBarButtonItemGoBack | KINAddressBarButtonItemGoForward]) {

}

    return self;
}

- (UIBarButtonItem *)forwardButtonItem {
   // UIBarButtonItem *forwardButtonItem = [[UIBarButtonItem alloc] initWithCustomView:self.forwardButton];
    return _forwardButtonItem;
}

- (UIBarButtonItem *)backwardButtonItem {
  //  UIBarButtonItem *backwardButtonItem = [[UIBarButtonItem alloc] initWithCustomView:self.backButton];
    return _backwardButtonItem;
}


- (NSArray*) defaultAddressBarItems {
    NSMutableArray *maskedItems = [NSMutableArray arrayWithCapacity:1];

    if(defaultItemMask& KINAddressBarButtonItemAddress)
        [maskedItems addObject:self.addressFieldItem];

    if(defaultItemMask& KINAddressBarButtonItemGoBack)
        [maskedItems addObject:self.backwardButtonItem];


    if(defaultItemMask& KINAddressBarButtonItemGoForward)
        [maskedItems addObject:self.forwardButtonItem];

    return maskedItems;
}

- (void)setItems:(NSArray *)items animated:(BOOL)animated {
    NSMutableArray *addressBarItems = items ? [NSMutableArray arrayWithArray:items] : [NSMutableArray arrayWithCapacity:1];

    if(![addressBarItems containsObject:self.addressFieldItem])
        [addressBarItems insertObject:self.addressBarDelegate atIndex:0];

    [super setItems:addressBarItems animated:animated];
}

- (void)setAccessoryItems: (NSArray*)items animated:(BOOL)animated {
    NSMutableArray *addressBarItems =[NSMutableArray array];
    [addressBarItems addObjectsFromArray:[self defaultAddressBarItems]];
    for(UIBarButtonItem *item in items) {
        if([item isKindOfClass:[UIBarButtonItem class]])
            [addressBarItems addObject:item];
    }
    [super setItems:addressBarItems animated:animated];
}
- (UIImage *)loadBundleImageName:(NSString *)name {

    NSString *bundlePath = [[NSBundle bundleForClass:[self class]]
            pathForResource:@"KINWebBrowser" ofType:@"bundle"];
    NSBundle *bundle = [NSBundle bundleWithPath:bundlePath];
    NSString *imagePath = [bundle pathForResource:name ofType:@"png"];
    // UIStoryboard *sb = [UIStoryboard storyboardWithName:@"IC2EntryAnnotationTableViewController" bundle:bundle];
    // IC2EntryAnnotationListViewController *vc = [sb instantiateViewControllerWithIdentifier:@"annotationTableViewController"];
    UIImage *image =
            [UIImage imageWithContentsOfFile:imagePath];
    return image;
}

#pragma mark - Actions

- (void)onActionTouchEvent:(id)event {
    NSLog(@"%@.%@:%@", self, NSStringFromSelector(_cmd), event);
    switch(actionState) {
        case KINAddressBarStateLoading:
            [self postAddressBarText:self.addressField.text action:KINAddressBarActionCancel];
            break;
        case KINAddressBarStateLoaded:
            [self postAddressBarText:self.addressField.text action:KINAddressBarActionRefresh];
            break;
    }
}

- (void)onStatusTouchEvent:(id)event {
    NSLog(@"%@.%@:%@", self, NSStringFromSelector(_cmd), event);
    //probably will never do anything
}

- (void)onForwardTouchEvent:(id)event {
    NSLog(@"%@.%@:%@", self, NSStringFromSelector(_cmd), event);
    //probably will never do anything
    [self postAddressBarText:self.addressField.text action:KINAddressBarActionForward];
}

- (void)onBackwardTouchEvent:(id)event {
    NSLog(@"%@.%@:%@", self, NSStringFromSelector(_cmd), event);
    //probably will never do anything
    [self postAddressBarText:self.addressField.text action:KINAddressBarActionBackward];
}


- (void) postAddressBarText:(NSString*) text action:(KINAddressBarAction) action {
    /*NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
    userInfo[@"text"] = text;
    userInfo[@"action"] = @(action);
    userInfo[@"onAddressBar"] = self;
    [[NSNotificationCenter defaultCenter] postNotificationName:NSStringFromSelector(@selector(onAddressBar:text:action:)) object:
            self userInfo:userInfo];*/
    NSURL *url = [self validURLFromString: text];
    NSString *urlString = [url absoluteString];
    if ([self.addressBarDelegate conformsToProtocol:@protocol(KINWebBrowserAddressBarDelegate)] &&
            [self.addressBarDelegate respondsToSelector:@selector(onAddressBar:text:action:)]) {
        [self.addressBarDelegate onAddressBar:self text:urlString action:action];
    }
    POST_KINADDRESSBAR_NOTIFICATION(urlString,action);
}


#pragma mark - AddressBarAbility Methods

- (void)updateAddressBarBrowser:(KINWebBrowserViewController *)browser status:(KINAddressBarStatus)status {
    NSString *addressBarText = [browser.URL absoluteString];

    if (status & KINAddressBarStatusCanRefresh) {
        actionState = KINAddressBarStateLoaded;
        //[self.actionButton setImage:self.refreshActionImage forState:UIControlStateNormal];
    } else if (status & KINAddressBarStatusCanCancel) {
        actionState = KINAddressBarStateLoading;
        //[self.actionButton setImage:self.cancelActionImage forState:UIControlStateNormal];
    } else  {
        NSLog(@"Unknown state");
    }

  //  [self.backButton setEnabled:(status & KINAddressBarStatusCanGoBack)];
  //  [self.forwardButton setEnabled:(status & KINAddressBarStatusCanGoForward)];

    [self updateAddressBarText: addressBarText state:actionState status: status];
}

- (void) updateAddressBarText: (NSString*) text state:(KINAddressBarState) state status:(KINAddressBarStatus)status { //todo:move
    switch(actionState) {
        case KINAddressBarStateIntitial:
            self.addressField.placeholder = @"Search or enter website name";
            self.addressField.textAlignment = NSTextAlignmentCenter;
            break;
        case KINAddressBarStateLoading:
            [self.actionButton setImage:self.cancelActionImage forState:UIControlStateNormal];
            self.addressField.textAlignment = NSTextAlignmentLeft;
            break;
        case KINAddressBarStateLoaded:
            [self.actionButton setImage:self.refreshActionImage forState:UIControlStateNormal];
            self.addressField.textAlignment = NSTextAlignmentLeft;
            break;
        default:
            break;
    }

    [self.backButton setEnabled:(status & KINAddressBarStatusCanGoBack)];
    [self.forwardButton setEnabled:(status & KINAddressBarStatusCanGoForward)];

    if(text)
        self.addressField.text = text;
}


#pragma mark - „

- (void)textFieldDidEndEditing:(UITextField *)textField {
    return;
}

- (void)textFieldDidBeginEditing:(UITextField * _Nonnull)textField {
    if([textField.text length] >0)
        [textField selectAll:textField];
}

- (BOOL)textFieldShouldClear:(UITextField *)textField {
    return YES;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [self postAddressBarText:self.addressField.text action:KINAddressBarActionLoad];
    return YES;
}


#pragma mark - Helpers


- (BOOL)validateHostname:(NSString *)query {
    NSPredicate *urlTest = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", kHostnameRegex];
    return [urlTest evaluateWithObject:query];
}

- (NSURL *)validURLFromString:(NSString *)query {
    // try to use query as an URL
    if(!query)
        return nil;
    NSString *trimmedQuery = [query stringByTrimmingCharactersInSet:
            [NSCharacterSet whitespaceCharacterSet]];

    NSURL *url = [NSURL URLWithString:trimmedQuery];

    if (url) {
        if (url.host && url.scheme) {
            return url;
        }
        if ([self validateHostname:query]) {
            url = [self validURLFromString: [NSString stringWithFormat:@"http://%@", query]];
            return url;
        }
    }
    // make search by query
    NSString *currentSearchServiceRequestPath = @"";

    switch (self.searchService) {
        case KINAddressBarSearchGoogle:
            currentSearchServiceRequestPath = [kGoogleServiceRequestPath copy];
            break;
        case KINAddressBarSearchDuckDuckGo:
            currentSearchServiceRequestPath = [kDuckDuckGoServiceRequestPath copy];
            break;
        default:
            currentSearchServiceRequestPath = [kGoogleServiceRequestPath copy];
            break;
    }
    NSCharacterSet *set = [NSCharacterSet URLHostAllowedCharacterSet];
    NSString *encodedQuery = [query stringByAddingPercentEncodingWithAllowedCharacters:set];

    url = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@", currentSearchServiceRequestPath,encodedQuery]];
    return url;
}


@end