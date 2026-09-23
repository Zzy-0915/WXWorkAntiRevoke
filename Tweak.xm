#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// 辅助方法：将文本写入系统文件中
static void writeLogToFile(NSString *logString) {
    if (!logString) return;
    
    // 我们把日志写到越狱环境下任意 App 都能访问的用户文档目录
    NSString *logPath = @"/var/mobile/Documents/AntiRevoke_Diag.txt";
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    // 添加时间戳
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyy-MM-dd HH:mm:ss.SSS"];
    NSString *dateString = [formatter stringFromDate:[NSDate date]];
    NSString *formattedLog = [NSString stringWithFormat:@"[%@] %@\n", dateString, logString];
    
    if (![fileManager fileExistsAtPath:logPath]) {
        [formattedLog writeToFile:logPath atomically:YES encoding:NSUTF8StringEncoding error:nil];
    } else {
        NSFileHandle *fileHandle = [NSFileHandle fileHandleForWritingAtPath:logPath];
        if (fileHandle) {
            [fileHandle seekToEndOfFile];
            [fileHandle writeData:[formattedLog dataUsingEncoding:NSUTF8StringEncoding]];
            [fileHandle closeFile];
        }
    }
}

// ==========================================
// 企业微信防撤回 - 文件输出型诊断仪
// ==========================================

%hook WWKMessage

- (id)p_parseRevokeMessage:(id)arg1 {
    writeLogToFile(@"========== 🔴 收到撤回数据包 ==========");
    writeLogToFile([NSString stringWithFormat:@"当前线程: %@", [NSThread currentThread]]);
    writeLogToFile([NSString stringWithFormat:@"撤回参数 (arg1) 类型: %@", [arg1 class]]);
    writeLogToFile([NSString stringWithFormat:@"撤回参数 (arg1) 内容: %@", arg1]);
    
    @try {
        if ([(id)self respondsToSelector:@selector(text)]) {
            writeLogToFile([NSString stringWithFormat:@"解析前 text: %@", [(id)self text]]);
        }
        if ([(id)self respondsToSelector:@selector(msgKey)]) {
            writeLogToFile([NSString stringWithFormat:@"解析前 msgKey: %@", [(id)self valueForKey:@"msgKey"]]);
        }
    } @catch (NSException *e) {
        writeLogToFile([NSString stringWithFormat:@"属性读取异常: %@", e]);
    }

    // ★ 最核心：保存函数调用栈，看看到底是哪个底层方法杀了我们
    NSArray *syms = [NSThread callStackSymbols];
    NSString *stackString = [syms componentsJoinedByString:@"\n"];
    writeLogToFile([NSString stringWithFormat:@"[Call Stack]:\n%@", stackString]);

    id res = %orig;

    @try {
        if ([(id)self respondsToSelector:@selector(text)]) {
            writeLogToFile([NSString stringWithFormat:@"解析后 text 变成了: %@", [(id)self text]]);
        }
    } @catch (NSException *e) {}

    writeLogToFile(@"========== 撤回流程记录完毕 ==========\n\n");
    return res;
}

%end
