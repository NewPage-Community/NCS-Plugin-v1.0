public int Native_SetTag(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	GetNativeString(2, g_szUserTag[client], 16);
	ChangePlayerPreName(client);
}

void ChangePlayerPreName(int client)
{
	char newName[64], oldName[64];

	GetClientName(client, oldName, 64);

	// get player name if it invalid
	if(g_szUsername[client][0] == '\0')
		GetClientName(client, g_szUsername[client], 32);
		
	strcopy(newName, 64, g_szUsername[client]);

	// Tag
	if(g_szUserTag[client][0] != '\0')
		Format(newName, 64, "[%s] %s", g_szUserTag[client], newName);

	if(g_iUserGroupId[client] != -1)
	{
		char groupName[32];
		g_aGroupName.GetString(g_iUserGroupId[client], groupName, 32);
		Format(newName, 64, "[%s] %s", groupName, newName);
	}
	else if(g_authClient[client][Own])
	{
		Format(newName, 64, "[服主] %s", newName);
	}
	else if(g_authClient[client][Adm])
	{
		Format(newName, 64, "[ADMIN] %s", newName);
	}
	else if(g_authClient[client][Opt])
	{
		Format(newName, 64, "[管理] %s", newName);
	}
	else if(g_authClient[client][Ctb])
	{
		Format(newName, 64, "[员工] %s", newName);
	}
	else if(g_authClient[client][Vip])
	{
		Format(newName, 64, "[会员] %s", newName);
	}
	else if(g_authClient[client][Spt])
	{
		Format(newName, 64, "[捐助] %s", newName);
	}

	if (!StrEqual(oldName, newName))
		SetClientName(client, newName);
}