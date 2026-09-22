#import <UIKit/UIKit.h>

// ==========================================
// 企业微信 5.0.11 防闪退·纯净防撤回
// ==========================================

%hook WWKMessage

// 1. 核心逻辑：系统无论怎么查，我们都告诉它“这条消息没有被撤回”
- (BOOL)isRevoked {
    return NO;
}

// 2. 修复闪退：让系统正常解析撤回数据包，绝对不能返回 nil！
// 这样进入聊天界面时，系统数组就不会因为拿到空对象而崩溃闪退。
- (id)p_parseRevokeMessage:(id)arg1 {
    id msg = %orig; // 让系统自己处理，保证数据链条完整
    NSLog(@"[AntiRevoke] 收到撤回包，已安全放行解析，通过 isRevoked 欺骗界面");
    return msg;
}

%end

// 3. 顺手保护一下“引用消息”
// 如果别人撤回了被你引用的消息，保证你这里的引用框依然正常显示
%hook WWKConversationQuoteBubbleView

- (BOOL)quotedRevoked {
    return NO;
}

%end
