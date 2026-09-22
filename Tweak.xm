#import <UIKit/UIKit.h>

// ==========================================
// 强化版防撤回逻辑 (尝试覆盖更多可能的类名)
// ==========================================

// 1. 尝试 Hook 经典的 CMessageMgr
%hook CMessageMgr
- (void)onRevokeMsg:(id)msgWrap {
    // 拦截撤回指令，不调用 %orig
    NSLog(@"[AntiRevoke] 拦截到 CMessageMgr 撤回指令: %@", msgWrap);
}
- (void)DelMsg:(id)arg1 MsgList:(id)arg2 DelAll:(BOOL)arg3 {
    // 拦截批量删除（可能是撤回引起的清理）
    NSLog(@"[AntiRevoke] 拦截到 CMessageMgr 删除指令");
    // 注释掉 %orig 阻止删除，但这可能影响正常的删除功能，作为测试先保留观察
    // %orig; 
}
%end

// 2. 尝试 Hook 可能的企业微信特有类 (WWKMessageService / WWKMessageMgr 等)
%hook WWKMessageService
- (void)onRevokeMessage:(id)message {
    NSLog(@"[AntiRevoke] 拦截到 WWKMessageService 撤回指令");
    // 不调用 %orig 拦截撤回
}
%end

%hook WWKConversationMessageMgr
- (void)onRevokeMessage:(id)message {
    NSLog(@"[AntiRevoke] 拦截到 WWKConversationMessageMgr 撤回指令");
}
%end

// 3. 拦截向聊天界面插入“撤回了一条消息”的系统提示消息
// 企业微信通常会调用某个 insertSystemMessage 类似的方法
%hook WWKMessageListController
- (void)addMessageNode:(id)node {
    // 简单粗暴：如果节点包含“撤回了”，就不添加到 UI 上
    NSString *nodeDesc = [NSString stringWithFormat:@"%@", node];
    if ([nodeDesc containsString:@"撤回了"]) {
        NSLog(@"[AntiRevoke] 拦截到 UI 撤回提示插入");
        return; 
    }
    %orig;
}
%end

%ctor {
    NSLog(@"[AntiRevoke] 插件已成功加载到企业微信进程！");
}
