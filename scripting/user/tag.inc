public int Native_SetTag(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	GetNativeString(2, g_aClient[client][Tag], 16);
	if(NP_Users_IsAuthLoaded(client))
		ChangePlayerPreName(client);
}

public int Native_GetTag(Handle plugin, int numParams)
{
	SetNativeString(2, g_aClient[GetNativeCell(1)][Tag], GetNativeCell(3), true);
}

void ChangePlayerPreName(int client)
{
	char newName[64], oldName[64], game[32];
	GetGameFolderName(game, 32);

	GetClientName(client, oldName, 64);

	// get player name if it invalid
	if(g_aClient[client][Name][0] == '\0')
		GetClientName(client, g_aClient[client][Name], 32);
		
	strcopy(newName, 64, g_aClient[client][Name]);

	// Tag
	if(g_aClient[client][Tag][0] != '\0')
		Format(newName, 64, "[%s] %s", g_aClient[client][Tag], newName);

	if (!strcmp(game, "cstrike") || !strcmp(game, "csgo"))
	{
		CreateTimer(5.0, Timer_ChangeClan, client);
	}
	else
	{
		if(g_aClient[client][GID] != -1)
		{
			char groupName[32];
			g_aGroupName.GetString(g_aClient[client][GID], groupName, 32);
			Format(newName, 64, "<%s> %s", groupName, newName);
		}
		else if(g_aClient[client][Auth][Own])
		{
			Format(newName, 64, "<服主> %s", newName);
		}
		else if(g_aClient[client][Auth][Adm])
		{
			Format(newName, 64, "<ADMIN> %s", newName);
		}
		else if(g_aClient[client][Auth][Opt])
		{
			Format(newName, 64, "<管理> %s", newName);
		}
		else if(g_aClient[client][Auth][Ctb])
		{
			Format(newName, 64, "<员工> %s", newName);
		}
		else if(g_aClient[client][Auth][Vip])
		{
			Format(newName, 64, "<会员> %s", newName);
		}
		else if(g_aClient[client][Auth][Spt])
		{
			Format(newName, 64, "<捐助> %s", newName);
		}
	}
	
	if (!StrEqual(oldName, newName))
		SetClientName(client, newName);
}

public Action Timer_ChangeClan(Handle timer, int client)
{
	if (!NP_Users_IsAuthLoaded(client) || !IsClientConnected(client))
		return Plugin_Stop;

	if (!IsClientInGame(client))
	{
		CreateTimer(5.0, Timer_ChangeClan, client);
		return Plugin_Stop;
	}

	char tag[64];

	if(g_aClient[client][GID] != -1)
	{
		char groupName[32];
		g_aGroupName.GetString(g_aClient[client][GID], groupName, 32);
		
		Format(tag, 64, "<%s>", groupName);
	}
	else if(g_aClient[client][Auth][Own])
	{
		Format(tag, 64, "<服主>");
	}
	else if(g_aClient[client][Auth][Adm])
	{
		Format(tag, 64, "<ADMIN>");
	}
	else if(g_aClient[client][Auth][Opt])
	{
		Format(tag, 64, "<管理>");
	}
	else if(g_aClient[client][Auth][Ctb])
	{
		Format(tag, 64, "<员工>");
	}
	else if(g_aClient[client][Auth][Vip])
	{
		Format(tag, 64, "<会员>");
	}
	else if(g_aClient[client][Auth][Spt])
	{
		Format(tag, 64, "<捐助>");
	}

	CS_SetClientClanTag(client, tag);

	return Plugin_Stop;
}