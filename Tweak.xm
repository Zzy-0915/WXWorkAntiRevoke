#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// ==========================================
// 全局纯内存防崩溃流水账
// ==========================================
static NSMutableArray<NSString *> *s_globalMessagePool = nil;

static void recordRawText(NSString *str) {
    if (!str || str.length == 0) return;
    if ([str containsString:@"撤回了一条消息"]) return;

    if (!s_globalMessagePool) {
        s_globalMessagePool = [[NSMutableArray alloc] initWithCapacity:50];
    }
    @synchronized (s_globalMessagePool) {
        // 避免重复存入相同文本
        if (![s_globalMessagePool.lastObject isEqualToString:str]) {
            [s_globalMessagePool addObject:str];
            if (s_globalMessagePool.count > 50) {
                [s_globalMessagePool removeObjectAtIndex:0];
            }
        }
    }
}

static NSString *getLatestRevokedBackup(void) {
    if (!s_globalMessagePool) return nil;
    @synchronized (s_globalMessagePool) {
        if (s_globalMessagePool.count > 0) {
            return s_globalMessagePool.lastObject;
        }
    }
    return nil;
}

// ==========================================
// 1. 核心模型层：100% 安全读取，不使用任何 KVC
// ==========================================
%hook WWKMessage

// 拦截纯文本
- (NSString *)text {
    NSString *orig = %orig;
    if (!orig || orig.length == 0) return orig;

    // 正常文本：安全归档
    if (![orig containsString:@"撤回了一条消息"]) {
        recordRawText(orig);
        return orig;
    }

    // 撤回文本：提取上一条正常文字还魂
    NSString *backup = getLatestRevokedBackup();
    if (backup && backup.length > 0) {
        return [NSString stringWithFormat:@"%@  [对方已撤回]", backup];
    }
    return orig;
}

// 拦截富文本（UI气泡实际绘制入口）
- (NSAttributedString *)attrText {
    NSAttributedString *orig = %orig;
    if (!orig || orig.string.length == 0) return orig;

    // 正常富文本
    if (![orig.string containsString:@"撤回了一条消息"]) {
        recordRawText(orig.string);
        return orig;
    }

    // 还原被撤回的富文本展示
    NSString *backup = getLatestRevokedBackup();
    if (backup && backup.length > 0) {
        NSMutableAttributedString *mut = [[NSMutableAttributedString alloc] initWithString:backup];
        // 采用克制、自然的灰色系统样式提示
        NSAttributedString *tag = [[NSAttributedString alloc] initWithString:@"  [对方已撤回]" 
                                                                  attributes:@{
                                                                      NSForegroundColorAttributeName: [UIColor lightGrayColor],
                                                                      NSFontAttributeName: [UIFont systemFontOfSize:12]
                                                                  }];
        [mut appendAttributedString:tag];
        return mut;
    }
    return orig;
}

%end

// ==========================================
// 2. 界面控制与引用安全保护
// ==========================================
%hook WWKConversationNewViewController
- (void)revokeMessageWithFirstAlert:(id)arg1 {}
%end

%hook WWKConversationQuoteBubbleView
- (BOOL)quotedRevoked {
    return NO;
}
%end
