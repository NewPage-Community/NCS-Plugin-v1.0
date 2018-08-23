public Action Command_UserInfo(int client, const char[] command, int argc)
{
	if (!IsValidClient(client))
		return Plugin_Handled;

	if (!NP_Users_UserIdentity(client))
	{
		PrintToChat(client, "你的账号信息仍未被加载！");
		return Plugin_Handled;
	}

	Menu infoMenu = new Menu(MenuHandler_UserInfo);
	infoMenu.SetTitle("%N 您好！\n欢迎查看用户信息", client);
	infoMenu.AddItem("ACCT", "账号信息");
	infoMenu.AddItem("VIP", "会员信息");
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

	char buff[128], steamid[32], onlineTime[16], groupName[32];

	GetClientAuthId(client, AuthId_SteamID64, steamid, 32, true);

	FormatTime(onlineTime, 16, "%T", NP_Stats_TotalOnlineTime(client));

	if (NP_Group_GetUserGId(client) < 0)
		Format(groupName, 32, "无");
	else
		g_aGroupName.GetString(NP_Group_GetUserGId(client), groupName, 32);

	Format(buff, 128, "UID：%d\nSTEAMID：%s\n在线时间：%s\n用户组：%s", NP_Users_UserIdentity(client), steamid, onlineTime, groupName);

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

	if (!NP_MySQL_IsConnected())
	{
		NP_Core_LogError("User-Func", "ShowVIPInfo", "Mysql is not ready!");
		return;
	}

	int vipPoint, vipExpired;
	char m_szQuery[128], notVIP[16], expireTime[16], buff[128];

	Format(m_szQuery, 256, "SELECT `vippoint`, `vipexpired` FROM `%s_users`", P_SQLPRE);
	DBResultSet _result = SQL_Query(NP_MySQL_GetDatabase(), m_szQuery);
	if (_result == null)
	{
		char error[256];
		SQL_GetError(NP_MySQL_GetDatabase(), error, 256);
		NP_Core_LogError("User-Func", "ShowVIPInfo", "Query Server Info: %s", error);
		CreateTimer(5.0, Timer_CheckGroupName, 0, TIMER_FLAG_NO_MAPCHANGE);
		return;
	}

	if (_result.FetchRow())
	{
		vipPoint = _result.FetchInt(0);
		vipExpired = _result.FetchInt(1);
	}

	if (!NP_Vip_IsVIP(client))
	{
		if (NP_Vip_VIPLevel(client) < 0)
			Format(notVIP, 16, "未开通");
		else
			Format(notVIP, 16, "已过期");

		Format(expireTime, 16, "未开通");
	}
	else
	{
		FormatTime(expireTime, 16, "%F", vipExpired);
	}
	
	Format(buff, 128, "会员状态：%s\n会员等级：%d级\n会员积分：%d\n到期时间：%s", NP_Vip_IsVIP(client) ? "已开通" : notVIP, NP_Vip_VIPLevel(client), vipPoint, expireTime);

	Menu infoMenu = new Menu(MenuHandler_UserInfo);
	infoMenu.SetTitle("会员信息", client);
	infoMenu.AddItem("", buff, ITEMDRAW_DISABLED);
	infoMenu.ExitButton = true;
	infoMenu.Display(client, 0);
}

public Action Command_Sign(int client, const char[] command, int argc)
{
	if (!IsValidClient(client))
		return Plugin_Handled;

	if (!NP_Users_UserIdentity(client))
	{
		PrintToChat(client, "你的账号信息仍未被加载！");
		return Plugin_Handled;
	}

	return Plugin_Handled;
}