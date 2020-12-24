//
//  MARecordWindowController.m
//  MacTest
//
//  Created by 马英伦 on 2020/12/6.
//  Copyright © 2020 马英伦. All rights reserved.
//

#import "MARecordWindowController.h"
#import "MARecordViewController.h"

@interface MARecordWindowController ()

@end

@implementation MARecordWindowController

- (void)windowDidLoad {
    [super windowDidLoad];
    
    MARecordViewController *vc = [[MARecordViewController alloc] init];
    self.window.contentViewController = vc;
}

@end
