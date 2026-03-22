//
//  AutoClick.m
//  自动点击插件 - Dopamine Roothide 越狱专用
//  支持：文字匹配、控件匹配、坐标点击
//  支持：应用启动后N秒内自动点击
//  支持：分应用控制，默认黑名单模式
//

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

#define Log(fmt, ...) NSLog(@"[AutoClick] " fmt, ##__VA_ARGS__)

// ============================================================
// 配置文件路径
// ============================================================
static NSString *kSettingsPath = @"/var/mobile/Library/Preferences/com.tweaks.autoclick.plist";

// ============================================================
// 配置结构
// ============================================================
static NSDictionary *gSettings = nil;
static BOOL gEnabled = YES;

// 加载配置
static void loadSettings() {
    NSDictionary *s = [NSDictionary dictionaryWithContentsOfFile:kSettingsPath];
    if (s) {
        gSettings = s;
        gEnabled = [s[@"enabled"] boolValue];
    } else {
        // 默认配置
        gEnabled = YES;
        gSettings = @{
            @"enabled": @YES,
            @"mode": @"blacklist",  // blacklist = 默认对所有应用生效，whitelist = 只对指定应用生效
            @"apps": @{},           // 分应用配置
            @"globalRules": @[]     // 全局规则
        };
    }
    Log(@"配置已加载, enabled=%d", gEnabled);
}

// ============================================================
// 模拟点击核心
// ============================================================

// 模拟点击指定坐标
static void simulateTapAtPoint(CGPoint point) {
    UIWindow *window = [[UIApplication sharedApplication] keyWindow];
    if (!window) return;
    
    // 发送触摸事件
    UIView *hitView = [window hitTest:point withEvent:nil];
    if (hitView) {
        Log(@"坐标点击: (%.1f, %.1f) -> %@", point.x, point.y, NSStringFromClass([hitView class]));
        
        // 模拟触摸
        [hitView touchesBegan:[NSSet set] withEvent:nil];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            [hitView touchesEnded:[NSSet set] withEvent:nil];
        });
        
        // 如果是按钮，直接触发
        if ([hitView isKindOfClass:[UIButton class]]) {
            [(UIButton *)hitView sendActionsForControlEvents:UIControlEventTouchUpInside];
        }
    }
}

// 递归查找并点击匹配文字的控件
static BOOL clickViewWithText(UIView *view, NSString *text, int depth) {
    if (!view || depth > 10) return NO;
    
    // 检查 UIButton
    if ([view isKindOfClass:[UIButton class]]) {
        UIButton *btn = (UIButton *)view;
        NSString *title = [btn titleForState:UIControlStateNormal] ?: @"";
        if ([title containsString:text]) {
            Log(@"文字点击按钮: %@", title);
            [btn sendActionsForControlEvents:UIControlEventTouchUpInside];
            return YES;
        }
    }
    
    // 检查 UILabel
    if ([view isKindOfClass:[UILabel class]]) {
        UILabel *label = (UILabel *)view;
        if ([label.text containsString:text] && view.userInteractionEnabled) {
            Log(@"文字点击Label: %@", label.text);
            CGPoint center = CGPointMake(view.frame.origin.x + view.frame.size.width/2,
                                         view.frame.origin.y + view.frame.size.height/2);
            simulateTapAtPoint([view.superview convertPoint:center toView:nil]);
            return YES;
        }
    }
    
    // 检查 accessibilityLabel
    NSString *accLabel = view.accessibilityLabel ?: @"";
    if ([accLabel containsString:text] && view.userInteractionEnabled) {
        Log(@"无障碍标签点击: %@", accLabel);
        CGPoint center = CGPointMake(view.frame.origin.x + view.frame.size.width/2,
                                     view.frame.origin.y + view.frame.size.height/2);
        simulateTapAtPoint([view.superview convertPoint:center toView:nil]);
        return YES;
    }
    
    // 递归子视图
    for (UIView *subview in view.subviews) {
        if (clickViewWithText(subview, text, depth + 1)) return YES;
    }
    
    return NO;
}

// 递归查找并点击匹配类名的控件
static BOOL clickViewWithClass(UIView *view, NSString *className, int depth) {
    if (!view || depth > 10) return NO;
    
    NSString *viewClass = NSStringFromClass([view class]);
    if ([viewClass containsString:className]) {
        Log(@"控件点击: %@", viewClass);
        if ([view isKindOfClass:[UIButton class]]) {
            [(UIButton *)view sendActionsForControlEvents:UIControlEventTouchUpInside];
        } else {
            CGPoint center = CGPointMake(view.frame.origin.x + view.frame.size.width/2,
                                         view.frame.origin.y + view.frame.size.height/2);
            simulateTapAtPoint([view.superview convertPoint:center toView:nil]);
        }
        return YES;
    }
    
    for (UIView *subview in view.subviews) {
        if (clickViewWithClass(subview, className, depth + 1)) return YES;
    }
    
    return NO;
}

// ============================================================
// 执行规则
// ============================================================
static void executeRule(NSDictionary *rule) {
    NSString *mode = rule[@"mode"] ?: @"text";  // text / class / coordinate
    
    if ([mode isEqualToString:@"text"]) {
        // 文字匹配模式
        NSString *text = rule[@"text"] ?: @"";
        NSArray *windows = [[UIApplication sharedApplication] windows];
        for (UIWindow *win in windows) {
            if (!win.hidden && clickViewWithText(win, text, 0)) {
                Log(@"文字规则执行成功: %@", text);
                return;
            }
        }
        Log(@"文字规则未找到: %@", text);
        
    } else if ([mode isEqualToString:@"class"]) {
        // 控件类名模式
        NSString *className = rule[@"className"] ?: @"";
        NSArray *windows = [[UIApplication sharedApplication] windows];
        for (UIWindow *win in windows) {
            if (!win.hidden && clickViewWithClass(win, className, 0)) {
                Log(@"控件规则执行成功: %@", className);
                return;
            }
        }
        Log(@"控件规则未找到: %@", className);
        
    } else if ([mode isEqualToString:@"coordinate"]) {
        // 坐标模式
        CGFloat x = [rule[@"x"] floatValue];
        CGFloat y = [rule[@"y"] floatValue];
        
        // 支持百分比坐标
        if ([rule[@"percent"] boolValue]) {
            CGSize screen = [UIScreen mainScreen].bounds.size;
            x = x * screen.width / 100.0;
            y = y * screen.height / 100.0;
        }
        
        Log(@"坐标规则执行: (%.1f, %.1f)", x, y);
        simulateTapAtPoint(CGPointMake(x, y));
    }
}

// ============================================================
// 主逻辑：应用启动后执行规则
// ============================================================
static void startAutoClick() {
    if (!gEnabled) return;
    
    NSString *bundleId = [[NSBundle mainBundle] bundleIdentifier];
    if (!bundleId) return;
    
    Log(@"应用启动: %@", bundleId);
    
    // 获取当前应用的规则
    NSArray *rules = nil;
    NSDictionary *apps = gSettings[@"apps"];
    
    if (apps[bundleId]) {
        // 有专属规则
        NSDictionary *appConfig = apps[bundleId];
        
        // 检查是否禁用
        if ([appConfig[@"disabled"] boolValue]) {
            Log(@"应用已禁用: %@", bundleId);
            return;
        }
        
        rules = appConfig[@"rules"];
    } else {
        // 使用全局规则
        NSString *globalMode = gSettings[@"mode"] ?: @"blacklist";
        
        if ([globalMode isEqualToString:@"whitelist"]) {
            // 白名单模式：只对指定应用生效
            Log(@"白名单模式，应用不在列表中: %@", bundleId);
            return;
        }
        
        // 黑名单模式：对所有应用生效
        rules = gSettings[@"globalRules"];
    }
    
    if (!rules || rules.count == 0) {
        // 没有规则时，使用默认跳过广告规则
        rules = @[
            @{@"mode": @"text", @"text": @"跳过", @"delay": @0.5},
            @{@"mode": @"text", @"text": @"Skip", @"delay": @0.5},
            @{@"mode": @"text", @"text": @"跳过广告", @"delay": @0.5},
            @{@"mode": @"text", @"text": @"关闭广告", @"delay": @0.5},
        ];
    }
    
    // 执行规则
    for (NSDictionary *rule in rules) {
        NSTimeInterval delay = [rule[@"delay"] doubleValue];
        if (delay <= 0) delay = 0.5;
        
        // 重复次数（默认在5秒内每0.5秒执行一次）
        NSInteger repeat = [rule[@"repeat"] integerValue];
        if (repeat <= 0) repeat = 10;
        
        for (NSInteger i = 0; i < repeat; i++) {
            NSTimeInterval totalDelay = delay + i * 0.5;
            NSDictionary *ruleCopy = [rule copy];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, totalDelay * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                executeRule(ruleCopy);
            });
        }
    }
}

// ============================================================
// 监听设置变化
// ============================================================
static void settingsChanged(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    loadSettings();
}

// ============================================================
// 构造函数
// ============================================================
__attribute__((constructor))
static void initialize() {
    Log(@"AutoClick 加载");
    
    loadSettings();
    
    // 监听设置变化
    CFNotificationCenterAddObserver(
        CFNotificationCenterGetDarwinNotifyCenter(),
        NULL,
        settingsChanged,
        CFSTR("com.tweaks.autoclick/settingsChanged"),
        NULL,
        CFNotificationSuspensionBehaviorCoalesce
    );
    
    // 延迟启动，等应用完全加载
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.3 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        startAutoClick();
    });
}
