#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// 声明一个内存地址用于动态绑定撤回标记
static const void *kIsAntiRevokedKey = &kIsAntiRevokedKey;

// ==========================================
// 1. 核心模型层：防清理 + 红色尾巴
// ==========================================
%hook WWKMessage

// 【极其关键：补回这句】强行骗过 UI，绝不让气泡变成“撤回了一条消息”的系统提示
- (BOOL)isRevoked {
    return NO;
}

// 拦截纯文本读取
- (NSString *)text {
    NSString *orig = %orig;
    NSNumber *isRevoked = objc_getAssociatedObject(self, kIsAntiRevokedKey);
    // 如果被打上了撤回标记，就在原文后面追加提示
    if (isRevoked && [isRevoked boolValue]) {
        if (orig && ![orig containsString:@"[对方已撤回]"]) {
            return [orig stringByAppendingString:@" [对方已撤回]"];
        }
    }
    return orig;
}

// 拦截富文本读取（带颜色和表情的文本）
- (NSAttributedString *)attrText {
    NSAttributedString *orig = %orig;
    NSNumber *isRevoked = objc_getAssociatedObject(self, kIsAntiRevokedKey);
    if (isRevoked && [isRevoked boolValue]) {
        if (orig && ![[orig string] containsString:@"[对方已撤回]"]) {
            NSMutableAttributedString *mut = [orig mutableCopy];
            NSAttributedString *tag = [[NSAttributedString alloc] initWithString:@" [对方已撤回]" 
                                                                      attributes:@{ NSForegroundColorAttributeName : [UIColor redColor] }];
            [mut appendAttributedString:tag];
            return mut;
        }
    }
    return orig;
}

%end

// ==========================================
// 2. 界面控制层：打标记 + 拦截系统删气泡
// ==========================================
%hook WWKConversationNewViewController

- (void)revokeMessage:(id)msg {
    // 打上标记
    if ([msg isKindOfClass:%c(WWKMessage)]) {
        objc_setAssociatedObject(msg, kIsAntiRevokedKey, @(YES), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    // 强制刷新，触发 attrText 更新红字
    UITableView *tv = [(id)self valueForKey:@"tableView"];
    if ([tv isKindOfClass:[UITableView class]]) {
        [tv reloadData];
    }
}

- (void)revokeHistoryMessage:(id)msg {
    if ([msg isKindOfClass:%c(WWKMessage)]) {
        objc_setAssociatedObject(msg, kIsAntiRevokedKey, @(YES), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    UITableView *tv = [(id)self valueForKey:@"tableView"];
    if ([tv isKindOfClass:[UITableView class]]) {
        [tv reloadData];
    }
}

- (void)managerRevokeMessage:(id)msg {
    if ([msg isKindOfClass:%c(WWKMessage)]) {
        objc_setAssociatedObject(msg, kIsAntiRevokedKey, @(YES), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    UITableView *tv = [(id)self valueForKey:@"tableView"];
    if ([tv isKindOfClass:[UITableView class]]) {
        [tv reloadData];
    }
}

// 拦截顶部的撤回弹窗警告（让它闭嘴）
- (void)revokeMessageWithFirstAlert:(id)arg1 {
    // 留空即可
}

%end

// ==========================================
// 3. 顺手保护引用消息
// ==========================================
%hook WWKConversationQuoteBubbleView

// 防止你引用的消息被别人撤回后显示异常
- (BOOL)quotedRevoked {
    return NO;
}

%end
