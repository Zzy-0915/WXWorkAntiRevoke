#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// 给我们拦截下来的撤回包打个隐藏标签
static const void *kFakeRevokeTag = &kFakeRevokeTag;

// ==========================================
// 企业微信 5.0.11 - 狸猫换太子 (防闪退 + 保原文)
// ==========================================

%hook WWKMessage

// 1. 拦截解析过程：正常解析防闪退，打上标签备用
- (id)p_parseRevokeMessage:(id)arg1 {
    id msg = %orig; // 必须调用原方法，生成合法的对象，100% 杜绝进群闪退
    if (msg) {
        // 给它盖个戳，证明它是被我们“截获的间谍”
        objc_setAssociatedObject(msg, kFakeRevokeTag, @(YES), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    NSLog(@"[AntiRevoke] 成功拦截撤回数据包！");
    return msg;
}

// 2. 核心欺骗：篡改消息类型！
// 当业务层来问“你是什么消息”时，如果它是间谍，我们强行回答“我是普通文本”！
// 这样业务层就不会去执行“抹除原消息”的数据库动作了，原话就被永久保住了！
- (int)type {
    NSNumber *isFake = objc_getAssociatedObject(self, kFakeRevokeTag);
    if (isFake && [isFake boolValue]) {
        return 1; // 1 通常代表普通的 Text 文本消息
    }
    return %orig;
}

- (long long)messageType {
    NSNumber *isFake = objc_getAssociatedObject(self, kFakeRevokeTag);
    if (isFake && [isFake boolValue]) {
        return 1;
    }
    return %orig;
}

// 3. 完美展现：把这个撤回指令，变成屏幕上的红色警告气泡！
- (NSString *)text {
    NSNumber *isFake = objc_getAssociatedObject(self, kFakeRevokeTag);
    if (isFake && [isFake boolValue]) {
        return @"[已拦截对方撤回]"; // 让撤回指令直接现原形
    }
    return %orig;
}

- (NSAttributedString *)attrText {
    NSNumber *isFake = objc_getAssociatedObject(self, kFakeRevokeTag);
    if (isFake && [isFake boolValue]) {
        return [[NSAttributedString alloc] initWithString:@"🚫 [已拦截对方撤回操作]" 
                                               attributes:@{NSForegroundColorAttributeName: [UIColor redColor]}];
    }
    return %orig;
}

// 4. 全局保底：所有消息均报告未撤回
- (BOOL)isRevoked {
    return NO;
}

- (BOOL)wwkfs_isInvalidateMessage {
    NSNumber *isFake = objc_getAssociatedObject(self, kFakeRevokeTag);
    if (isFake && [isFake boolValue]) {
        return NO;
    }
    return %orig;
}

%end

// ==========================================
// 保护引用消息框不崩溃
// ==========================================
%hook WWKConversationQuoteBubbleView
- (BOOL)quotedRevoked { 
    return NO; 
}
%end
