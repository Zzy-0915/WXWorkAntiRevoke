#import <UIKit/UIKit.h>

// ==========================================
// 企业微信防撤回 - 剪贴板全自动诊断仪
// ==========================================

%hook WWKMessage

- (id)p_parseRevokeMessage:(id)arg1 {
    NSMutableString *log = [NSMutableString string];
    [log appendString:@"========== 🔴 收到撤回数据包 ==========\n"];
    [log appendFormat:@"当前线程: %@\n", [NSThread currentThread]];
    [log appendFormat:@"撤回参数 (arg1) 类型: %@\n", [arg1 class]];
    
    @try {
        if ([(id)self respondsToSelector:@selector(text)]) {
            [log appendFormat:@"解析前 text: %@\n", [(id)self text]];
        }
    } @catch (NSException *e) {}

    // ★ 最核心：保存函数调用栈
    NSArray *syms = [NSThread callStackSymbols];
    NSString *stackString = [syms componentsJoinedByString:@"\n"];
    [log appendFormat:@"[Call Stack]:\n%@\n", stackString];

    id res = %orig;

    @try {
        if ([(id)self respondsToSelector:@selector(text)]) {
            [log appendFormat:@"解析后 text 变成了: %@\n", [(id)self text]];
        }
    } @catch (NSException *e) {}

    [log appendString:@"========== 撤回流程记录完毕 ==========\n"];

    // 核心妙招：回到主线程，强制把日志塞进手机的剪贴板！
    dispatch_async(dispatch_get_main_queue(), ^{
        [UIPasteboard generalPasteboard].string = log;
        NSLog(@"[AntiRevoke-Diag] 诊断日志已成功写入剪贴板！");
    });

    return res;
}

%end
