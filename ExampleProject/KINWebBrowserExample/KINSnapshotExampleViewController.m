//
// Created by James Whitfield on 7/28/16.
// Copyright (c) 2016 Kinwa, Inc. All rights reserved.
//

#import "KINSnapshotExampleViewController.h"
#import "KINWebBrowserViewController.h"

@interface KINSnapshotExampleViewController ()
@property (nonatomic,retain) UIScrollView *scrollView;
@property (nonatomic,retain) UIImageView *imageView;
@end

@implementation KINSnapshotExampleViewController {}


- (instancetype)initWithBrowser: (KINWebBrowserViewController *) browserViewController {
    if(self = [super initWithNibName:nil bundle:nil]) {

    }

    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.scrollView = [[UIScrollView alloc] initWithFrame:self.view.bounds];
    self.scrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.imageView = [[UIImageView alloc] initWithFrame:self.view.bounds];
    self.navigationItem.leftBarButtonItems = @[
             [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(cancel:)]
    ];

    [self.scrollView addSubview:self.imageView];
    [self.view addSubview:self.scrollView];
}

- (void) cancel: (id) sender {
    [self dismissViewControllerAnimated:YES completion:^{

    }];
}

@end