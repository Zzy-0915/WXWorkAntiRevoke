#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// ==========================================
// 企业微信防撤回 - 底层诊断与调用栈监控仪
// ==========================================

%hook WWKMessage

// 1. 监控消息创建：看看消息刚诞生时，文本长什么样
- (id)initWithMessage:(id)arg1 {
    id res = %orig;
    @try {
        if (res && [(id)res respondsToSelector:@selector(text)]) {
            NSString *t = [(id)res text];
            if (t.length > 0) {
                NSLog(@"[AntiRevoke-Diag] 🟢 消息创建: %@", t);
            }
        }
    } @catch (NSException *e) {
        NSLog(@"[AntiRevoke-Diag] 消息创建监控异常: %@", e);
    }
    return res;
}

// 2. 核心监控：拦截撤回解析包，倾印所有参数和调用栈
- (id)p_parseRevokeMessage:(id)arg1 {
    NSLog(@"========== [AntiRevoke-Diag] 🔴 收到撤回数据包 ==========");
    
    // 打印当前线程，判断是后台网络同步还是前台 UI 刷新
    NSLog(@"[AntiRevoke-Diag] 当前线程: %@", [NSThread currentThread]);
    
    // 打印撤回指令的原始参数
    NSLog(@"[AntiRevoke-Diag] 撤回参数 (arg1) 类型: %@", [arg1 class]);
    NSLog(@"[AntiRevoke-Diag] 撤回参数 (arg1) 内容: %@", arg1);
    
    // 打印被撤回前，当前消息对象到底长什么样
    @try {
        if ([(id)self respondsToSelector:@selector(text)]) {
            NSLog(@"[AntiRevoke-Diag] 解析前 text: %@", [(id)self text]);
        }
        if ([(id)self respondsToSelector:@selector(msgKey)]) {
            NSLog(@"[AntiRevoke-Diag] 解析前 msgKey: %@", [(id)self valueForKey:@"msgKey"]);
        }
        // 尝试探索隐藏属性，看看有没有可能原始消息被移到了其他字段
        if ([(id)self respondsToSelector:@selector(summary)]) {
            NSLog(@"[AntiRevoke-Diag] 解析前 summary: %@", [(id)self valueForKey:@"summary"]);
        }
    } @catch (NSException *e) {
        NSLog(@"[AntiRevoke-Diag] 属性读取异常: %@", e);
    }

    // 打印当前的函数调用栈（最关键！能看清是哪个底层 C++ 函数触发了撤回）
    NSLog(@"[AntiRevoke-Diag] 函数调用栈 (Call Stack):\n%@", [NSThread callStackSymbols]);

    // 放行原逻辑，观察解析后的变化
    id res = %orig;

    @try {
        if ([(id)self respondsToSelector:@selector(text)]) {
            NSLog(@"[AntiRevoke-Diag] 解析后 text 变成了: %@", [(id)self text]);
        }
    } @catch (NSException *e) {}

    NSLog(@"========== [AntiRevoke-Diag] 撤回流程记录完毕 ==========");
    return res;
}

// 3. 监控 UI 渲染：看看界面去拿文本时，拿到了什么
- (NSString *)text {
    NSString *res = %orig;
    if ([res containsString:@"撤回"]) {
        NSLog(@"[AntiRevoke-Diag] 🟡 UI正在请求撤回文本，当前返回: %@", res);
    }
    return res;
}

%end

// 4. 监控控制器层面的撤回动作
%hook WWKConversationNewViewController
- (void)revokeMessage:(id)arg1 {
    NSLog(@"[AntiRevoke-Diag] 🟣 UI控制器触发 revokeMessage, 参数: %@", arg1);
    %orig;
}
- (void)managerRevokeMessage:(id)arg1 {
    NSLog(@"[AntiRevoke-Diag] 🟣 UI控制器触发 managerRevokeMessage");
    %orig;
}
%end
