#import <UIKit/UIKit.h>

// ==========================================
// 企业微信 5.0.11 (Rootless) 专版防撤回
// ==========================================

// 1. 强行干涉底层消息体的解析与呈现状态
%hook WWKMessage

// 只要底层来问“这条消息是不是被撤回了”，直接回答 NO
- (BOOL)isRevoked {
    return NO;
}

// 拦截撤回消息的协议解析，遇到撤回包直接丢弃
- (id)p_parseRevokeMessage:(id)arg1 {
    NSLog(@"[AntiRevoke] 拦截到底层撤回解析包，已丢弃");
    return nil;
}

%end

// 2. 强行屏蔽聊天视图控制器的撤回刷新逻辑
%hook WWKConversationNewViewController

// 拦截管理员撤回
- (void)managerRevokeMessage:(id)arg1 {
    NSLog(@"[AntiRevoke] 拦截到管理员撤回指令");
}

// 拦截单条历史撤回
- (void)revokeHistoryMessage:(id)arg1 {
    NSLog(@"[AntiRevoke] 拦截到历史消息撤回指令");
}

// 拦截普通消息撤回
- (void)revokeMessage:(id)arg1 {
    NSLog(@"[AntiRevoke] 拦截到实时消息撤回指令");
}

// 拦截撤回弹窗警告
- (void)revokeMessageWithFirstAlert:(id)arg1 {
    NSLog(@"[AntiRevoke] 拦截到撤回弹窗警告");
}

%end

// 3. 强行拦截并隐藏由于其他原因强行渲染出来的红字撤回提示标签
%hook UILabel

- (void)setAttributedText:(NSAttributedString *)text {
    if (text && [text.string containsString:@"撤回了一条消息"]) {
        NSLog(@"[AntiRevoke] 拦截到 UI 上即将显示撤回红字，已强制消隐");
        return; // 直接丢弃这个富文本，不让它显示出来
    }
    %orig;
}

- (void)setText:(NSString *)text {
    if (text && [text containsString:@"撤回了一条消息"]) {
        NSLog(@"[AntiRevoke] 拦截到 UI 上即将显示撤回文字，已强制消隐");
        return; // 直接丢弃文字
    }
    %orig;
}

%end
