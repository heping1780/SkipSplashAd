//
//  SkipSplashAd.m
//  Simple version
//

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

#define DEBUG_MODE YES
#if DEBUG_MODE
#define Log(fmt, ...) NSLog(@"[SkipSplashAd] " fmt, ##__VA_ARGS__)
#else
#define Log(fmt, ...)
#endif

static NSArray *skipKeywords = @[
    @"splash", @"Splash", @"launchAd", @"ADView", @"advertisement", @"GDTSplashAd"
];

static NSArray *whitelist = @[
    @"com.apple.mobilesafari", @"com.tencent.xin", @"com.alipay.iphoneAlipay"
];

static BOOL shouldSkipApp() {
    NSString *bundleId = [[NSBundle mainBundle] bundleIdentifier];
    for (NSString *white in whitelist) {
        if ([bundleId isEqualToString:white]) return NO;
    }
    return YES;
}

static void hideAdView(UIView *view, int depth) {
    if (!view || depth > 8) return;
    
    NSString *className = NSStringFromClass([view class]);
    CGRect frame = view.frame;
    BOOL isFullScreen = (frame.size.width >= [UIScreen mainScreen].bounds.size.width * 0.9 && 
                         frame.size.height >= [UIScreen mainScreen].bounds.size.height * 0.9);
    
    BOOL isAd = NO;
    for (NSString *kw in skipKeywords) {
        if ([className containsString:kw]) { isAd = YES; break; }
    }
    
    if ((isAd || isFullScreen) && shouldSkipApp() && ![className containsString:@"LaunchScreen"]) {
        view.alpha = 0;
        view.userInteractionEnabled = NO;
        Log(@"Hidden: %@", className);
    }
    
    for (UIView *sub in view.subviews) {
        hideAdView(sub, depth + 1);
    }
}

static void startKiller() {
    static dispatch_source_t timer = nil;
    if (timer) return;
    
    timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
    dispatch_source_set_timer(timer, DISPATCH_TIME_NOW, 1.0 * NSEC_PER_SEC, 0.1 * NSEC_PER_SEC);
    
    dispatch_source_set_event_handler(timer, ^{
        @try {
            for (UIWindow *win in [[UIApplication sharedApplication] windows]) {
                if (!win.hidden) hideAdView(win, 0);
            }
        } @catch (NSException *e) { Log(@"Error: %@", e); }
    });
    
    dispatch_resume(timer);
    Log(@"Started");
}

__attribute__((constructor))
static void init() {
    Log(@"SkipSplashAd loaded");
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        startKiller();
    });
}