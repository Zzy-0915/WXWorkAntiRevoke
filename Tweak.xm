#import <UIKit/UIKit.h>

// ==========================================
// 企业微信 5.0.11 - 双轨记忆防撤回 (完美防闪退版)
// ==========================================

// 建立两个全局保险箱，分别储存纯文本和带表情的富文本
static NSCache *g_textCache = nil;
static NSCache *g_attrTextCache = nil;

%ctor {
    g_textCache = [[NSCache alloc] init];
    g_textCache.countLimit = 5000; // 记忆最近 5000 条消息
    
    g_attrTextCache = [[NSCache alloc] init];
    g_attrTextCache.countLimit = 5000;
}

// 安全获取消息唯一 ID 的辅助函数
static NSString* safeKey(id msg) {
    if ([msg respondsToSelector:@selector(msgKey)]) {
        id key = [msg valueForKey:@"msgKey"];
        if (key) return [NSString stringWithFormat:@"%@", key];
    }
    return nil;
}

%hook WWKMessage

// 强行把气泡维持在正常形态，不让它变成灰色的系统提示框
- (BOOL)isRevoked {
    return NO; 
}

// 1. 拦截富文本渲染（带颜色的文字、表情等）
- (NSAttributedString *)attrText {
    NSAttributedString *orig = %orig;
    if (!orig) return orig;
    
    NSString *key = safeKey(self);
    if (!key) return orig;

    // 当底层数据库把内容改成了“撤回”提示时
    if ([orig.string containsString:@"撤回了一条消息"]) {
        // 从保险箱里捞出被删除前的原文！
        NSAttributedString *cached = [g_attrTextCache objectForKey:key];
        if (cached) {
            NSMutableAttributedString *mut = [cached mutableCopy];
            // 在原文屁股后面贴上红色标签
            NSAttributedString *tag = [[NSAttributedString alloc] initWithString:@" [已拦截对方撤回]" 
                                                                      attributes:@{NSForegroundColorAttributeName: [UIColor redColor]}];
            [mut appendAttributedString:tag];
            return mut; // 偷天换日，完美恢复！
        }
        // 如果 App 重启过，保险箱清空了，就给个保底提示
        return [[NSAttributedString alloc] initWithString:@"[已拦截对方撤回消息]" 
                                               attributes:@{NSForegroundColorAttributeName: [UIColor redColor]}];
    } else {
        // 正常消息一出现，立刻存进保险箱备用
        [g_attrTextCache setObject:orig forKey:key];
        return orig;
    }
}

// 2. 拦截纯文本渲染（逻辑同上）
- (NSString *)text {
    NSString *orig = %orig;
    if (!orig) return orig;
    
    NSString *key = safeKey(self);
    if (!key) return orig;

    if ([orig containsString:@"撤回了一条消息"]) {
        NSString *cached = [g_textCache objectForKey:key];
        if (cached) {
            return [cached stringByAppendingString:@" [已拦截对方撤回]"];
        }
        return @"[已拦截对方撤回消息]";
    } else {
        [g_textCache setObject:orig forKey:key];
        return orig;
    }
}

%end

// ==========================================
// 拦截 UI 刷新逻辑，强行触发替换
// ==========================================
%hook WWKConversationNewViewController

- (void)revokeMessage:(id)arg1 {
    UITableView *tv = [(id)self valueForKey:@"tableView"];
    if ([tv isKindOfClass:[UITableView class]]) [tv reloadData];
}
- (void)revokeHistoryMessage:(id)arg1 {
    UITableView *tv = [(id)self valueForKey:@"tableView"];
    if ([tv isKindOfClass:[UITableView class]]) [tv reloadData];
}
- (void)managerRevokeMessage:(id)arg1 {
    UITableView *tv = [(id)self valueForKey:@"tableView"];
    if ([tv isKindOfClass:[UITableView class]]) [tv reloadData];
}

// 让顶部的恶心弹窗闭嘴
- (void)revokeMessageWithFirstAlert:(id)arg1 {}

%end

// 顺手保护一下被引用的消息
%hook WWKConversationQuoteBubbleView
- (BOOL)quotedRevoked { return NO; }
%end
