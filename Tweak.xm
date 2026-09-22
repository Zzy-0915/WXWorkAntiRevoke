#import <UIKit/UIKit.h>

// 1. 拦截企业微信消息同步与撤回服务
%hook WWKMessageService
- (void)onRevokeMessage:(id)arg1 {
    NSLog(@"[AntiRevoke] 已拦截单条消息撤回: %@", arg1);
}
- (void)onRevokeMessages:(id)arg1 {
    NSLog(@"[AntiRevoke] 已拦截多条消息撤回: %@", arg1);
}
%end

// 2. 拦截会话管理器中的撤回动作
%hook WWKConversationMessageMgr
- (void)onRevokeMessage:(id)arg1 {
    NSLog(@"[AntiRevoke] 已拦截会话管理器撤回: %@", arg1);
}
- (void)onRevokeMessages:(id)arg1 {
    NSLog(@"[AntiRevoke] 已拦截会话管理器批量撤回: %@", arg1);
}
%end

// 3. 强行篡改核心消息的“撤回状态”属性，让 UI 界面继续强行显示原消息
%hook WWKMessage
- (BOOL)isRevoked {
    // 强制告诉界面：这条消息没有被撤回
    return NO;
}
- (void)setRevoked:(BOOL)arg1 {
    NSLog(@"[AntiRevoke] 拦截到尝试修改撤回状态，已阻止！");
}
%end

// 4. 插件加载完成时的检测探针
%ctor {
    NSLog(@"[AntiRevoke] 🚀 企业微信 WWK 专版防撤回插件已成功加载！");
}
