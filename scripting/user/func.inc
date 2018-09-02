public Action Command_UserInfo(int client, int args)
{
	if (!IsValidClient(client))
		return Plugin_Handled;

	if (!NP_Users_IsAuthLoaded(client))
	{
		PrintToChat(client, "你的账号信息仍未被加载！");
		return Plugin_Handled;
	}

	Menu infoMenu = new Menu(MenuHandler_UserInfo);
	infoMenu.SetTitle("%s 您好！\n欢迎查看用户信息", g_aClient[client][Name]);
	infoMenu.AddItem("ACCT", "账号信息");
	infoMenu.AddItem("VIP", "会员信息");
	infoMenu.ExitButton = true;
	infoMenu.Display(client, 0);
	return Plugin_Handled;
}

public int MenuHandler_UserInfo(Menu menu, MenuAction action, int client, int slot)
{
	if (action == MenuAction_End)
		delete menu;
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

	char buff[512], steamid[32], groupName[32];

	GetClientAuthId(client, AuthId_SteamID64, steamid, 32, true);

	if (NP_Group_GetUserGId(client) < 0)
		Format(groupName, 32, "无");
	else
		g_aGroupName.GetString(NP_Group_GetUserGId(client), groupName, 32);

	Format(buff, 512, "UID：%d\nSTEAMID：%s\n在线时间：%d小时\n用户组：%s\n签到次数：%d\n软妹币：%d元", NP_Users_UserIdentity(client), steamid, NP_Stats_TotalOnlineTime(client)/3600, groupName, g_aClient[client][SignTimes], g_aClient[client][Money]);

	Menu infoMenu = new Menu(MenuHandler_UserInfo);
	infoMenu.SetTitle("账号信息", client);
	infoMenu.AddItem("", buff, ITEMDRAW_DISABLED);
	infoMenu.ExitButton = true;
	infoMenu.Display(client, 0);
}

void ShowVIPInfo(int client)
{
	if (!IsValidClient(client))
		return;

	char notVIP[16], expireTime[128], buff[512];

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
			FormatTime(expireTime, 128, "%m月%d日 %H时%M分", vipExpired);
	}
	
	Format(buff, 512, "会员状态：%s\n会员等级：%d级\n会员成长值：%d\n到期时间：%s\n今日获取成长值：%d/%d", NP_Vip_IsVIP(client) ? "已开通" : notVIP, NP_Vip_VIPLevel(client), vipPoint, expireTime, g_iVIPReward[client], g_cVIPOnlineMaxReward.IntValue);

	Menu infoMenu = new Menu(MenuHandler_UserInfo);
	infoMenu.SetTitle("会员信息", client);
	infoMenu.AddItem("", buff, ITEMDRAW_DISABLED);
	infoMenu.ExitButton = true;
	infoMenu.Display(client, 0);
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

public Action SetTeams(Handle timer, int client)
{
	if (IsClientInGame(client))
		if (GetDay() > g_aClient[client][SignDate])
			PrintToChat(client,"\x04[提示] \x04您今天还未签到!输入 \x05!qd \x04每日可获得软妹币!");
}