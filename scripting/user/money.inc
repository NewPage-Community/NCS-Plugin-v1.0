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
	if (NP_Vip_IsVIP(client) && VIPmoney > 0)
	{
		if (GiveClientMoney(client, VIPmoney))
			PrintToChat(client, "\x04[提示] \x01签到获得\x05%d\x01元！", VIPmoney);
	}
	else if(money > 0)
	{
		if (GiveClientMoney(client, money))
			PrintToChat(client, "\x04[提示] \x01签到获得\x05%d\x01元！", money);
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