//
//  SkipSplashAd.m
//  2秒内检测"跳过"按钮并点击
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
    @"com.apple.Preferences",
    @"com.tencent.xin",
    @"com.alipay.iphoneAlipay"
];

// 检测应用是否在白名单
static BOOL isWhitelistApp() {
    NSString *bundleId = [[NSBundle mainBundle] bundleIdentifier];
    for (NSString *white in whitelist) {
        if ([bundleId isEqualToString:white]) return YES;
    }
    return NO;
}

// 查找并点击"跳过"按钮
static void clickSkipButton(UIView *view) {
    if (!view) return;
    
    // 检查是否是按钮
    if ([view isKindOfClass:[UIButton class]]) {
        UIButton *btn = (UIButton *)view;
        NSString *title = [btn titleForState:UIControlStateNormal] ?: @"";
        NSString *titleHighlighted = [btn titleForState:UIControlStateHighlighted] ?: @"";
        
        // 检查标题是否包含跳过相关文字
        NSArray *skipTexts = @[@"跳过", @"Skip", @"skip", @"SKIP", @"跳过广告", @"跳过倒计时", @"seconds"];
        
        for (NSString *text in skipTexts) {
            if ([title containsString:text] || [titleHighlighted containsString:text]) {
                Log(@"找到跳过按钮: %@", title);
                [btn sendActionsForControlEvents:UIControlEventTouchUpInside];
                return;
            }
        }
    }
    
    // 递归检查子视图
    for (UIView *subview in view.subviews) {
        clickSkipButton(subview);
    }
}

// 遍历视图找跳过按钮
static void findAndClickSkip(UIView *view, int depth) {
    if (!view || depth > 8) return;
    
    clickSkipButton(view);
    
    for (UIView *subview in view.subviews) {
        findAndClickSkip(subview, depth + 1);
    }
}

// 启动检测（只在开屏2秒内检测）
static void startSkipDetection() {
    if (isWhitelistApp()) {
        Log(@"白名单应用，跳过检测");
        return;
    }
    
    Log(@"开始检测跳过按钮...");
    
    // 立即检测一次
    dispatch_async(dispatch_get_main_queue(), ^{
        for (UIWindow *win in [[UIApplication sharedApplication] windows]) {
            findAndClickSkip(win, 0);
        }
    });
    
    // 0.5秒后再检测一次
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        for (UIWindow *win in [[UIApplication sharedApplication] windows]) {
            findAndClickSkip(win, 0);
        }
    });
    
    // 1秒后再检测一次
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1.0 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        for (UIWindow *win in [[UIApplication sharedApplication] windows]) {
            findAndClickSkip(win, 0);
        }
    });
    
    // 2秒后再检测一次（最后机会）
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2.0 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        for (UIWindow *win in [[UIApplication sharedApplication] windows]) {
            findAndClickSkip(win, 0);
        }
    });
}

__attribute__((constructor))
static void init() {
    Log(@"SkipSplashAd loaded - 2秒点击模式");
    
    // 应用启动时延迟检测
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.3 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        startSkipDetection();
    });
}