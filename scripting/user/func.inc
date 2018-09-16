Menu InfoMenu;

public Action Command_UserInfo(int client, int args)
{
	if (!IsValidClient(client))
		return Plugin_Handled;

	if (!NP_Users_IsAuthLoaded(client))
	{
		PrintToChat(client, "\x04[提示]\x01 你的账号信息仍未被加载！");
		return Plugin_Handled;
	}

	InfoMenu = new Menu(MenuHandler_UserInfo);
	InfoMenu.SetTitle("欢迎查看用户信息");
	InfoMenu.AddItem("ACCT", "账号信息");
	InfoMenu.AddItem("VIP", "会员信息");
	InfoMenu.ExitButton = true;
	InfoMenu.Display(client, 0);
	return Plugin_Handled;
}

public int MenuHandler_UserInfo(Menu menu, MenuAction action, int client, int slot)
{
	if (action == MenuAction_Cancel)
	{
		if(slot == MenuCancel_ExitBack)
			delete menu;
	}
	else if (action == MenuAction_Select)
	{
		switch (slot)
		{
			case 0: ShowUserInfo(client);
			case 1: ShowVIPInfo(client);
		}
	}
}

void ShowUserInfo(int client)
{
	if (!IsValidClient(client))
		return;

	char steamid[32], groupName[32];

	GetClientAuthId(client, AuthId_SteamID64, steamid, 32, true);

	if (NP_Group_GetUserGId(client) < 0)
		Format(groupName, 32, "无");
	else
		g_aGroupName.GetString(NP_Group_GetUserGId(client), groupName, 32);

	Panel panel = CreatePanel();

	panel.SetTitle("个人信息");
	DrawPanelTextEx(panel, " ");
	DrawPanelTextEx(panel, "社区个人唯一ID (UID): %d", NP_Users_UserIdentity(client));
	DrawPanelTextEx(panel, "STEAMID 64: %s", steamid);
	DrawPanelTextEx(panel, "用户组: %s", groupName);
	DrawPanelTextEx(panel, "在线时间: %d 小时", NP_Stats_TotalOnlineTime(client)/3600);
	DrawPanelTextEx(panel, "软妹币: %d 元", g_aClient[client][Money]);
	DrawPanelTextEx(panel, "签到次数: %d", g_aClient[client][SignTimes]);
	DrawPanelTextEx(panel, " ");
	panel.DrawItem("返回");
	panel.DrawItem("退出");

	panel.Send(client, MenuHandler_InfoPanel, 30);
}

void ShowVIPInfo(int client)
{
	if (!IsValidClient(client))
		return;

	char notVIP[16], expireTime[128];

	int vipPoint = g_aClient[client][VIPPoint];
	int vipExpired = g_aClient[client][VIPExpired];

	if (!NP_Vip_IsVIP(client))
	{
		if (NP_Vip_VIPLevel(client) <= 0)
			Format(notVIP, 16, "未开通");
		else
			Format(notVIP, 16, "已过期");

		Format(expireTime, 128, "未开通");
	}
	else
	{
		if (vipExpired == 99999999999)
			Format(expireTime, 128, "永久");
		else
			FormatTime(expireTime, 128, "%Y-%m-%d", vipExpired);
	}

	Panel panel = CreatePanel();
	
	panel.SetTitle("会员信息");
	DrawPanelTextEx(panel, " ");
	DrawPanelTextEx(panel, "会员状态: %s", NP_Vip_IsVIP(client) ? "已开通" : notVIP);
	DrawPanelTextEx(panel, "会员等级：%d 级", NP_Vip_VIPLevel(client));
	DrawPanelTextEx(panel, "会员成长值：%d 点", vipPoint);
	DrawPanelTextEx(panel, "到期时间：%s", expireTime);
	DrawPanelTextEx(panel, "今日获取成长值：%d/%d", g_iVIPReward[client], g_cVIPOnlineMaxReward.IntValue);
	DrawPanelTextEx(panel, " ");
	panel.DrawItem("返回");
	panel.DrawItem("退出");

	panel.Send(client, MenuHandler_InfoPanel, 30);
}

public int MenuHandler_InfoPanel(Handle menu, MenuAction action, int client, int itemNum)
{
	if(action == MenuAction_Select)
	{
		if(itemNum==1)
			InfoMenu.Display(client, 0);
	}
	else if(action == MenuAction_End)
		CloseHandle(menu);
}

public Action Command_Sign(int client, int args)
{
	if (!IsValidClient(client))
		return Plugin_Handled;

	if (!NP_Users_IsAuthLoaded(client))
	{
		PrintToChat(client, "\x04[提示]\x01 你的账号信息仍未被加载！");
		return Plugin_Handled;
	}

	int today = GetDay();

	if(g_aClient[client][SignDate] >= today)
	{
		PrintToChat(client, "\x04[提示]\x01 你已经签到过了！");
		return Plugin_Handled;
	}

	char m_szQuery[256];
	FormatEx(m_szQuery, 256, "UPDATE %s_users SET signtimes = signtimes + 1, signdate = %d WHERE uid = %d", P_SQLPRE, today, NP_Users_UserIdentity(client));
	
	if (!NP_MySQL_SaveDatabase(m_szQuery))
	{
		PrintToChat(client, "\x04[提示]\x01 签到失败，请重试！");
		return Plugin_Handled;
	}

	g_aClient[client][SignTimes]++;
	g_aClient[client][SignDate] = today;

	PrintToChat(client, "\x04[提示]\x01 签到成功！");

	MoneySigned(client);
	VIPSigned(client);

	Call_StartForward(g_hOnClientSigned);
	Call_PushCell(client);
	Call_PushCell(g_aClient[client][SignTimes]);
	Call_Finish();
	
	return Plugin_Handled;
}

public Action Timer_SignTips(Handle timer, int client)
{
	if (IsClientConnected(client))
	{
		if (GetDay() > g_aClient[client][SignDate])
		{
			PrintToChat(client,"\x04[提示] \x04您今天还未签到!聊天输入 \x05!qd \x04每日可获得软妹币!");
			PrintHintText(client, "您今天还未签到! 聊天输入 !qd 每日可获得软妹币!");
		}
	}
	else
		KillTimer(timer);

	return Plugin_Continue;
}