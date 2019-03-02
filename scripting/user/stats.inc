KeyValues g_KVCache;

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

	char m_szQuery[256], playerName[32];
	
	strcopy(playerName, 32, g_aClient[client][Name]);
	StringToJson(playerName, 32);

	FormatEx(m_szQuery, 256, "CALL user_stats(%d, %d, %d, %d, %d, %d, '%s')", NP_Users_UserIdentity(client), g_aClient[client][StatsTrackingId], g_aClient[client][StatsTotal][iTodayOnlineTime] + g_aClient[client][StatsSession][iTodayOnlineTime], g_aClient[client][StatsSession][iTotalOnlineTime], g_aClient[client][StatsSession][iObserveOnlineTime], g_aClient[client][StatsSession][iPlayOnlineTime], playerName);
	NP_MySQL_SaveDatabase(m_szQuery);

	// Delete cache
	char m_szAuth[32];
	GetClientAuthId(client, AuthId_Engine, m_szAuth, 32, true);
	
	g_KVCache.Rewind();
	if(g_KVCache.JumpToKey(m_szAuth, false))
	{
		g_KVCache.DeleteThis();
		g_KVCache.Rewind();
		g_KVCache.ExportToFile(g_cCacheFile);
	}
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

	VIPReward(client, NP_Stats_TodayOnlineTime(client));
 
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

			// 重置VIP在线经验上限
			g_iVIPReward[client] = 0;
			VIPRewardReset(client);
		}
	}
	
	return Plugin_Continue;
}

public Action Timer_StatsCheckCache(Handle timer)
{
	g_KVCache = new KeyValues("PlayerStats");
	g_KVCache.ImportFromFile(g_cCacheFile);

	if(!g_KVCache.GotoFirstSubKey(true))
	{
		CreateTimer(1.0, Timer_StatsSaveCache, _, TIMER_REPEAT);
		return Plugin_Stop;
	}

	int count = 0;

	do
	{
		int uniqueid = g_KVCache.GetNum("uid", 0);
		int stid = g_KVCache.GetNum("stid", 0); //StatsTrackingId
		int tot = g_KVCache.GetNum("tot", 0); //TodayOnlineTime
		int ttot = g_KVCache.GetNum("ttot", 0); //TotalOnlineTime
		int oot = g_KVCache.GetNum("oot", 0); //ObserveOnlineTime
		int pot = g_KVCache.GetNum("pot", 0); //PlayOnlineTime
		
		char tname[32], m_szQuery[256];
		g_KVCache.GetString("tname", tname, 32);
		StringToJson(tname, 32);

		if (!uniqueid)
			continue;

		// Database not record
		if (stid == -1)
			continue;

		FormatEx(m_szQuery, 256, "CALL user_stats(%d, %d, %d, %d, %d, %d, '%s')", uniqueid, stid, tot, ttot, oot, pot, tname);
		NP_MySQL_SaveDatabase(m_szQuery);

		count++;
	}
	while(g_KVCache.GotoNextKey(true));

	if (count > 0)
		NP_Core_LogMessage("User", "Timer_StatsCheckCache", "Saved %d cache data!", count);

	delete g_KVCache;

	g_KVCache = new KeyValues("PlayerStats", "", "");
	g_KVCache.ExportToFile(g_cCacheFile);

	CreateTimer(1.0, Timer_StatsSaveCache, _, TIMER_REPEAT);
	
	return Plugin_Stop;
}

public Action Timer_StatsSaveCache(Handle timer)
{
	g_KVCache.Rewind();
	
	char steamid[32];
	for(int client = 1; client <= MaxClients; ++client)
		if(g_aClient[client][AuthLoaded] && g_aClient[client][UID] > 0)
			if(GetClientAuthId(client, AuthId_Engine, steamid, 32, false))
			{
				// Database not record
				if (g_aClient[client][StatsTrackingId] == -1)
					continue;

				g_KVCache.JumpToKey(steamid, true);
				g_KVCache.SetNum("uid", g_aClient[client][UID]);
				g_KVCache.SetNum("stid", g_aClient[client][StatsTrackingId]);
				g_KVCache.SetNum("tot", g_aClient[client][StatsTotal][iTodayOnlineTime] + g_aClient[client][StatsSession][iTodayOnlineTime]);
				g_KVCache.SetNum("ttot", g_aClient[client][StatsSession][iTotalOnlineTime]);
				g_KVCache.SetNum("oot", g_aClient[client][StatsSession][iObserveOnlineTime]);
				g_KVCache.SetNum("pot", g_aClient[client][StatsSession][iPlayOnlineTime]);

				g_KVCache.SetString("tname", g_aClient[client][Name]);

				g_KVCache.Rewind();
			}

	g_KVCache.Rewind();
	g_KVCache.ExportToFile(g_cCacheFile);
	
	return Plugin_Continue;
}