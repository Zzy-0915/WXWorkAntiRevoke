#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// 给被我们强行转化的撤回指令打个标记
static const void *kInterceptedRevokeTag = &kInterceptedRevokeTag;

// ==========================================
// 企业微信 5.0.11 - 移花接木防撤回终极版
// ==========================================

%hook WWKMessage

// 1. 核心：移花接木！把撤回数据包当成“未知消息”去解析
- (id)p_parseRevokeMessage:(id)arg1 {
    id msg = nil;
    
    // 借用底层自带的“未知消息解析器”
    // 这样既能生成合法的消息对象（防止进聊天室闪退）
    // 又能让它失去“撤回指令”的威力（保住原始气泡不被隐藏）
    if ([(id)self respondsToSelector:@selector(p_parseUnknownMessage:)]) {
        msg = [(id)self performSelector:@selector(p_parseUnknownMessage:) withObject:arg1];
    } else {
        msg = %orig; // 兜底安全策略
    }
    
    // 给这条被转化后的消息打上“防撤回”的专属烙印
    if (msg) {
        objc_setAssociatedObject(msg, kInterceptedRevokeTag, @(YES), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    
    NSLog(@"[AntiRevoke] 成功拦截撤回数据包，并已转化为安全通知！");
    return msg;
}

// 2. 偷天换日：把这条伪装消息的文本替换成我们的红色提示
- (NSString *)text {
    NSNumber *isIntercepted = objc_getAssociatedObject(self, kInterceptedRevokeTag);
    if (isIntercepted && [isIntercepted boolValue]) {
        return @"🚫 [已拦截对方的撤回操作]";
    }
    return %orig;
}

// 拦截富文本读取（带颜色的文本）
- (NSAttributedString *)attrText {
    NSNumber *isIntercepted = objc_getAssociatedObject(self, kInterceptedRevokeTag);
    if (isIntercepted && [isIntercepted boolValue]) {
        return [[NSAttributedString alloc] initWithString:@"🚫 [已拦截对方的撤回操作]" 
                                               attributes:@{NSForegroundColorAttributeName: [UIColor systemRedColor]}];
    }
    return %orig;
}

// 3. 保底防御：永远告诉系统“这条消息没有被撤回”
- (BOOL)isRevoked {
    return NO;
}

%end

// 4. 保护引用消息（防止引用的内容被别人撤回后显示异常）
%hook WWKConversationQuoteBubbleView

- (BOOL)quotedRevoked {
    return NO;
}

%end
