#import <UIKit/UIKit.h>
#import <objc/runtime.h>

@interface CMessageWrap : NSObject
@property (nonatomic, assign) NSUInteger m_uiMessageType; // 1:文字, 3:图片, 43:视频, 47:表情/动画
@property (nonatomic, retain) NSString *m_nsContent;      // 消息主体文本
@property (nonatomic, assign) NSUInteger m_uiMesLocalID;  // 本地消息ID
@property (nonatomic, retain) NSString *m_nsFromUsr;     // 发送者
@property (nonatomic, retain) NSString *m_nsToUsr;       // 接收者
@property (nonatomic, assign) BOOL m_isAntiRevoked;      // 标记是否被防撤回拦截
@end

@interface CMessageMgr : NSObject
- (void)UpdateMsgContent:(NSString *)fromUser MsgWrap:(CMessageWrap *)msgWrap;
- (void)DelMsg:(NSString *)fromUser MsgList:(NSArray *)msgList DelAll:(BOOL)delAll;
@end

// 记录已被撤回的本地消息 ID 集合
static NSMutableSet<NSNumber *> *g_antiRevokeMsgIDs = nil;

%hook CMessageMgr

// 拦截系统下发的撤回指令
- (void)onRevokeMsg:(CMessageWrap *)msgWrap {
    if (!msgWrap) {
        %orig;
        return;
    }

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        g_antiRevokeMsgIDs = [[NSMutableSet alloc] init];
    });

    NSNumber *msgID = @(msgWrap.m_uiMesLocalID);

    // 避免重复拦截逻辑
    if ([g_antiRevokeMsgIDs containsObject:msgID]) {
        return;
    }
    [g_antiRevokeMsgIDs addObject:msgID];

    msgWrap.m_isAntiRevoked = YES;
    NSString *tagText = @" [已撤回]";

    // 根据消息类型处理（文字、图片、视频、表情）
    switch (msgWrap.m_uiMessageType) {
        case 1: { // 文本消息
            if (msgWrap.m_nsContent && ![msgWrap.m_nsContent containsString:tagText]) {
                msgWrap.m_nsContent = [msgWrap.m_nsContent stringByAppendingString:tagText];
            }
            break;
        }
        case 3:   // 图片消息
        case 43:  // 视频消息
        case 47:  // 表情/Sticker
        default: {
            // 非文本富媒体保留缓存文件，并在消息描述处附带撤回标记
            if (msgWrap.m_nsContent == nil || msgWrap.m_nsContent.length == 0) {
                msgWrap.m_nsContent = tagText;
            } else if (![msgWrap.m_nsContent containsString:tagText]) {
                msgWrap.m_nsContent = [msgWrap.m_nsContent stringByAppendingString:tagText];
            }
            break;
        }
    }

    // 强行刷新内存与本地数据库中的消息文本，使其原样留在聊天界面
    [self UpdateMsgContent:msgWrap.m_nsFromUsr MsgWrap:msgWrap];

    // 拦截并终止原生的本地擦除与UI删除方法
    return;
}

// 拦截UI层消息删除指令
- (void)DelMsg:(NSString *)fromUser MsgList:(NSArray *)msgList DelAll:(BOOL)delAll {
    NSMutableArray *filteredList = [NSMutableArray array];
    for (CMessageWrap *msg in msgList) {
        if ([g_antiRevokeMsgIDs containsObject:@(msg.m_uiMesLocalID)]) {
            // 阻断撤回引发的擦除
            continue;
        }
        [filteredList addObject:msg];
    }
    if (filteredList.count > 0) {
        %orig(fromUser, filteredList, delAll);
    }
}

%end

// 动态分类，给 CMessageWrap 绑定 m_isAntiRevoked 属性
%hook CMessageWrap

%property (nonatomic, assign) BOOL m_isAntiRevoked;

%end
