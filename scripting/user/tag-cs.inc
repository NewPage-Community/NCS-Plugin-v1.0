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

public int Native_SetCustomPrefix(Handle plugin, int numParams)
{
	char prefix[32];
	GetNativeString(2, prefix, 32);
	SetClientCustomPrefix(GetNativeCell(1), prefix);
}

public int Native_GetPrefix(Handle plugin, int numParams)
{
	char prefix[32];
	GetClientPrefix(GetNativeCell(1), prefix, 32, !GetNativeCell(4) ? false : true);
	SetNativeString(2, prefix, GetNativeCell(3), true);
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

	CreateTimer(5.0, Timer_ChangeClan, client);
	
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

	char prefix[32];
	GetClientPrefix(client, prefix, 32);
	CS_SetClientClanTag(client, prefix);

	return Plugin_Stop;
}

bool SetClientPrefixPrefer(int client, int type)
{
	char m_szQuery[256];
	FormatEx(m_szQuery, 256, "UPDATE %s_users SET prefixprefer = %d WHERE uid = %d", P_SQLPRE, type, NP_Users_UserIdentity(client));
	
	if (NP_MySQL_SaveDatabase(m_szQuery))
	{
		g_aClient[client][PrefixPrefer] = type;
		ChangePlayerPreName(client);
		return true;
	}

	return false;
}

bool SetClientCustomPrefix(int client, char[] prefix)
{
	char m_szQuery[256], t_prefix[16];
	strcopy(t_prefix, 16, prefix);
	FormatEx(m_szQuery, 256, "UPDATE %s_users SET customperfix = '%s' WHERE uid = %d", P_SQLPRE, prefix, NP_Users_UserIdentity(client));
	
	if (NP_MySQL_SaveDatabase(m_szQuery))
	{
		strcopy(g_aClient[client][CustomPrefix], 16, t_prefix);
		ChangePlayerPreName(client);
		return true;
	}

	return false;
}

bool GetClientPrefix(int client, char[] prefix, int size, bool color = false)
{
	if (!NP_Users_IsAuthLoaded(client) || !IsClientConnected(client))
		return false;

	char groupName[32], authprefix[32];
	authprefix[0] = '\0';
	if(g_aClient[client][GID] != -1)
		g_aGroupName.GetString(g_aClient[client][GID], groupName, 32);
	GetClientAuthPrefix(client, authprefix, 32, color);

	switch(g_aClient[client][PrefixPrefer])
	{
		case 0: if(authprefix[0] != '\0') Format(prefix, size, "%s", authprefix);
		case 1: color ? Format(prefix, size, "{purple}<%s>", groupName) : Format(prefix, size, "<%s>", groupName);
		case 2: color ? Format(prefix, size, "{blue}<%s>", g_aClient[client][CustomPrefix]) : Format(prefix, size, "<%s>", g_aClient[client][CustomPrefix]);
		default: return true;
	}

	return true;
}

void GetClientAuthPrefix(int client, char[] prefix, int size, bool color = false)
{
	if (g_aClient[client][Auth][Own])
	{
		if (color)
			Format(prefix, size, "{red}<服主>");
		else
			Format(prefix, size, "<服主>");
	}
	else if (g_aClient[client][Auth][Adm])
	{
		if (color)
			Format(prefix, size, "{green}<ADMIN>");
		else
			Format(prefix, size, "<ADMIN>");
	}
	else if (g_aClient[client][Auth][Opt])
	{
		if (color)
			Format(prefix, size, "{green}<管理>");
		else
			Format(prefix, size, "<管理>");
	}
	else if (g_aClient[client][Auth][Ctb])
	{
		if (color)
			Format(prefix, size, "{green}<员工>");
		else
			Format(prefix, size, "<员工>");
	}
	else if (g_aClient[client][Auth][Vip])
	{
		if (color)
			Format(prefix, size, "{yellow}<会员>");
		else
			Format(prefix, size, "<会员>");
	}
	else if (g_aClient[client][Auth][Spt])
	{
		if (color)
			Format(prefix, size, "{pink}<捐助>");
		else
			Format(prefix, size, "<捐助>");
	}
}

public Action Command_Prefix(int client, int args)
{
	if (!IsValidClient(client))
		return Plugin_Handled;

	if (!NP_Users_IsAuthLoaded(client))
	{
		CPrintToChat(client, "\x04[系统提示]{blue} 你的账号信息仍未被加载！");
		return Plugin_Handled;
	}

	char groupName[32], authprefix[32];
	if(g_aClient[client][GID] != -1)
		g_aGroupName.GetString(g_aClient[client][GID], groupName, 32);
	GetClientAuthPrefix(client, authprefix, 32);

	Menu menu = new Menu(MenuHandler_Prefix);
	menu.SetTitle("请选择你显示的头衔");
	if (authprefix[0] != '\0')
		AddMenuItemEx(menu, 0, "0", "%s", authprefix);
	if(g_aClient[client][GID] != -1)
		AddMenuItemEx(menu, 0, "1", "<%s>", groupName);
	if (g_aClient[client][CustomPrefix][0] != '\0')
		AddMenuItemEx(menu, 0, "2", "<%s>", g_aClient[client][CustomPrefix]);
	AddMenuItemEx(menu, 0, "3", "不显示");
	menu.ExitButton = true;
	menu.Display(client, 0);
	return Plugin_Handled;
}

public int MenuHandler_Prefix(Menu menu, MenuAction action, int client, int slot)
{
	if (action == MenuAction_Cancel)
	{
		if(slot == MenuCancel_ExitBack)
			delete menu;
	}
	else if (action == MenuAction_Select)
	{
		char minfo[2];
		menu.GetItem(slot, minfo, 2, _, _, _);
		SetClientPrefixPrefer(client, StringToInt(minfo));
		ChangePlayerPreName(client);
	}
}