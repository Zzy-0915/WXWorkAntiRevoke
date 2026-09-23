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
    
    // 加上 (id) 强转，解决“前向声明”编译报错
    if ([(id)self respondsToSelector:@selector(setIsUnknownMsg:)]) {
        [(id)self performSelector:@selector(setIsUnknownMsg:) withObject:@(YES)];
    }
    
    return self; 
}

%end

// 2. 强行屏蔽聊天视图控制器的撤回刷新逻辑
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
        // 替换成红色的安全提示语，防止高度为0导致闪退
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
