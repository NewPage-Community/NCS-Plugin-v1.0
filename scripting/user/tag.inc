public int Native_SetTag(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	GetNativeString(2, g_aClient[client][Tag], 16);
	ChangePlayerPreName(client);
}

void ChangePlayerPreName(int client)
{
	char newName[64], oldName[64];

	GetClientName(client, oldName, 64);

	// get player name if it invalid
	if(g_aClient[client][Name][0] == '\0')
		GetClientName(client, g_aClient[client][Name], 32);
		
	strcopy(newName, 64, g_aClient[client][Name]);

	// Tag
	if(g_aClient[client][Tag][0] != '\0')
		Format(newName, 64, "[%s] %s", g_aClient[client][Tag], newName);

	if(g_aClient[client][GID] != -1)
	{
		char groupName[32];
		g_aGroupName.GetString(g_aClient[client][GID], groupName, 32);
		Format(newName, 64, "[%s] %s", groupName, newName);
	}
	else if(g_aClient[client][Auth][Own])
	{
		Format(newName, 64, "[服主] %s", newName);
	}
	else if(g_aClient[client][Auth][Adm])
	{
		Format(newName, 64, "[ADMIN] %s", newName);
	}
	else if(g_aClient[client][Auth][Opt])
	{
		Format(newName, 64, "[管理] %s", newName);
	}
	else if(g_aClient[client][Auth][Ctb])
	{
		Format(newName, 64, "[员工] %s", newName);
	}
	else if(g_aClient[client][Auth][Vip])
	{
		Format(newName, 64, "[会员] %s", newName);
	}
	else if(g_aClient[client][Auth][Spt])
	{
		Format(newName, 64, "[捐助] %s", newName);
	}

	if (!StrEqual(oldName, newName))
		SetClientName(client, newName);
}