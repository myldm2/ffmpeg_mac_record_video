//
//  AppDelegate.m
//  EncodeVideo
//
//  Created by 马英伦 on 2020/12/23.
//

#import "AppDelegate.h"
#import "libavutil/ffversion.h"

@interface AppDelegate ()


@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    // Insert code here to initialize your application
    
    NSLog(@"mayinglun log: %s", FFMPEG_VERSION);
    
}


- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}


@end
