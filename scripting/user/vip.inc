void GrantVip(int client, int duration)
{
	if(!NP_Socket_IsReady())
	{
		NP_Core_LogError("Vip", "GrantVip", "Error: Socket is unavailable -> \"%L\"", client);
		return;
	}

	char m_szQuery[256];
	FormatEx(m_szQuery, 256, "UPDATE %s_users SET vipexpired = '%d' WHERE uid = '%d'", P_SQLPRE, GetTime()+duration*86400, NP_Users_UserIdentity(client));
	NP_MySQL_SaveDatabase(m_szQuery);
}

void DeleteVip(int client)
{
	//if player isn's vip
	if(!g_aClient[client][Auth][Vip])
		return;

	if(!NP_Socket_IsReady())
	{
		NP_Core_LogError("Vip", "GrantVip", "Error: Socket is unavailable -> \"%L\"", client);
		return;
	}

	char m_szQuery[256];
	FormatEx(m_szQuery, 256, "UPDATE %s_users SET vipexpired = '%d' WHERE uid = '%d'", P_SQLPRE, 0, NP_Users_UserIdentity(client));
	NP_MySQL_SaveDatabase(m_szQuery);
}

void AddVipPoint(int client, int point)
{
	//if player isn's vip
	if(!g_aClient[client][Auth][Vip])
		return;

	if(!NP_Socket_IsReady())
	{
		NP_Core_LogError("Vip", "GrantVip", "Error: Socket is unavailable -> \"%L\"", client);
		return;
	}

	char m_szQuery[256];
	FormatEx(m_szQuery, 256, "UPDATE %s_users SET vippoint = vippoint + '%d' WHERE uid = '%d'", P_SQLPRE, point, NP_Users_UserIdentity(client));
	NP_MySQL_SaveDatabase(m_szQuery);
}

public int Native_IsVIP(Handle plugin, int numParams)
{
	return g_aClient[GetNativeCell(1)][Auth][Vip];
}

public int Native_VIPLevel(Handle plugin, int numParams)
{
	return g_aClient[GetNativeCell(1)][VipLevel];
}

public int Native_GrantVip(Handle plugin, int numParams)
{
	GrantVip(GetNativeCell(1), GetNativeCell(2));
}

public int Native_DeleteVip(Handle plugin, int numParams)
{
	DeleteVip(GetNativeCell(1));
}

public int Native_AddVipPoint(Handle plugin, int numParams)
{
	AddVipPoint(GetNativeCell(1), GetNativeCell(2));
}

void VIPConnected(int client)
{
	if (!NP_Vip_IsVIP(client))
		return;

	if (g_aClient[client][StatsTotal][iTodayOnlineTime] == 0)
	{
		char msg[512];
		FormatEx(msg, 512, "会员 - \x07%s\x01：叛乱，启动！", g_aClient[client][Name]);
		NP_AllChat_Msg(msg);
	}

	PrintToChatAll("欢迎会员 \x07%s 加入本服务器！");
}