#import <UIKit/UIKit.h>

// ==========================================
// 企业微信 5.0.11 (Rootless) 专版防撤回 - 完美防闪退版
// ==========================================

// 1. 强行干涉底层消息体的解析与呈现状态
%hook WWKMessage

// 只要底层来问“这条消息是不是被撤回了”，直接回答 NO（保住原消息气泡）
- (BOOL)isRevoked {
    return NO;
}

// 【核心修复一：防进聊天室闪退】
- (id)p_parseRevokeMessage:(id)arg1 {
    NSLog(@"[AntiRevoke] 拦截到底层撤回解析包");
    
    // 绝对不能 return nil！否则进群拉取消息时，数组插入 nil 会瞬间闪退。
    // 我们不调用 %orig，从而成功阻断撤回指令写入数据库。
    // 直接返回 self（它是一个刚创建好的合法空消息对象），骗过系统数组！
    
    // 保险起见，将其伪装成一条“未知/普通”消息
    if ([self respondsToSelector:@selector(setIsUnknownMsg:)]) {
        [self performSelector:@selector(setIsUnknownMsg:) withObject:@(YES)];
    }
    
    return self; 
}

%end

// 2. 强行屏蔽聊天视图控制器的撤回刷新逻辑（保持你的原样）
%hook WWKConversationNewViewController

- (void)managerRevokeMessage:(id)arg1 {}
- (void)revokeHistoryMessage:(id)arg1 {}
- (void)revokeMessage:(id)arg1 {}
- (void)revokeMessageWithFirstAlert:(id)arg1 {}

%end

// 3. 【核心修复二：防 UI 布局闪退 & 增加撤回提示】
%hook UILabel

- (void)setAttributedText:(NSAttributedString *)text {
    if (text && [text.string containsString:@"撤回了一条消息"]) {
        // 不能直接 return 丢弃！UILabel 必须有内容支撑高度，否则计算为0会引发约束冲突闪退。
        // 我们把它替换成红色的安全提示语，这样你就能知道对方撤回了什么！
        NSAttributedString *safeText = [[NSAttributedString alloc] initWithString:@" [已拦截对方撤回]" 
                                                                       attributes:@{NSForegroundColorAttributeName: [UIColor redColor]}];
        %orig(safeText);
        return;
    }
    %orig(text);
}

- (void)setText:(NSString *)text {
    if (text && [text containsString:@"撤回了一条消息"]) {
        %orig(@" [已拦截对方撤回]");
        return;
    }
    %orig(text);
}

%end
