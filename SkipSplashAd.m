//
//  SkipSplashAd.m
//  Dopamine iOS 15-16 无根越狱专用
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
    @"splash", @"Splash", @"SPLASH",
    @"launch", @"Launch", @"LAUNCH",
    @"advertisement", @"Advertisement", @"ADVERTISEMENT",
    @"adview", @"ADView", @"GDTSplashAd", @"MobSplash",
    @"flash", @"Flash"
];

static NSArray *whitelist = @[
    @"com.apple.mobilesafari",
    @"com.apple.Preferences",
    @"com.apple.AppStore",
    @"com.apple.MobileSMS",
    @"com.tencent.xin",
    @"com.alipay.iphoneAlipay",
    @"com.baidu.netdisk",
    @"com.duokan.phone",
];

static int skipCount = 0;

void hideSplashAdView(UIView *view, int depth) {
    if (!view || depth > 8) return;
    
    NSString *className = NSStringFromClass([view class]);
    NSString *description = view.description ?: @"";
    
    BOOL isAdView = NO;
    for (NSString *keyword in skipKeywords) {
        if ([className containsString:keyword] || [description containsString:keyword]) {
            isAdView = YES;
            break;
        }
    }
    
    CGRect frame = view.frame;
    BOOL isFullScreen = (frame.size.width >= [UIScreen mainScreen].bounds.size.width * 0.9 && 
                         frame.size.height >= [UIScreen mainScreen].bounds.size.height * 0.9);
    
    if (isAdView || (isFullScreen && ![description containsString:@"UIWindow"])) {
        NSString *bundleId = [[NSBundle mainBundle] bundleIdentifier];
        
        BOOL inWhitelist = NO;
        for (NSString *white in whitelist) {
            if ([bundleId containsString:white]) {
                inWhitelist = YES;
                break;
            }
        }
        
        if (!inWhitelist && (isAdView || isFullScreen)) {
            if ([description containsString:@"LaunchScreen"] || 
                [className containsString:@"LaunchScreen"] ||
                [className containsString:@"_UIFloatingBackgroundView"]) {
                Log(@"保留引导页: %@", className);
                return;
            }
            
            Log(@"隐藏广告: %@", className);
            view.hidden = YES;
            skipCount++;
        }
    }
    
    for (UIView *subview in view.subviews) {
        hideSplashAdView(subview, depth + 1);
    }
}

static void startAdKiller() {
    static dispatch_source_t timer = nil;
    if (timer) return;
    
    timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
    dispatch_source_set_timer(timer, DISPATCH_TIME_NOW, 1.0 * NSEC_PER_SEC, 0.1 * NSEC_PER_SEC);
    
    dispatch_source_set_event_handler(timer, ^{
        @try {
            NSArray *windows = [[UIApplication sharedApplication] windows];
            for (UIWindow *window in windows) {
                if (!window.hidden) {
                    hideSplashAdView(window, 0);
                }
            }
        } @catch (NSException *exception) {
            Log(@"异常: %@", exception);
        }
    });
    
    dispatch_resume(timer);
    Log(@"广告拦截已启动");
}

__attribute__((constructor))
static void initialize() {
    Log(@"SkipSplashAd 加载成功");
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        startAdKiller();
    });
}