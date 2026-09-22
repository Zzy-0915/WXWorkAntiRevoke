#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// ==========================================
// 全局记忆保险箱：用于抢救被底层删掉的原始消息
// ==========================================
static NSCache *g_originalContentCache = nil;
static NSMutableSet *g_revokedKeys = nil;

%ctor {
    g_originalContentCache = [[NSCache alloc] init];
    g_originalContentCache.countLimit = 2000; // 最多记忆当前 2000 条消息
    g_revokedKeys = [[NSMutableSet alloc] init];
}

// ==========================================
// 1. 拦截撤回动作：记录谁被撤回了，并阻止 UI 删除
// ==========================================
%hook WWKConversationNewViewController

- (void)revokeMessage:(id)msg {
    if ([msg isKindOfClass:%c(WWKMessage)]) {
        id key = [msg valueForKey:@"msgKey"];
        if (key) [g_revokedKeys addObject:key];
    }
    // 强制刷新界面，触发文本替换，决不执行 %orig 导致气泡消失
    UITableView *tv = [(id)self valueForKey:@"tableView"];
    if ([tv isKindOfClass:[UITableView class]]) [tv reloadData];
}

- (void)revokeHistoryMessage:(id)msg {
    if ([msg isKindOfClass:%c(WWKMessage)]) {
        id key = [msg valueForKey:@"msgKey"];
        if (key) [g_revokedKeys addObject:key];
    }
    UITableView *tv = [(id)self valueForKey:@"tableView"];
    if ([tv isKindOfClass:[UITableView class]]) [tv reloadData];
}

- (void)managerRevokeMessage:(id)msg {
    if ([msg isKindOfClass:%c(WWKMessage)]) {
        id key = [msg valueForKey:@"msgKey"];
        if (key) [g_revokedKeys addObject:key];
    }
    UITableView *tv = [(id)self valueForKey:@"tableView"];
    if ([tv isKindOfClass:[UITableView class]]) [tv reloadData];
}

// 屏蔽顶部的撤回弹窗警告
- (void)revokeMessageWithFirstAlert:(id)arg1 {}

%end

// ==========================================
// 2. 文本渲染层：偷天换日，从保险箱恢复数据
// ==========================================
%hook WWKMessage

- (NSAttributedString *)attrText {
    NSAttributedString *orig = %orig;
    id key = [self valueForKey:@"msgKey"];
    if (!key) return orig;

    // 核心判定：这条消息是否收到了撤回指令，或者底层文本已经被改成了撤回提示？
    BOOL isRevoked = [g_revokedKeys containsObject:key] || [[orig string] containsString:@"撤回了一条消息"];

    if (isRevoked) {
        // 从我们的全局保险箱里捞出原文！
        NSAttributedString *cachedOrig = [g_originalContentCache objectForKey:key];
        if (cachedOrig) {
            NSMutableAttributedString *mut = [cachedOrig mutableCopy];
            // 在原文尾部强行挂上红色提示
            NSAttributedString *tag = [[NSAttributedString alloc] initWithString:@" [对方已撤回]" 
                                                                      attributes:@{ NSForegroundColorAttributeName : [UIColor redColor] }];
            [mut appendAttributedString:tag];
            return mut; // 完美替换底层丢失的数据！
        }
    } else if (orig.length > 0) {
        // 如果是正常消息，趁底层还没删，赶紧存进保险箱
        [g_originalContentCache setObject:orig forKey:key];
    }

    return orig;
}

- (NSString *)text {
    NSString *orig = %orig;
    id key = [self valueForKey:@"msgKey"];
    if (!key) return orig;

    BOOL isRevoked = [g_revokedKeys containsObject:key] || [orig containsString:@"撤回了一条消息"];

    if (isRevoked) {
        NSAttributedString *cachedAttr = [g_originalContentCache objectForKey:key];
        if (cachedAttr) {
            return [[cachedAttr string] stringByAppendingString:@" [对方已撤回]"];
        }
    }
    return orig;
}

%end
