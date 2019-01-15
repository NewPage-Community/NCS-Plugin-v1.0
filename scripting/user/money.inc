bool GiveClientMoney(int client, int money)
{
	if (!NP_Users_IsAuthLoaded(client))
		return false;

	char m_szQuery[256];
	FormatEx(m_szQuery, 256, "UPDATE %s_users SET money = money + %d WHERE uid = %d", P_SQLPRE, money, NP_Users_UserIdentity(client));

	if (NP_MySQL_SaveDatabase(m_szQuery))
	{
		g_aClient[client][Money] += money;
		return true;
	}
	
	return false;
}

bool PayClientMoney(int client, int money)
{
	if (!NP_Users_IsAuthLoaded(client))
		return false;

	if (g_aClient[client][Money] < money)
		return false;

	char m_szQuery[256];
	FormatEx(m_szQuery, 256, "UPDATE %s_users SET money = money - %d WHERE uid = %d", P_SQLPRE, money, NP_Users_UserIdentity(client));

	if (NP_MySQL_SaveDatabase(m_szQuery))
	{
		g_aClient[client][Money] -= money;
		return true;
	}
	
	return false;
}

void MoneySigned(int client)
{
	int money = g_cSignMoney.IntValue;
	int VIPmoney = g_cSignVIPMoney.IntValue;
	int OPmoney = g_cSignOPMoney.IntValue;
	int steamGroup = g_cSignSteamGroup.IntValue;

	if (SteamWorks_GetUserGroupStatus(client, P_STEAMGROUP))
		money += steamGroup;
	else
		CPrintToChat(client, "\x04[系统提示]{red} 腻还没加入我们Steam组!加入可以获得更多软妹币哦~", money);

	if (NP_Vip_IsVIP(client))
		money += VIPmoney;
	
	if (money > 0)
	{
		if (GiveClientMoney(client, money))
			CPrintToChat(client, "\x04[系统提示]{blue} 签到获得\x05%d{blue}元！", money);
	}

	if (NP_Users_IsAuthorized(client, Ctb) || NP_Users_IsAuthorized(client, Opt) || NP_Users_IsAuthorized(client, Adm) || NP_Users_IsAuthorized(client, Own))
	{
		if (GiveClientMoney(client, OPmoney))
			CPrintToChat(client, "\x04[系统提示]{blue} 管理每日工资\x05%d{blue}元！", OPmoney);
	}
}

public int Native_PayMoney(Handle plugin, int numParams)
{
	return PayClientMoney(GetNativeCell(1), GetNativeCell(2));
}

public int Native_GiveMoney(Handle plugin, int numParams)
{
	return GiveClientMoney(GetNativeCell(1), GetNativeCell(2));
}

public int Native_GetMoney(Handle plugin, int numParams)
{
	return g_aClient[GetNativeCell(1)][Money];
}