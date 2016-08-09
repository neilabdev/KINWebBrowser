//
// Created by James Whitfield on 7/28/16.
// Copyright (c) 2016 Kinwa, Inc. All rights reserved.
//

#import "KINSnapshotExampleViewController.h"
#import "KINWebBrowserViewController.h"

@interface KINSnapshotExampleViewController ()
@property (nonatomic,retain) UIScrollView *scrollView;
@property (nonatomic,retain) UIImageView *imageView;
//@property (nonatomic,retain) KINWebBrowserViewController *browser;
@property (nonatomic,retain) UIImage *image;
@end

@implementation KINSnapshotExampleViewController {}


- (instancetype)initWithImage: (UIImage *) image {
    if(self = [super initWithNibName:nil bundle:nil]) {
        self.image = image;
    }

    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.automaticallyAdjustsScrollViewInsets = YES;
  //  self.view.opaque = NO;
    self.scrollView = [[UIScrollView alloc] initWithFrame:self.view.bounds];
    self.scrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.scrollView.contentSize = self.image.size;
    self.imageView = [[UIImageView alloc] initWithFrame:CGRectMake(0,0,self.image.size.height,self.image.size.height)];
   self.imageView.contentMode = UIViewContentModeTopLeft;
    self.imageView.image = self.image;
    self.imageView.backgroundColor = [UIColor redColor];
  //  self.imageView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
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