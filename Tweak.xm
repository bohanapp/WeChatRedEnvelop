#import "WeChatRedEnvelop.h"
#import "WeChatRedEnvelopParam.h"
#import "WBSettingViewController.h"

%hook WCRedEnvelopesLogicMgr

- (void)OnWCToHongbaoCommonResponse:(HongBaoRes *)arg1 Request:(id)arg2 {

	%orig;

	WeChatRedEnvelopParam *mgrParams = [WeChatRedEnvelopParam sharedInstance];
	
	// 如果不是自动抢红包，则无需继续
	if (!mgrParams.autoReceiveRedEnvelop) { return; }

	// 重置标志
	mgrParams.autoReceiveRedEnvelop = NO;

	NSString *string = [[NSString alloc] initWithData:arg1.retText.buffer encoding:NSUTF8StringEncoding];
	NSDictionary *dictionary = [string JSONDictionary];

	// 没有这个字段会被判定为使用外挂
	if (!dictionary[@"timingIdentifier"]) { return; }

	if (mgrParams.redEnvelopSwitchOn && (mgrParams.redEnvelopInChatRoomFromOther || mgrParams.redEnvelopInChatRoomFromMe)) {
		mgrParams.timingIdentifier = dictionary[@"timingIdentifier"];

		// NSString *message = [NSString stringWithFormat:@"%@", [mgrParams toParams]];
	 //   	UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Alert" message:message delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
	 //   	[alert show];

		NSInteger delaySeconds = [[NSUserDefaults standardUserDefaults] integerForKey:@"XGDelaySecondsKey"];
		// NSUInteger randomSeconds = arc4random_uniform(delaySeconds);
		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delaySeconds * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
			WCRedEnvelopesLogicMgr *logicMgr = [[objc_getClass("MMServiceCenter") defaultCenter] getService:[objc_getClass("WCRedEnvelopesLogicMgr") class]];
			[logicMgr OpenRedEnvelopesRequest:[mgrParams toParams]];
		});
	}
}

%end

%hook CMessageMgr
- (void)AsyncOnAddMsg:(NSString *)msg MsgWrap:(CMessageWrap *)wrap {
	%orig;
	
	switch(wrap.m_uiMessageType) {
	case 49: { // AppNode

		CContactMgr *contactManager = [[objc_getClass("MMServiceCenter") defaultCenter] getService:[objc_getClass("CContactMgr") class]];
		CContact *selfContact = [contactManager getSelfContact];

		BOOL isMesasgeFromMe = NO;
		if ([wrap.m_nsFromUsr isEqualToString:selfContact.m_nsUsrName]) {
			isMesasgeFromMe = YES;
		}

		if ([wrap.m_nsContent rangeOfString:@"wxpay://"].location != NSNotFound) { // 红包
			
			WeChatRedEnvelopParam *mgrParams = [WeChatRedEnvelopParam sharedInstance];

			// 是否打开红包开关
			BOOL redEnvelopSwitchOn = [[NSUserDefaults standardUserDefaults] boolForKey:@"XGWeChatRedEnvelopSwitchKey"];

			// 群聊中，别人发红包
			BOOL redEnvelopInChatRoomFromOther = ([wrap.m_nsFromUsr rangeOfString:@"@chatroom"].location != NSNotFound);
			
			// 群聊中，自己发红包
			BOOL redEnvelopInChatRoomFromMe = (isMesasgeFromMe && ([wrap.m_nsToUsr rangeOfString:@"@chatroom"].location != NSNotFound));

			if (redEnvelopSwitchOn && (redEnvelopInChatRoomFromOther || redEnvelopInChatRoomFromMe)) {

				NSString *nativeUrl = [[wrap m_oWCPayInfoItem] m_c2cNativeUrl];
				nativeUrl = [nativeUrl substringFromIndex:[@"wxpay://c2cbizmessagehandler/hongbao/receivehongbao?" length]];
				NSDictionary *nativeUrlDict = [%c(WCBizUtil) dictionaryWithDecodedComponets:nativeUrl separator:@"&"];

				WCRedEnvelopesLogicMgr *logicMgr = [[objc_getClass("MMServiceCenter") defaultCenter] getService:[objc_getClass("WCRedEnvelopesLogicMgr") class]];
				
				NSMutableDictionary *params = [@{} mutableCopy];
				params[@"agreeDuty"] = @"0";
				params[@"channelId"] = nativeUrlDict[@"channelid"] ?: @"1";
				params[@"inWay"] = @"0";
				params[@"msgType"] = nativeUrlDict[@"msgtype"] ?: @"1";
				params[@"nativeUrl"] = [[wrap m_oWCPayInfoItem] m_c2cNativeUrl] ?: @"";
				params[@"sendId"] = nativeUrlDict[@"sendid"] ?: @"";

				[logicMgr ReceiverQueryRedEnvelopesRequest:params];

				mgrParams.msgType = nativeUrlDict[@"msgtype"] ?: @"1";
				mgrParams.sendId = nativeUrlDict[@"sendid"] ?: @"";
				mgrParams.channelId = nativeUrlDict[@"channelid"] ?: @"1";
				mgrParams.nickName = [selfContact getContactDisplayName] ?: @"小锅";
				mgrParams.headImg = [selfContact m_nsHeadImgUrl] ?: @"";
				mgrParams.nativeUrl = [[wrap m_oWCPayInfoItem] m_c2cNativeUrl] ?: @"";
				mgrParams.sessionUserName = redEnvelopInChatRoomFromMe ? wrap.m_nsToUsr : wrap.m_nsFromUsr;
				mgrParams.redEnvelopSwitchOn = redEnvelopSwitchOn;
				mgrParams.redEnvelopInChatRoomFromMe = redEnvelopInChatRoomFromMe;
				mgrParams.redEnvelopInChatRoomFromOther = redEnvelopInChatRoomFromOther;
				mgrParams.autoReceiveRedEnvelop = YES;
			}
		}	
		break;
	}
	default:
		break;
	}
	
}
%end

%hook NewSettingViewController

- (void)reloadTableData {
	%orig;

	MMTableViewInfo *tableViewInfo = MSHookIvar<id>(self, "m_tableViewInfo");

	MMTableViewSectionInfo *sectionInfo = [%c(MMTableViewSectionInfo) sectionInfoDefaut];

	MMTableViewCellInfo *settingCell = [%c(MMTableViewCellInfo) normalCellForSel:@selector(setting) target:self title:@"红包助手" accessoryType:1];
	[sectionInfo addCell:settingCell];

	[tableViewInfo insertSection:sectionInfo At:0];

	MMTableView *tableView = [tableViewInfo getTableView];
	[tableView reloadData];
}

%new
- (void)setting {
	WBSettingViewController *settingViewController = [WBSettingViewController new];
	[self.navigationController PushViewController:settingViewController animated:YES];
}

%end
