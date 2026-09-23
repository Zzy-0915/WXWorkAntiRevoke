#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// ==========================================
// 全局会话回溯中心：按会话记录最近消息文本
// ==========================================
@interface WWKRevokeMemoryCenter : NSObject
+ (void)recordMessage:(NSString *)text inConv:(NSString *)convKey;
+ (NSString *)popLatestMessageInConv:(NSString *)convKey;
@end

@implementation WWKRevokeMemoryCenter

static NSMutableDictionary<NSString *, NSMutableArray<NSString *> *> *s_convStacks = nil;

+ (void)initialize {
    if (self == [WWKRevokeMemoryCenter class]) {
        s_convStacks = [[NSMutableDictionary alloc] init];
    }
}

+ (void)recordMessage:(NSString *)text inConv:(NSString *)convKey {
    if (!text || text.length == 0 || !convKey) return;
    if ([text containsString:@"撤回了一条消息"]) return;

    @synchronized (s_convStacks) {
        NSMutableArray *list = s_convStacks[convKey];
        if (!list) {
            list = [NSMutableArray array];
            s_convStacks[convKey] = list;
        }
        // 记录最新消息，最多保留最近 20 条，防止内存膨胀
        [list addObject:text];
        if (list.count > 20) {
            [list removeObjectAtIndex:0];
        }
    }
}

+ (NSString *)popLatestMessageInConv:(NSString *)convKey {
    if (!convKey) return nil;
    @synchronized (s_convStacks) {
        NSMutableArray *list = s_convStacks[convKey];
        if (list && list.count > 0) {
            NSString *last = [list lastObject];
            // 取出后不立即删除，保留作为历史备查
            return last;
        }
    }
    return nil;
}

@end

// ==========================================
// 1. 核心模型层：拦截解析、阻止作废、还原内容
// ==========================================
%hook WWKMessage

// 阻止底层将消息标记为“作废/不可见”
- (BOOL)wwkfs_isInvalidateMessage {
    return NO;
}

// 拦截撤回数据包解析：保证调用 %orig 彻底杜绝崩溃，同时抓取撤回前的数据
- (id)p_parseRevokeMessage:(id)arg1 {
    NSString *beforeText = nil;
    if ([(id)self respondsToSelector:@selector(text)]) {
        beforeText = [(id)self text];
    }
    
    // 正常放行解析，维持底层数组结构的绝对完整
    id res = %orig(arg1);
    
    if (beforeText && beforeText.length > 0 && ![beforeText containsString:@"撤回了一条消息"]) {
        objc_setAssociatedObject(self, "kPreRevokeContent", [beforeText copy], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return res;
}

// 拦截纯文本读取
- (NSString *)text {
    NSString *orig = %orig;
    id convId = [(id)self cleanItemConversationKey];
    NSString *convKey = convId ? [NSString stringWithFormat:@"%@", convId] : @"default";

    // 正常消息：自动归档到该会话的流水账中
    if (orig && orig.length > 0 && ![orig containsString:@"撤回了一条消息"]) {
        [WWKRevokeMemoryCenter recordMessage:orig inConv:convKey];
        return orig;
    }

    // 遇到已被撤回的消息：提取原文还原
    if (orig && [orig containsString:@"撤回了一条消息"]) {
        // 1. 优先尝试提取解析前绑定的内容
        NSString *saved = objc_getAssociatedObject(self, "kPreRevokeContent");
        // 2. 否则从该会话的最近消息回溯栈提取
        if (!saved || saved.length == 0) {
            saved = [WWKRevokeMemoryCenter popLatestMessageInConv:convKey];
        }
        
        if (saved && saved.length > 0) {
            return [NSString stringWithFormat:@"%@  [对方已撤回]", saved];
        }
    }
    return orig;
}

// 拦截富文本读取（UI 渲染气泡核心）
- (NSAttributedString *)attrText {
    NSAttributedString *orig = %orig;
    if (!orig || orig.length == 0) return orig;

    id convId = [(id)self cleanItemConversationKey];
    NSString *convKey = convId ? [NSString stringWithFormat:@"%@", convId] : @"default";

    // 正常富文本消息入库
    if (![orig.string containsString:@"撤回了一条消息"]) {
        [WWKRevokeMemoryCenter recordMessage:orig.string inConv:convKey];
        return orig;
    }

    // 还原被撤回的富文本展示
    if ([orig.string containsString:@"撤回了一条消息"]) {
        NSString *saved = objc_getAssociatedObject(self, "kPreRevokeContent");
        if (!saved || saved.length == 0) {
            saved = [WWKRevokeMemoryCenter popLatestMessageInConv:convKey];
        }

        if (saved && saved.length > 0) {
            NSMutableAttributedString *mut = [[NSMutableAttributedString alloc] initWithString:saved];
            // 采用克制、自然的灰色系统样式提示
            NSAttributedString *tag = [[NSAttributedString alloc] initWithString:@"  [对方已撤回]" 
                                                                      attributes:@{
                                                                          NSForegroundColorAttributeName: [UIColor lightGrayColor],
                                                                          NSFontAttributeName: [UIFont systemFontOfSize:12]
                                                                      }];
            [mut appendAttributedString:tag];
            return mut;
        }
    }
    return orig;
}

%end

// ==========================================
// 2. 界面控制与引用保护
// ==========================================
%hook WWKConversationNewViewController
// 屏蔽顶部的撤回弹窗警告
- (void)revokeMessageWithFirstAlert:(id)arg1 {}
%end

%hook WWKConversationQuoteBubbleView
// 保护引用框不随撤回而破碎
- (BOOL)quotedRevoked {
    return NO;
}
%end
