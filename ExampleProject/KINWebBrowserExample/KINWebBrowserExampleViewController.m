//
//  KINWebBrowserExampleViewController.m
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


#import "KINWebBrowserExampleViewController.h"
#import "KINSnapshotExampleViewController.h"

@interface KINWebBrowserExampleViewController ()
@property (nonatomic,retain) NSMutableArray *bottomToolbarItems;
@property (nonatomic,retain)UIBarButtonItem *browserTakeShopshotButton;
@property (nonatomic,retain) KINWebBrowserViewController *webBrowser;
@property (nonatomic,assign) BOOL snapshotEnabled;
@end

static NSString *const defaultAddress =  @"http://blogs.spectator.co.uk/2016/07/will-politicians-accept-reality-islamic-terrorism/"; // @"https://www.apple.com";

@implementation KINWebBrowserExampleViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
        self.snapshotEnabled = NO;
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    
    self.navigationItem.title = @"";
    [self.navigationController setToolbarHidden:YES];
    [self.navigationController setNavigationBarHidden:YES];
    self.navigationController.navigationBar.translucent = YES;
    self.navigationController.toolbar.translucent = YES;

    self.browserTakeShopshotButton  =
            [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCamera target:self
                                                          action:@selector(takeSnapshot:)];

}

- (void) takeSnapshot:(id) sender {
    NSLog(@"take snapshot");
 //   self.snapshotEnabled = !self.snapshotEnabled;
 //   [self.webBrowser enableSnapshot:self.snapshotEnabled];

    KINSnapshotExampleViewController *snapshotExampleViewController =
            [[KINSnapshotExampleViewController alloc] initWithBrowser:self.webBrowser];

    UINavigationController *navigationController =
            [[UINavigationController alloc] initWithRootViewController:snapshotExampleViewController];
    [self presentViewController:navigationController animated:YES completion:^{

    }];

}

- (NSArray *)webBrowser:(KINWebBrowserViewController *)webBrowser toolbarItems:(NSArray *)items {

    if(webBrowser.isLoading) {
        return @[
                items[KINBrowserToolbarButtonIndexBack],
                items[KINBrowserToolbarButtonIndexFixedSeparator1],
                items[KINBrowserToolbarButtonIndexForward],
                items[KINBrowserToolbarButtonIndexFixedSeparator2],
                items[KINBrowserToolbarButtonIndexStop],
                items[KINBrowserToolbarButtonIndexFlexibleSeparator1],
                self.browserTakeShopshotButton,
                webBrowser.browserActionButton
        ];
    } else {
        return @[
                items[KINBrowserToolbarButtonIndexBack],
                items[KINBrowserToolbarButtonIndexFixedSeparator1],
                items[KINBrowserToolbarButtonIndexForward],
                items[KINBrowserToolbarButtonIndexFixedSeparator2],
                items[KINBrowserToolbarButtonIndexRefresh],
                items[KINBrowserToolbarButtonIndexFlexibleSeparator1],
                self.browserTakeShopshotButton,
                webBrowser.browserActionButton
        ];
    }
}

#pragma mark - KINWebBrowserDelegate Protocol Implementation

- (void)webBrowser:(KINWebBrowserViewController *)webBrowser didStartLoadingURL:(NSURL *)URL {
    NSLog(@"Started Loading URL : %@", URL);
}

- (void)webBrowser:(KINWebBrowserViewController *)webBrowser didFinishLoadingURL:(NSURL *)URL {
    NSLog(@"Finished Loading URL : %@", URL);
}

- (void)webBrowser:(KINWebBrowserViewController *)webBrowser didFailToLoadURL:(NSURL *)URL error:(NSError *)error {
    NSLog(@"Failed To Load URL : %@ With Error: %@", URL, error);
}

- (void)webBrowserViewControllerWillDismiss:(KINWebBrowserViewController*)viewController {
	NSLog(@"View Controller will dismiss: %@", viewController);
	
}


#pragma mark - IBActions

- (IBAction)pushButtonPressed:(id)sender {
    KINWebBrowserViewController *webBrowser =  self.webBrowser = [KINWebBrowserViewController webBrowser];
    [webBrowser setDelegate:self];
    [self.navigationController pushViewController:webBrowser animated:YES];
    [webBrowser loadURLString:defaultAddress];
}

- (IBAction)presentButtonPressed:(id)sender {
    UINavigationController *webBrowserNavigationController = [KINWebBrowserViewController navigationControllerWithWebBrowser];
    KINWebBrowserViewController *webBrowser = self.webBrowser = [webBrowserNavigationController rootWebBrowser];
    [webBrowser setDelegate:self];
    webBrowser.showsURLInNavigationBar = YES;
    webBrowser.tintColor = [UIColor whiteColor];
    webBrowser.barTintColor = [UIColor colorWithRed:102.0f/255.0f green:204.0f/255.0f blue:51.0f/255.0f alpha:1.0f];
    webBrowser.showsPageTitleInNavigationBar = NO;
    webBrowser.showsURLInNavigationBar = NO;
    [self presentViewController:webBrowserNavigationController animated:YES completion:nil];

    [webBrowser loadURLString:defaultAddress];
}
@end
