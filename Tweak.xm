#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// 声明一个内存地址用于动态绑定撤回标记
static const void *kIsAntiRevokedKey = &kIsAntiRevokedKey;

// ==========================================
// 1. 给消息体追加 [已撤回] 的红色提示尾巴
// ==========================================
%hook WWKMessage

// 拦截纯文本读取
- (NSString *)text {
    NSString *orig = %orig;
    NSNumber *isRevoked = objc_getAssociatedObject(self, kIsAntiRevokedKey);
    // 如果被打上了撤回标记，就在原文后面追加提示
    if (isRevoked && [isRevoked boolValue]) {
        if (orig && ![orig containsString:@"[已撤回]"]) {
            return [orig stringByAppendingString:@" [已撤回]"];
        }
    }
    return orig;
}

// 拦截富文本读取（带颜色和表情的文本）
- (NSAttributedString *)attrText {
    NSAttributedString *orig = %orig;
    NSNumber *isRevoked = objc_getAssociatedObject(self, kIsAntiRevokedKey);
    if (isRevoked && [isRevoked boolValue]) {
        if (orig && ![[orig string] containsString:@"[已撤回]"]) {
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
// 2. 拦截撤回动作，打上标记，并阻止 UI 删消息
// ==========================================
%hook WWKConversationNewViewController

- (void)revokeMessage:(id)msg {
    // 1. 抓到即将被撤回的消息，给它打上“已撤回”标记
    if ([msg isKindOfClass:%c(WWKMessage)]) {
        objc_setAssociatedObject(msg, kIsAntiRevokedKey, @(YES), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    
    // 2. 绝不能调用 %orig，防止系统把气泡从屏幕上删掉
    
    // 3. 强制刷新当前聊天列表，让追加的红色 [已撤回] 展现出来
    UITableView *tv = [self valueForKey:@"tableView"];
    if ([tv isKindOfClass:[UITableView class]]) {
        [tv reloadData];
    }
}

- (void)revokeHistoryMessage:(id)msg {
    if ([msg isKindOfClass:%c(WWKMessage)]) {
        objc_setAssociatedObject(msg, kIsAntiRevokedKey, @(YES), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    UITableView *tv = [self valueForKey:@"tableView"];
    if ([tv isKindOfClass:[UITableView class]]) [tv reloadData];
}

- (void)managerRevokeMessage:(id)msg {
    if ([msg isKindOfClass:%c(WWKMessage)]) {
        objc_setAssociatedObject(msg, kIsAntiRevokedKey, @(YES), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    UITableView *tv = [self valueForKey:@"tableView"];
    if ([tv isKindOfClass:[UITableView class]]) [tv reloadData];
}

// 拦截顶部的撤回弹窗警告（让它闭嘴）
- (void)revokeMessageWithFirstAlert:(id)arg1 {
    // 留空，不执行任何弹窗
}

%end
