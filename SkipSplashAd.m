//
//  SkipSplashAd.m
//  Dopamine iOS 15-16 无根越狱专用
//  修复白屏问题 + 添加设置支持
//

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

#define DEBUG_MODE YES
#if DEBUG_MODE
#define Log(fmt, ...) NSLog(@"[SkipSplashAd] " fmt, ##__VA_ARGS__)
#else
#define Log(fmt, ...)
#endif

// 从设置读取的配置
static NSDictionary *settings = nil;
static NSArray *skipKeywords = nil;
static NSArray *whitelist = nil;
static NSArray *blacklist = nil;
static BOOL enabled = YES;
static BOOL autoClick = NO;

// 默认配置
static NSArray *defaultSkipKeywords = @[
    @"splash", @"Splash", @"SPLASH",
    @"launchAd", @"LaunchAd", @"ADView",
    @"advertisement", @"Advertisement",
    @"GDTSplashAd", @"MobSplash",
    @"BaiduMobAdSplash", @"GDTMobAdSplash",
    @"splashAdView", @"adContainer"
];

static NSArray *defaultWhitelist = @[
    @"com.apple.mobilesafari",
    @"com.apple.Preferences",
    @"com.apple.AppStore",
    @"com.apple.MobileSMS",
    @"com.tencent.xin",
    @"com.alipay.iphoneAlipay"
];

// 加载设置
static void loadSettings() {
    NSString *settingsPath = @"/var/mobile/Library/Preferences/com.tweaks.skipsplashad.plist";
    settings = [NSDictionary dictionaryWithContentsOfFile:settingsPath];
    
    if (!settings) {
        settings = @{
            @"enabled": @YES,
            @"autoClick": @NO,
            @"skipKeywords": defaultSkipKeywords,
            @"whitelist": defaultWhitelist,
            @"blacklist": @[]
        };
    }
    
    enabled = [settings[@"enabled"] boolValue];
    autoClick = [settings[@"autoClick"] boolValue];
    skipKeywords = settings[@"skipKeywords"] ?: defaultSkipKeywords;
    whitelist = settings[@"whitelist"] ?: defaultWhitelist;
    blacklist = settings[@"blacklist"] ?: @[];
}

// 检查是否是广告视图（更精确）
static BOOL isAdView(UIView *view) {
    NSString *className = NSStringFromClass([view class]);
    NSString *description = view.description ?: @"";
    
    // 检查类名
    for (NSString *keyword in skipKeywords) {
        if ([className containsString:keyword]) {
            return YES;
        }
    }
    
    // 检查子视图是否包含广告元素
    for (UIView *subview in view.subviews) {
        NSString *subClass = NSStringFromClass([subview class]);
        for (NSString *keyword in skipKeywords) {
            if ([subClass containsString:keyword]) {
                return YES;
            }
        }
    }
    
    return NO;
}

// 检查是否应该跳过此应用
static BOOL shouldSkipApp() {
    NSString *bundleId = [[NSBundle mainBundle] bundleIdentifier];
    
    // 检查白名单
    for (NSString *white in whitelist) {
        if ([bundleId isEqualToString:white] || [bundleId containsString:white]) {
            Log(@"白名单应用: %@", bundleId);
            return NO;
        }
    }
    
    // 检查黑名单（优先）
    for (NSString *black in blacklist) {
        if ([bundleId isEqualToString:black] || [bundleId containsString:black]) {
            Log(@"黑名单应用，强制跳过: %@", bundleId);
            return YES;
        }
    }
    
    return YES;
}

// 智能隐藏广告 - 避免白屏
static void smartHideAd(UIView *view) {
    if (!view || view.hidden) return;
    
    // 方法1: 直接隐藏（可能白屏）
    // view.hidden = YES;
    
    // 方法2: 降低透明度（推荐，避免白屏）
    view.alpha = 0.0;
    
    // 方法3: 缩小到看不见
    // CGRect frame = view.frame;
    // view.frame = CGRectMake(0, 0, 1, 1);
    
    // 方法4: 移到屏幕外
    // CGRect frame = view.frame;
    // frame.origin.y = -10000;
    // view.frame = frame;
    
    // 禁用用户交互
    view.userInteractionEnabled = NO;
    
    // 尝试点击"跳过"按钮
    if (autoClick) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            clickSkipButton(view);
        });
    }
    
    Log(@"隐藏广告视图: %@", NSStringFromClass([view class]));
}

// 自动点击跳过按钮
static void clickSkipButton(UIView *view) {
    // 查找跳过按钮
    NSArray *skipTexts = @[@"跳过", @"Skip", @"skip", @"关闭", @"Close", @"X", @"×"];
    
    for (UIView *subview in view.subviews) {
        if ([subview isKindOfClass:[UIButton class]]) {
            UIButton *btn = (UIButton *)subview;
            NSString *title = [btn titleForState:UIControlStateNormal] ?: @"";
            
            for (NSString *text in skipTexts) {
                if ([title containsString:text]) {
                    Log(@"自动点击跳过按钮: %@", title);
                    [btn sendActionsForControlEvents:UIControlEventTouchUpInside];
                    return;
                }
            }
        }
        
        // 递归查找
        clickSkipButton(subview);
    }
}

// 遍历视图树
static void scanViewTree(UIView *view, int depth) {
    if (!view || depth > 10) return;
    
    // 检查是否是广告
    if (isAdView(view)) {
        smartHideAd(view);
        return; // 找到广告就不继续深入
    }
    
    // 检查全屏广告容器
    CGRect frame = view.frame;
    BOOL isFullScreen = (frame.size.width >= [UIScreen mainScreen].bounds.size.width * 0.8 && 
                         frame.size.height >= [UIScreen mainScreen].bounds.size.height * 0.8);
    
    if (isFullScreen && depth <= 3) {
        // 可能是广告容器，检查子视图
        for (UIView *subview in view.subviews) {
            if (isAdView(subview)) {
                smartHideAd(view);
                return;
            }
        }
    }
    
    // 递归
    for (UIView *subview in view.subviews) {
        scanViewTree(subview, depth + 1);
    }
}

// 定时扫描
static void startAdKiller() {
    if (!enabled) {
        Log(@"插件已禁用");
        return;
    }
    
    if (!shouldSkipApp()) return;
    
    static dispatch_source_t timer = nil;
    if (timer) return;
    
    timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
    dispatch_source_set_timer(timer, DISPATCH_TIME_NOW, 0.5 * NSEC_PER_SEC, 0.1 * NSEC_PER_SEC);
    
    dispatch_source_set_event_handler(timer, ^{
        @try {
            NSArray *windows = [[UIApplication sharedApplication] windows];
            for (UIWindow *window in windows) {
                if (!window.hidden && window.alpha > 0) {
                    scanViewTree(window, 0);
                }
            }
        } @catch (NSException *exception) {
            Log(@"异常: %@", exception);
        }
    });
    
    dispatch_resume(timer);
    Log(@"广告拦截已启动");
}

// 监听设置变化
static void settingsChanged(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    Log(@"设置已更改，重新加载");
    loadSettings();
}

__attribute__((constructor))
static void initialize() {
    Log(@"SkipSplashAd 加载成功");
    
    // 加载设置
    loadSettings();
    
    // 监听设置变化
    CFNotificationCenterAddObserver(
        CFNotificationCenterGetDarwinNotifyCenter(),
        NULL,
        settingsChanged,
        CFSTR("com.tweaks.skipsplashad/settingsChanged"),
        NULL,
        CFNotificationSuspensionBehaviorCoalesce
    );
    
    // 延迟启动
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1.0 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        startAdKiller();
    });
}