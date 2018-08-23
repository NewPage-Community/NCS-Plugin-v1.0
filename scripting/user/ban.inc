static char g_banType[3][32] = {"全服封禁", "当前模式封禁", "当前服务器封禁"};

static any g_eBan[MAXPLAYERS+1][ban_t];

bool CheckBan(int client, Handle playerinfo)
{
	char BanReason[128], BanAdminName[32];

	bool Isbanned = json_object_get_bool(playerinfo, "IsBanned");
	int BanType = json_object_get_int(playerinfo, "BanType");
	int BanETime = json_object_get_int(playerinfo, "BanETime");
	json_object_get_string(playerinfo, "BanReason", BanReason, 128);
	json_object_get_string(playerinfo, "BanAdminName", BanAdminName, 128);

	if (Isbanned)
	{
		char kickReason[256], timeExpired[64];
		if (BanETime != 0)
			FormatTime(timeExpired, 64, "%Y.%m.%d %H:%M:%S", BanETime);
		else
			FormatEx(timeExpired, 64, "永久封禁");
		FormatEx(kickReason, 256, "您已被服务器封锁,禁止进入游戏!\n封禁类型:\t%s\n封禁原因:\t%s\n操作人员:\t%s\n到期时间:\t%s\n请联系管理员", g_banType[BanType], BanReason, BanAdminName, timeExpired);
		BanClient(client, 10, BANFLAG_AUTHID, kickReason, kickReason);
		return false;
	}

	return true;
}

bool Util_BanClient(int client, int admin, int length, int bantype, const char[] reason)
{
	if (NP_Core_GetServerId() < 0)
		return false;

	if (!NP_Socket_IsReady())
		return false;

	char ip[24], steamid[32], adminname[32];

	GetClientIP(client, ip, 24, false);
	GetClientAuthId(client, AuthId_SteamID64, steamid, 32, true);

	
	if (admin > 0)
		strcopy(adminname, 32, g_aClient[admin][Name]);
	else
		strcopy(adminname, 32, "SERVER");

	char m_szQuery[512];
	FormatEx(m_szQuery, 512, "{\"Event\":\"AddBan\",\"BanInfo\":{\"UID\":%d\"SteamID\":\"%s\",\"IP\":\"%s\",\"NikeName\":\"%s\",\"Length\":%i,\"BanType\":%d,\"ServerID\":%d,\"ServerModID\":%d,\"AdminID\":%d,\"AdminName\":\"%s\",\"Reason\":\"%s\"}}", NP_Users_UserIdentity(client), steamid, ip, g_aClient[client][Name], length*60, bantype, NP_Core_GetServerId(), NP_Core_GetServerModId(), admin, adminname, reason);
	return NP_Socket_Write(m_szQuery);
}

bool Util_BanIdentity(char[] steamid, int admin, int length, int bantype, const char[] reason)
{
	if (NP_Core_GetServerId() < 0)
		return false;

	if (!NP_Socket_IsReady())
		return false;

	char adminname[32];
	
	if (admin > 0)
		strcopy(adminname, 32, g_aClient[admin][Name]);
	else
		strcopy(adminname, 32, "SERVER");

	char m_szQuery[512];
	FormatEx(m_szQuery, 512, "{\"Event\":\"AddBan\",\"BanInfo\":{\"UID\":%d\"SteamID\":\"%s\",\"IP\":\"%s\",\"NikeName\":\"%s\",\"Length\":%i,\"BanType\":%d,\"ServerID\":%d,\"ServerModID\":%d,\"AdminID\":%d,\"AdminName\":\"%s\",\"Reason\":\"%s\"}}", -1, steamid, "0.0.0.0", "N/C", length*60, bantype, NP_Core_GetServerId(), NP_Core_GetServerModId(), admin, adminname, reason);

	return NP_Socket_Write(m_szQuery);
}

void BanClientCallback(const char[] data)
{
	Handle json = json_load(data);

	char steamid[32], BanAdminName[32], BanReason[128];
	json_object_get_string(json, "SteamID", steamid, 32);
	json_object_get_string(json, "AdminName", BanAdminName, 32);
	json_object_get_string(json, "Reason", BanReason, 128);

	int BanType = json_object_get_int(json, "BanType");
	int BanETime = json_object_get_int(json, "BanETime");
	int length = json_object_get_int(json, "Length");

	int target = FindClientBySteamId(AuthId_SteamID64, steamid);
	int admin = json_object_get_int(json, "AdminID");

	CloseHandle(json);

	char kickReason[256], timeExpired[64];

	if (length != 0)
		FormatTime(timeExpired, 64, "%Y.%m.%d %H:%M:%S", BanETime);
	else
		FormatEx(timeExpired, 64, "永久封禁");

	FormatEx(kickReason, 256, "您已被服务器封锁,禁止进入游戏!\n封禁类型:\t%s\n封禁原因:\t%s\n操作人员:\t%s\n到期时间:\t%s\n请联系管理员", g_banType[BanType], BanReason, BanAdminName, timeExpired);
	BanClient(target, 10, BANFLAG_AUTHID, kickReason, kickReason);
	
	if (IsValidClient(admin))
		PrintToChat(admin, "\x07已成功封禁 \x04%s", steamid);

	char msg[512];
	FormatEx(msg, 512, "\x07玩家 \x05%s \x04(STEAMID) \x07已被封禁，原因：%s", steamid, BanReason);
	NP_AllChat_Msg(msg);
}

public int Native_BanClient(Handle plugin, int numParams)
{
	char reason[128];
	GetNativeString(5, reason, 128);
	Util_BanClient(GetNativeCell(1), GetNativeCell(2), GetNativeCell(3), GetNativeCell(4), reason);
}

public int Native_BanIdentity(Handle plugin, int numParams)
{
	char steamIdentity[32], reason[128];
	GetNativeString(1, steamIdentity, 32);
	GetNativeString(5, reason, 128);
	Util_BanIdentity(steamIdentity, GetNativeCell(2), GetNativeCell(3), GetNativeCell(4), reason);
}

public Action Command_Ban(int client, int args)
{
	if(!client)
		return Plugin_Handled;
	
	if(args < 3)
	{
		PrintToChat(client, "\x04用法\x01: sm_ban <#userid或者名字> <时间(分钟)|0为永久> [原因]");
		return Plugin_Handled;
	}

	int admin = client;

	char buffer[64];
	GetCmdArg(1, buffer, 64);
	int target = FindTarget(client, buffer, true);
	if(target == -1)
	{
		PrintToChat(client, "目标无效");
		return Plugin_Handled;
	}

	GetCmdArg(2, buffer, 64);
	int length = StringToInt(buffer);
	if(length == 0 && client && !(CheckCommandAccess(client, "sm_unban", ADMFLAG_UNBAN|ADMFLAG_ROOT)))
	{
		PrintToChat(client, "你没有永久封禁的权限");
		return Plugin_Handled;
	}

	char reason[256];
	for(int i = 3; i <= args; i++)
	{
		GetCmdArg(i, buffer, 64);
		Format(reason, 256, "%s %s", reason, buffer);
	}

	g_eBan[admin][iTarget] = target;
	g_eBan[admin][iLength] = length;
	g_eBan[admin][banProc] = ban_Client;
	
	strcopy(g_eBan[admin][szReason], 256, reason);

	Util_ShowBanType(admin);

	return Plugin_Handled;
}

void Util_ShowBanType(int admin)
{
	Menu menu = new Menu(MenuHandler_BanType);
	
	menu.SetTitle("对象: %N\n时长: %d分钟\n \n请选择封禁类型: \n ", g_eBan[admin][iTarget], g_eBan[admin][iLength]);

	menu.AddItem("", "全服封禁", CheckCommandAccess(admin, "sm_unban", ADMFLAG_UNBAN|ADMFLAG_ROOT) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);

	menu.AddItem("", "模式封禁");
	menu.AddItem("", "本服封禁");
	
	menu.ExitButton = false;
	menu.Display(admin, 0);
}

public int MenuHandler_BanType(Menu menu, MenuAction action, int admin, int slot)
{
	if(action == MenuAction_End)
		delete menu;
	else if(action == MenuAction_Select)
	{
		g_eBan[admin][iBanType] = slot;
		switch (g_eBan[admin][banProc])
		{
			case ban_Client:   Util_BanClient(g_eBan[admin][iTarget], admin, g_eBan[admin][iLength], g_eBan[admin][iBanType], g_eBan[admin][szReason]);
			case ban_Identity: Util_BanIdentity(g_eBan[admin][szAuthId], admin, g_eBan[admin][iLength], g_eBan[admin][iBanType], g_eBan[admin][szReason]);
		}
	}
}