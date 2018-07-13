void StartStats(int client)
{
    g_iTrackingId[client]   = -1;
    g_iConnectTimes[client] = 0;

    for(int i = 0; i < view_as<int>(Stats); ++i)
    {
        g_StatsClient[client][STATS_SESSION][i] = 0;
        g_StatsClient[client][STATS_TOTAL][i] = 0;
    }

    if(IsFakeClient(client) || IsClientSourceTV(client))
        return;

    g_TimerClient[client] = CreateTimer(1.0, Timer_Client, client, TIMER_REPEAT);
}

void EndStats(int client)
{
    if(g_TimerClient[client] != INVALID_HANDLE)
        KillTimer(g_TimerClient[client]);

    g_TimerClient[client] = INVALID_HANDLE;

    if(g_iTrackingId[client] <= 0)
        return;

    char m_szQuery[256], m_szEscape[64];

    NP_MySQL_GetDatabase().Escape(g_szUsername[client], m_szEscape, 64);

    FormatEx(m_szQuery, 256, "CALL user_stats(%d, %d, %d, %d, %d, %d, '%s')", NP_Users_UserIdentity(client), g_iTrackingId[client], g_StatsClient[client][STATS_SESSION][iTodayOnlineTime], g_StatsClient[client][STATS_SESSION][iTotalOnlineTime], g_StatsClient[client][STATS_SESSION][iObserveOnlineTime], g_StatsClient[client][STATS_SESSION][iPlayOnlineTime], m_szEscape);
    NP_MySQL_SaveDatabase(m_szQuery);
}

public Action Timer_Client(Handle timer, int client)
{
    if(IsClientInGame(client) && GetClientTeam(client) > TEAM_OB)
    {
        g_StatsClient[client][STATS_SESSION][iPlayOnlineTime]++;
    }
    else
    {
        g_StatsClient[client][STATS_SESSION][iObserveOnlineTime]++;
    }
    
    g_StatsClient[client][STATS_SESSION][iTodayOnlineTime]++;
    g_StatsClient[client][STATS_SESSION][iTotalOnlineTime]++;
 
    return Plugin_Continue;
}

public int Native_TodayOnlineTime(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    return g_StatsClient[client][STATS_SESSION][iTodayOnlineTime] + g_StatsClient[client][STATS_TOTAL][iTodayOnlineTime];
}

public int Native_TotalOnlineTime(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    return g_StatsClient[client][STATS_SESSION][iTotalOnlineTime] + g_StatsClient[client][STATS_TOTAL][iTotalOnlineTime];
}

public int Native_ObserveOnlineTime(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    return g_StatsClient[client][STATS_SESSION][iObserveOnlineTime] + g_StatsClient[client][STATS_TOTAL][iObserveOnlineTime];
}

public int Native_PlayOnlineTime(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    return g_StatsClient[client][STATS_SESSION][iPlayOnlineTime] + g_StatsClient[client][STATS_TOTAL][iPlayOnlineTime];
}

public int Native_Vitality(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    return g_iClientVitality[client];
}