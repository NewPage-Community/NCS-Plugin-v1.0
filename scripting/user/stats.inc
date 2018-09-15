void StartStats(int client)
{
	g_aClient[client][StatsTrackingId]   = -1;
	g_aClient[client][ConnectTimes] = 0;

	for(int i = 0; i < view_as<int>(Stats); ++i)
	{
		g_aClient[client][StatsSession][i] = 0;
		g_aClient[client][StatsTotal][i] = 0;
	}

	if(IsFakeClient(client) || IsClientSourceTV(client))
		return;

	g_aClient[client][StatsTimer] = CreateTimer(1.0, Timer_Client, client, TIMER_REPEAT);
}

void EndStats(int client)
{
	if(g_aClient[client][StatsTimer] != INVALID_HANDLE)
		KillTimer(g_aClient[client][StatsTimer]);

	g_aClient[client][StatsTimer] = INVALID_HANDLE;

	if(g_aClient[client][StatsTrackingId] <= 0)
		return;

	char m_szQuery[256], playerName[32], ip[32], map[128];

	GetClientIP(client, ip, 32);
	GetCurrentMap(map, 128);

	strcopy(playerName, 32, g_aClient[client][Name]);
	StringToJson(playerName, 32);

	FormatEx(m_szQuery, 256, "CALL user_stats(%d, %d, %d, %d, %d, %d, '%s', '%s', '%s')", NP_Users_UserIdentity(client), g_aClient[client][StatsTrackingId], g_aClient[client][StatsSession][iTodayOnlineTime], g_aClient[client][StatsSession][iTotalOnlineTime], g_aClient[client][StatsSession][iObserveOnlineTime], g_aClient[client][StatsSession][iPlayOnlineTime], playerName, ip, map);
	NP_MySQL_SaveDatabase(m_szQuery);
}

public Action Timer_Client(Handle timer, int client)
{
	if(IsClientInGame(client) && GetClientTeam(client) > TEAM_OB)
	{
		g_aClient[client][StatsSession][iPlayOnlineTime]++;
	}
	else
	{
		g_aClient[client][StatsSession][iObserveOnlineTime]++;
	}
	
	g_aClient[client][StatsSession][iTodayOnlineTime]++;
	g_aClient[client][StatsSession][iTotalOnlineTime]++;

	VIPReward(client, g_aClient[client][StatsSession][iTodayOnlineTime]);
 
	return Plugin_Continue;
}

public int Native_TodayOnlineTime(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	return g_aClient[client][StatsSession][iTodayOnlineTime] + g_aClient[client][StatsTotal][iTodayOnlineTime];
}

public int Native_TotalOnlineTime(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	return g_aClient[client][StatsSession][iTotalOnlineTime] + g_aClient[client][StatsTotal][iTotalOnlineTime];
}

public int Native_ObserveOnlineTime(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	return g_aClient[client][StatsSession][iObserveOnlineTime] + g_aClient[client][StatsTotal][iObserveOnlineTime];
}

public int Native_PlayOnlineTime(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	return g_aClient[client][StatsSession][iPlayOnlineTime] + g_aClient[client][StatsTotal][iPlayOnlineTime];
}

public int Native_Vitality(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	return g_aClient[client][Vitality];
}

public Action Timer_Global(Handle timer)
{
	int today = GetDay();

	if(today != g_iToday)
	{
		g_iToday = today;
		
		for(int client = 1; client <= MaxClients; ++client)
		{
			g_aClient[client][StatsSession][iTodayOnlineTime] = 0;
			g_aClient[client][StatsTotal][iTodayOnlineTime]   = 0;
			g_iVIPReward[client] = 0;
		}
	}
	
	return Plugin_Continue;
}