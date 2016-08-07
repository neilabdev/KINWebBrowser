//
// Created by James Whitfield on 7/28/16.
// Copyright (c) 2016 Kinwa, Inc. All rights reserved.
//

#import "KINSnapshotExampleViewController.h"
#import "KINWebBrowserViewController.h"

@interface KINSnapshotExampleViewController ()
@property (nonatomic,retain) UIScrollView *scrollView;
@property (nonatomic,retain) UIImageView *imageView;
@property (nonatomic,retain) KINWebBrowserViewController *browser;
@end

@implementation KINSnapshotExampleViewController {}


- (instancetype)initWithBrowser: (KINWebBrowserViewController *) browserViewController {
    if(self = [super initWithNibName:nil bundle:nil]) {
        self.browser = browserViewController;
    }

    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.automaticallyAdjustsScrollViewInsets = NO;
    self.view.opaque = NO;
    self.scrollView = [[UIScrollView alloc] initWithFrame:self.view.bounds];
    self.scrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.imageView = [[UIImageView alloc] initWithFrame:self.view.bounds];
  //  self.imageView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.navigationItem.leftBarButtonItems = @[
             [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(cancel:)]
    ];

    [self.scrollView addSubview:self.imageView];
    [self.view addSubview:self.scrollView];
    [self.browser performScreenshotWithOptions:KINBrowserSnapshotOptionProgressive  progress:^(KINWebBrowserSnapshotProgress * progress)  {

    } completed:^(UIImage *image, NSError *error, BOOL finished) {
        if(finished) {
            self.imageView.image = image;
            self.scrollView.contentSize = image.size;
        }
    }];
}

- (void) cancel: (id) sender {
    [self dismissViewControllerAnimated:YES completion:^{

    }];
}

@end