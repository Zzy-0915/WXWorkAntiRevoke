#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static const void *kBoundRevokeTextKey = &kBoundRevokeTextKey;
static NSMutableArray<NSString *> *s_messageHistory = nil;

// ==========================================
// 1. 全局消息流水账中心（线程安全）
// ==========================================
static void recordMessage(NSString *str) {
    if (!str || str.length == 0) return;
    // 过滤掉各类系统提示与自身标记，防止污染缓存池
    if ([str containsString:@"撤回了一条消息"]) return;
    if ([str containsString:@"[对方已撤回]"]) return;
    if ([str containsString:@"[已拦截"]) return;

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        s_messageHistory = [[NSMutableArray alloc] initWithCapacity:100];
    });

    @synchronized(s_messageHistory) {
        // 去重：避免相同内容连续重复入库
        if (s_messageHistory.count > 0 && [s_messageHistory.lastObject isEqualToString:str]) {
            return;
        }
        [s_messageHistory addObject:[str copy]];
        // 限制常驻容量为最近 100 条
        if (s_messageHistory.count > 100) {
            [s_messageHistory removeObjectAtIndex:0];
        }
    }
}

static NSString *popLatestMessageFromHistory(void) {
    if (!s_messageHistory) return nil;
    @synchronized(s_messageHistory) {
        if (s_messageHistory.count > 0) {
            NSString *last = s_messageHistory.lastObject;
            [s_messageHistory removeLastObject];
            return last;
        }
    }
    return nil;
}

// ==========================================
// 2. 核心模型层：前置网络捕获 + 渲染层偷天换日
// ==========================================
%hook WWKMessage

// 【前置捕获一】：消息模型初始化瞬间（无论是否在聊天界面均必定触发）
- (id)initWithMessage:(id)arg1 {
    id res = %orig;
    if (res) {
        NSString *t = [(id)res text];
        recordMessage(t);
    }
    return res;
}

- (id)initWithMessage:(id)arg1 scene:(id)arg2 {
    id res = %orig;
    if (res) {
        NSString *t = [(id)res text];
        recordMessage(t);
    }
    return res;
}

// 【前置捕获二】：文本消息底层解析入口，确保文字在网络包拆解期即被锁定
- (id)p_createTextMessage:(id)arg1 andModelMsg:(id)arg2 mediaRange:(id)arg3 trimHeadNewLine:(BOOL)arg4 trimTailNewLine:(BOOL)arg5 {
    if ([arg1 isKindOfClass:[NSString class]]) {
        recordMessage((NSString *)arg1);
    }
    return %orig;
}

// 【渲染还原一】：纯文本输出拦截
- (NSString *)text {
    NSString *orig = %orig;
    if (!orig || orig.length == 0) return orig;

    // 正常消息：顺手补充记录
    if (![orig containsString:@"撤回了一条消息"] && ![orig containsString:@"[对方已撤回]"]) {
        recordMessage(orig);
        return orig;
    }

    // 撤回系统消息：提取原文并绑定还魂
    if ([orig containsString:@"撤回了一条消息"]) {
        NSString *bound = objc_getAssociatedObject(self, kBoundRevokeTextKey);
        if (!bound) {
            bound = popLatestMessageFromHistory();
            if (bound) {
                objc_setAssociatedObject(self, kBoundRevokeTextKey, bound, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            }
        }
        if (bound && bound.length > 0) {
            return [NSString stringWithFormat:@"%@  [对方已撤回]", bound];
        }
    }
    return orig;
}

// 【渲染还原二】：富文本输出拦截（气泡实际渲染通道）
- (NSAttributedString *)attrText {
    NSAttributedString *orig = %orig;
    if (!orig || orig.length == 0) return orig;

    // 正常富文本
    if (![orig.string containsString:@"撤回了一条消息"] && ![orig.string containsString:@"[对方已撤回]"]) {
        recordMessage(orig.string);
        return orig;
    }

    // 撤回富文本：将原文与灰色系统标签合并重绘
    if ([orig.string containsString:@"撤回了一条消息"]) {
        NSString *bound = objc_getAssociatedObject(self, kBoundRevokeTextKey);
        if (!bound) {
            bound = popLatestMessageFromHistory();
            if (bound) {
                objc_setAssociatedObject(self, kBoundRevokeTextKey, bound, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            }
        }
        if (bound && bound.length > 0) {
            NSMutableAttributedString *mut = [[NSMutableAttributedString alloc] initWithString:bound];
            // 采用自然、不突兀的系统灰色标签
            NSAttributedString *tag = [[NSAttributedString alloc] initWithString:@"  [对方已撤回]" 
                                                                      attributes:@{
                                                                          NSForegroundColorAttributeName: [UIColor systemGrayColor],
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
// 3. 辅助防护：弹窗静音与引用保护
// ==========================================
%hook WWKConversationNewViewController
- (void)revokeMessageWithFirstAlert:(id)arg1 {}
%end

%hook WWKConversationQuoteBubbleView
- (BOOL)quotedRevoked {
    return NO;
}
%end
