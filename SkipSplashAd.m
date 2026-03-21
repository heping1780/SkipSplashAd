//
//  SkipSplashAd.m
// 暴力10秒扫描点击
//

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

#define DEBUG_MODE YES
#if DEBUG_MODE
#define Log(fmt, ...) NSLog(@"[SkipSplashAd] " fmt, ##__VA_ARGS__)
#else
#define Log(fmt, ...)
#endif

static NSArray *whitelist = @[
    @"com.apple.mobilesafari",
    @"com.tencent.xin",
    @"com.alipay.iphoneAlipay"
];

static BOOL isWhitelistApp() {
    NSString *bundleId = [[NSBundle mainBundle] bundleIdentifier];
    for (NSString *white in whitelist) {
        if ([bundleId isEqualToString:white]) return YES;
    }
    return NO;
}

static void clickAllSkipButtons(UIView *view) {
    if (!view) return;
    
    if ([view isKindOfClass:[UIButton class]]) {
        UIButton *btn = (UIButton *)view;
        NSString *title = [btn titleForState:UIControlStateNormal] ?: @"";
        NSString *titleHigh = [btn titleForState:UIControlStateHighlighted] ?: @"";
        
        NSArray *skipWords = @[@"跳过", @"Skip", @"skip", @"SKIP", @"跳过广告", @"关闭", @"X", @"×", @"close", @"CLOSE", @"倒计时", @"广告"];
        
        for (NSString *word in skipWords) {
            if ([title containsString:word] || [titleHigh containsString:word]) {
                Log(@"点击: %@", title);
                [btn sendActionsForControlEvents:UIControlEventTouchUpInside];
            }
        }
    }
    
    for (UIView *subview in view.subviews) {
        clickAllSkipButtons(subview);
    }
}

static void scanAndClick() {
    if (isWhitelistApp()) return;
    
    Log(@"扫描10秒...");
    
    NSArray *windows = [[UIApplication sharedApplication] windows];
    for (UIWindow *win in windows) {
        if (!win.hidden) {
            clickAllSkipButtons(win);
        }
    }
}

__attribute__((constructor))
static void init() {
    Log(@"SkipSplashAd 10秒版加载");
    
    // 0.1秒开始扫描
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        scanAndClick();
    });
    
    // 持续扫描10秒，每0.5秒一次
    for (int i = 1; i <= 20; i++) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, i * 0.5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            scanAndClick();
        });
    }
}
