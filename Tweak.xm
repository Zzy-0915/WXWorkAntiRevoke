#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static const void *kHistoricalRevokeTag = &kHistoricalRevokeTag;

// ==========================================
// 企业微信 5.0.11 - 线程截杀防撤回 (保原文+防闪退终极版)
// ==========================================

%hook WWKMessage

// 1. 核心黑科技：智能线程截杀
- (id)p_parseRevokeMessage:(id)arg1 {
    // 判断当前是在哪个线程运行
    if ([NSThread isMainThread]) {
        // 【前台 UI 渲染】
        // 说明这是以前的历史撤回记录，绝对不能返回 nil，否则一进聊天室必闪退！
        id msg = %orig;
        if (msg) {
            // 打个标签，等会儿把它染成红色
            objc_setAssociatedObject(msg, kHistoricalRevokeTag, @(YES), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        return msg;
    } else {
        // 【后台网络同步】
        // 真正的杀招！对方刚刚按下了撤回，网络在后台收到了指令
        // 我们直接返回 nil，把指令丢进黑洞！
        // 这样底层的 C++ 数据库根本收不到撤回命令，你手机里的原消息会被永久保留，一字不差！
        NSLog(@"[AntiRevoke] 成功在后台截杀撤回指令，原消息已永久保留！");
        return nil;
    }
}

// 2. 界面处理：把历史遗留的撤回提示标红
- (NSString *)text {
    NSNumber *isHistorical = objc_getAssociatedObject(self, kHistoricalRevokeTag);
    if (isHistorical && [isHistorical boolValue]) {
        return @"🚫 [历史撤回已拦截]";
    }
    return %orig;
}

- (NSAttributedString *)attrText {
    NSNumber *isHistorical = objc_getAssociatedObject(self, kHistoricalRevokeTag);
    if (isHistorical && [isHistorical boolValue]) {
        return [[NSAttributedString alloc] initWithString:@"🚫 [历史撤回已拦截]" 
                                               attributes:@{NSForegroundColorAttributeName: [UIColor systemRedColor]}];
    }
    return %orig;
}

// 3. 保底防御
- (BOOL)isRevoked {
    return NO;
}

%end

// 4. 保护引用消息框不崩溃
%hook WWKConversationQuoteBubbleView
- (BOOL)quotedRevoked { 
    return NO; 
}
%end
