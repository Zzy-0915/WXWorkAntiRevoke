#import <UIKit/UIKit.h>

// ==========================================
// 企业微信 5.0.11 - 极致纯净防撤回 (零闪退版)
// ==========================================

%hook WWKMessage

// 核心命门：永远告诉系统“这条消息没有被撤回”
// 这行代码将保护原始消息气泡不被系统隐藏或删除。
- (BOOL)isRevoked {
    return NO;
}

// 注意：完全移除了 p_parseRevokeMessage 的拦截！
// 让系统顺畅无阻地去生成那条灰色的“撤回提示”消息。
// 这样不仅解决了数组插入 nil 导致的闪退，还能天然利用系统的灰条作为撤回标记！

%end

// 顺手保护引用消息（防止引用的内容被别人撤回后显示异常）
%hook WWKConversationQuoteBubbleView

- (BOOL)quotedRevoked {
    return NO;
}

%end
