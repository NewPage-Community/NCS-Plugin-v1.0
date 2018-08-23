public int Native_GetUserGId(Handle plugin, int numParams)
{
	return g_aClient[GetNativeCell(1)][GID];
}

public int Native_IsGIdValid(Handle plugin, int numParams)
{
	return (GetNativeCell(1) != -1) ? 1 : 0;
}

public int Native_GetUserGName(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);

	if (!IsValidClient(client))
		ThrowNativeError(SP_ERROR_PARAM, "client index %d in invalid.", client);

	if (g_aClient[client][GID] <= 0)
		return false;

	char groupName[32];

	g_aGroupName.GetString(g_aClient[client][GID], groupName, 32);

	SetNativeString(2, groupName, GetNativeCell(3), true);

	return true;
}

void CheckGroup()
{
	if(!NP_MySQL_IsConnected())
	{
		NP_Core_LogError("User-Group", "CheckGroupName", "Mysql is not ready!");
		CreateTimer(5.0, Timer_CheckGroupName, 0, TIMER_FLAG_NO_MAPCHANGE);
		return;
	}

	char m_szQuery[128];
	Format(m_szQuery, 256, "SELECT gid, gname FROM `%s_groups`", P_SQLPRE);
	DBResultSet _result = SQL_Query(NP_MySQL_GetDatabase(), m_szQuery);
	if(_result == null)
	{
		char error[256];
		SQL_GetError(NP_MySQL_GetDatabase(), error, 256);
		NP_Core_LogError("User-Group", "CheckGroupName", "Query Server Info: %s", error);
		CreateTimer(5.0, Timer_CheckGroupName, 0, TIMER_FLAG_NO_MAPCHANGE);
		return;
	}

	while(_result.FetchRow())
	{
		char groupName[32];
		_result.FetchString(1, groupName, 32);
		g_aGroupName.SetString(_result.FetchInt(0), groupName);
	}
}

public Action Timer_CheckGroupName(Handle timer)
{
	NP_Core_OnInitialized(0, 0);
	return Plugin_Stop;
}