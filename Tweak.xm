#import <UIKit/UIKit.h>

// ==========================================
// 缓存管理中心：负责记忆原始消息文本与富文本
// 具备内存 + 磁盘持久化，划掉后台也不会丢失原文
// ==========================================
@interface AntiRevokeManager : NSObject
+ (void)saveText:(NSString *)text forKey:(NSString *)key;
+ (NSString *)getTextForKey:(NSString *)key;
@end

@implementation AntiRevokeManager

static NSMutableDictionary *s_memoryCache = nil;

+ (void)initialize {
    if (self == [AntiRevokeManager class]) {
        s_memoryCache = [[NSMutableDictionary alloc] initWithCapacity:1000];
        // 启动时从本地沙盒加载历史备份
        NSDictionary *saved = [[NSUserDefaults standardUserDefaults] objectForKey:@"WWK_AntiRevoke_SavedCache"];
        if (saved) {
            [s_memoryCache addEntriesFromDictionary:saved];
        }
    }
}

+ (void)saveText:(NSString *)text forKey:(NSString *)key {
    if (!key || key.length == 0 || !text || text.length == 0) return;
    if ([text containsString:@"撤回了一条消息"]) return; // 不缓存撤回提示
    
    @synchronized (s_memoryCache) {
        s_memoryCache[key] = text;
        // 限制缓存上限为 1000 条，防止体积过大
        if (s_memoryCache.count > 1000) {
            NSString *firstKey = s_memoryCache.allKeys.firstObject;
            if (firstKey) [s_memoryCache removeObjectForKey:firstKey];
        }
        // 异步持久化到沙盒
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
            [[NSUserDefaults standardUserDefaults] setObject:[s_memoryCache copy] forKey:@"WWK_AntiRevoke_SavedCache"];
        });
    }
}

+ (NSString *)getTextForKey:(NSString *)key {
    if (!key || key.length == 0) return nil;
    @synchronized (s_memoryCache) {
        return s_memoryCache[key];
    }
}

@end

// ==========================================
// 1. 核心模型层：捕获原文 + 动态“还魂”
// ==========================================
%hook WWKMessage

// 消息出生阶段：只要拿到原始文本，立刻自动备案
- (id)initWithMessage:(id)arg1 {
    id res = %orig;
    if (res) {
        id k = [(id)res valueForKey:@"msgKey"];
        NSString *t = [res text];
        if (k && t && t.length > 0 && ![t containsString:@"撤回了一条消息"]) {
            [AntiRevokeManager saveText:t forKey:[NSString stringWithFormat:@"%@", k]];
        }
    }
    return res;
}

// 纯文本渲染拦截
- (NSString *)text {
    NSString *orig = %orig;
    id k = [(id)self valueForKey:@"msgKey"];
    if (k) {
        NSString *key = [NSString stringWithFormat:@"%@", k];
        // 正常消息：自动更新缓存
        if (orig && orig.length > 0 && ![orig containsString:@"撤回了一条消息"]) {
            [AntiRevokeManager saveText:orig forKey:key];
            return orig;
        }
        // 遇到已被撤回的消息：从缓存中调出原文还魂
        if (orig && [orig containsString:@"撤回了一条消息"]) {
            NSString *saved = [AntiRevokeManager getTextForKey:key];
            if (saved && saved.length > 0) {
                return [NSString stringWithFormat:@"%@  [对方已撤回]", saved];
            }
        }
    }
    return orig;
}

// 富文本渲染拦截（负责将界面渲染为带红字提示的效果）
- (NSAttributedString *)attrText {
    NSAttributedString *orig = %orig;
    id k = [(id)self valueForKey:@"msgKey"];
    if (k) {
        NSString *key = [NSString stringWithFormat:@"%@", k];
        // 正常消息
        if (orig && orig.string.length > 0 && ![orig.string containsString:@"撤回了一条消息"]) {
            [AntiRevokeManager saveText:orig.string forKey:key];
            return orig;
        }
        // 被撤回消息：还原原文并追加红色提示戳
        if (orig && [orig.string containsString:@"撤回了一条消息"]) {
            NSString *saved = [AntiRevokeManager getTextForKey:key];
            if (saved && saved.length > 0) {
                NSMutableAttributedString *mut = [[NSMutableAttributedString alloc] initWithString:saved];
                NSAttributedString *tag = [[NSAttributedString alloc] initWithString:@"  [对方已撤回]" 
                                                                          attributes:@{NSForegroundColorAttributeName: [UIColor systemRedColor]}];
                [mut appendAttributedString:tag];
                return mut;
            }
        }
    }
    return orig;
}

%end

// ==========================================
// 2. 界面控制层：静音弹窗警告
// ==========================================
%hook WWKConversationNewViewController

- (void)revokeMessageWithFirstAlert:(id)arg1 {}
- (void)managerRevokeMessage:(id)arg1 {}
- (void)revokeHistoryMessage:(id)arg1 {}
- (void)revokeMessage:(id)arg1 {}

%end

// ==========================================
// 3. 保护引用消息框不被破坏
// ==========================================
%hook WWKConversationQuoteBubbleView

- (BOOL)quotedRevoked {
    return NO;
}

%end
