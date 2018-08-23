bool GiveClientMoney(int client, int money)
{
	if (!NP_Users_IsAuthLoaded(client))
		return false;

	if(!NP_Socket_IsReady())
	{
		NP_Core_LogError("User-Money", "AddClientMoney", "Error: Socket is unavailable -> \"%L\"", client);
		return false;
	}

	char m_szQuery[256];
	FormatEx(m_szQuery, 256, "UPDATE %s_users SET money = money + '%d' WHERE uid = '%d'", P_SQLPRE, money, NP_Users_UserIdentity(client));

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

	if(!NP_Socket_IsReady())
	{
		NP_Core_LogError("User-Money", "PayClientMoney", "Error: Socket is unavailable -> \"%L\"", client);
		return false;
	}

	if (g_aClient[client][Money] < money)
		return false;

	char m_szQuery[256];
	FormatEx(m_szQuery, 256, "UPDATE %s_users SET money = money - '%d' WHERE uid = '%d'", P_SQLPRE, money, NP_Users_UserIdentity(client));

	if (NP_MySQL_SaveDatabase(m_szQuery))
	{
		g_aClient[client][Money] -= money;
		return true;
	}
	
	return false;
}

public void NP_OnClientSigned(int client, int signtimes)
{		
	if (GiveClientMoney(client, 3000))
		PrintToChat(client, "\x04[提示] \x01签到获得\x053000\x01元！");
}