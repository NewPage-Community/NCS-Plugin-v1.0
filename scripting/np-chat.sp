#pragma semicolon 1

#include <NewPage>

#define P_NAME P_PRE ... " - Chat processor"
#define P_DESC "Chat processor plugin"

char g_cClientNameColor[MAXPLAYERS + 1][16];

bool g_Proto;
bool g_NewMSG[MAXPLAYERS + 1];

EngineVersion engine;

public Plugin myinfo = 
{
	name        = P_NAME,
	author      = P_AUTHOR,
	description = P_DESC,
	version     = P_VERSION,
	url         = P_URLS
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	CreateNative("NP_AllChat_Msg", Native_SendMsg);
	CreateNative("NP_Chat_SetNameColor", Native_SetNameColor);

	engine = GetEngineVersion();

	// lib
	RegPluginLibrary("np-chat");

	return APLRes_Success;
}

public int Native_SendMsg(Handle plugin, int numParams)
{
	// dynamic length
	int inLen = 0;
	GetNativeStringLength(3, inLen);
	char[] msg = new char[inLen+1];
	if (GetNativeString(3, msg, inLen+1) != SP_ERROR_NONE)
		return 0;

	char name[MAXLENGTH_NAME];
	switch (GetNativeCell(1))
	{
		case PlayerChat: GetNativeString(2, name, MAXLENGTH_NAME);
		case Announcement: strcopy(name, MAXLENGTH_NAME, "[公告]");
		case Custom: GetNativeString(2, name, MAXLENGTH_NAME);
	}

	StringToJson(name, MAXLENGTH_NAME);
	StringToJson(msg, inLen+1);

	CreateRequest(AllChatRequestCallback, "allchat.php", "\"ServerModID\":%d,\"Event\":\"AllServersChat\",\"AllServersChat\":{\"Name\":\"%s\",\"Msg\":\"%s\",\"Type\":%d}", NP_Core_GetServerModId(), name, msg, GetNativeCell(1));
	
	return 1;
}

public int Native_SetNameColor(Handle plugin, int numParams)
{
	char color[16], m_szQuery[256];
	int client = GetNativeCell(1);
	GetNativeString(2, color, 16);
	strcopy(g_cClientNameColor[client], 16, color);
	FormatEx(m_szQuery, 256, "UPDATE %s_users SET namecolor = '%s' WHERE uid = %d", P_SQLPRE, color, NP_Users_UserIdentity(client));
	NP_MySQL_SaveDatabase(m_szQuery);
}

public void OnPluginStart()
{
	RegConsoleCmd("sm_achat", Command_AllChat);
}

public void OnConfigsExecuted()
{
	g_Proto = CanTestFeatures() && GetFeatureStatus(FeatureType_Native, "GetUserMessageType") == FeatureStatus_Available && GetUserMessageType() == UM_Protobuf;

	UserMsg SayText2 = GetUserMessageId("SayText2");

	if (SayText2 != INVALID_MESSAGE_ID)
	{
		HookUserMessage(SayText2, OnSayText2, true);
		//LogMessage("Successfully hooked a SayText2 chat hook.");
	}
	else
		SetFailState("Error loading the plugin, SayText2 is unavailable.");
}

public void OnClientConnected(int client)
{
	g_cClientNameColor[client][0] = '\0';
}

//This function is based on chat-processor by Keith Warren 
public Action OnSayText2(UserMsg msg_id, BfRead msg, const int[] players, int playersNum, bool reliable, bool init)
{
	char game[32];
	GetGameFolderName(game, 32);

	//Retrieve the client sending the message to other clients.
	int iSender = g_Proto ? PbReadInt(msg, "ent_idx") : BfReadByte(msg);

	if (iSender <= 0)
		return Plugin_Continue;

	//Stops double messages in-general.
	if (g_NewMSG[iSender])
		g_NewMSG[iSender] = false;
	else if (reliable)	//Fix for other plugins that use SayText2 I guess?
		return Plugin_Stop;

	//Chat Type
	bool bChat = g_Proto ? PbReadBool(msg, "chat") : view_as<bool>(BfReadByte(msg));

	//Retrieve the name of template name to use when getting the format.
	char sFlag[MAXLENGTH_FLAG];
	switch (g_Proto)
	{
		case true: PbReadString(msg, "msg_name", sFlag, sizeof(sFlag));
		case false: BfReadString(msg, sFlag, sizeof(sFlag));
	}

	//Get the name string of the client.
	char sName[MAXLENGTH_NAME];
	switch (g_Proto)
	{
		case true: PbReadString(msg, "params", sName, sizeof(sName), 0);
		case false: if (BfGetNumBytesLeft(msg)) BfReadString(msg, sName, sizeof(sName));
	}

	//Get the message string that the client is wanting to send.
	char sMessage[MAXLENGTH_MESSAGE];
	switch (g_Proto)
	{
		case true: PbReadString(msg, "params", sMessage, sizeof(sMessage), 1);
		case false: if (BfGetNumBytesLeft(msg)) BfReadString(msg, sMessage, sizeof(sMessage));
	}

	//Get tag name.
	ProcessChatName(iSender, sName, MAXLENGTH_NAME);

	//Process colors.
	ProcessColorString(sName, MAXLENGTH_NAME);

	DataPack hPack = new DataPack();
	hPack.WriteCell(iSender);
	hPack.WriteString(sName);
	hPack.WriteString(sMessage);
	hPack.WriteString(sFlag);
	hPack.WriteCell(bChat);

	RequestFrame(Frame_OnChatMessage_SayText2, hPack);

	return Plugin_Stop;
}

public void Frame_OnChatMessage_SayText2(DataPack data)
{
	//Retrieve pack contents and what not, this part is obvious.
	data.Reset();

	int iSender = data.ReadCell();

	char sName[MAXLENGTH_NAME];
	data.ReadString(sName, sizeof(sName));

	char sMessage[MAXLENGTH_MESSAGE];
	data.ReadString(sMessage, sizeof(sMessage));

	char sFlag[MAXLENGTH_FLAG];
	data.ReadString(sFlag, sizeof(sFlag));

	bool bChat = data.ReadCell();

	delete data;

	int team = GetClientTeam(iSender);
	bool alive = IsPlayerAlive(iSender);

	char sBuffer[MAXLENGTH_BUFFER];
	Format(sBuffer, MAXLENGTH_BUFFER, "\x05%s\x01 : %s", sName, sMessage);

	if (team == 1)
		Format(sBuffer, MAXLENGTH_BUFFER, "\x05*观察*\x01 %s", sBuffer);
	else if (!alive)
		Format(sBuffer, MAXLENGTH_BUFFER, "\x05*死亡*\x01 %s", sBuffer);

	//CSGO quirk where the 1st color in the line won't work..
	if (engine == Engine_CSGO)
		Format(sBuffer, MAXLENGTH_BUFFER, " %s", sBuffer);

	//Send the message to clients.
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			if (StrContains(sFlag, "_All") == -1 && team != GetClientTeam(i))
				continue;

			if (!FindConVar("sv_deadtalk").BoolValue && IsPlayerAlive(i) && !IsPlayerAlive(iSender))
				continue;

			if (g_Proto)
				CSayText2(i, sBuffer, iSender, bChat);
			else
				SendPlayerMessage(i, sBuffer, iSender);
		}
	}
}

public Action OnClientSayCommand(int client, const char[] command, const char[] sArgs)
{
	if (client > 0 && StrContains(command, "say") != -1)
		g_NewMSG[client] = true;
}

public Action Command_AllChat(int client, int argc)
{
	if (!IsValidClient(client))
		return Plugin_Handled;

	char szChat[MAXLENGTH_MESSAGE];
	if (GetCmdArgString(szChat, MAXLENGTH_MESSAGE) <= 0)
	{
		PrintToChat(client, " \x04[提示] \x01聊天内容不能为空");
		return Plugin_Handled;
	}

	char name[MAXLENGTH_NAME];
	ProcessChatName(client, name, MAXLENGTH_NAME);

	StringToJson(name, MAXLENGTH_NAME);
	StringToJson(szChat, MAXLENGTH_MESSAGE);

	NP_AllChat_Msg(PlayerChat, name, szChat);

	return Plugin_Handled;
}

void AllChatRequestCallback(bool success, const char[] error, System2HTTPRequest request, System2HTTPResponse response, HTTPRequestMethod method)
{
	if (!CheckRequest(success, error, request, response, method, "AllChat", "AllChatRequestCallback"))
		return;

	delete request;
}

public void NP_Core_RconData(const char[] data, const char[] event)
{
	if (!strcmp(event, "AllServersChat"))
		AllChatProcess(data);
}

void AllChatProcess(const char[] data)
{
	Handle json, msgdata;

	if ((json = json_load(data)) == INVALID_HANDLE)
	{
		NP_Core_LogError("AllChat", "AllChatProcess", "Error: Json -> %s", data);
		return;
	}

	char name[MAXLENGTH_NAME], msg[MAXLENGTH_MESSAGE];

	if ((msgdata = json_object_get(json, "AllServersChat")) == INVALID_HANDLE)
	{
		NP_Core_LogError("AllChat", "AllChatProcess", "Can't find AllServersChat object -> %s", data);
		CloseHandle(json);
		return;
	}
		
	int serModID = json_object_get_int(json, "ServerModID");

	//不需要不同游戏聊天
	if (serModID != NP_Core_GetServerModId())
	{
		CloseHandle(json);
		return;
	}

	json_object_get_string(msgdata, "Name", name, MAXLENGTH_NAME);
	json_object_get_string(msgdata, "Msg", msg, MAXLENGTH_MESSAGE);

	ProcessColorString(name, MAXLENGTH_NAME);
	ProcessColorString(msg, MAXLENGTH_MESSAGE);
	
	if (view_as<ChatType>(json_object_get_int(msgdata, "Type")) == PlayerChat)
		PrintToChatAll("\x04[全服聊天] \x05%s\x01 : %s", name, msg);
	else
		PrintToChatAll("\x04[%s] \x01%s", name, msg);

	CloseHandle(json);
}

void ProcessChatName(int client, char[] name, int size)
{
	if (!IsValidClient(client))
		return;

	char tagName[32], grpName[32];

	NP_Users_GetName(client, name, size);

	if (g_cClientNameColor[client][0] != '\0')
		Format(name, size, "%s%s", g_cClientNameColor[client], name);

	if (NP_Users_GetTag(client, tagName, 32))
	{
		Format(name, size, "{lime}[%s]{name} %s", tagName, name);
	}

	if (NP_Group_GetGrpName(client, grpName, 32))
	{
		Format(name, size, "{purple}<%s>{name} %s", grpName, name);
	}
	else if (NP_Users_IsAuthorized(client, Authentication:Own))
	{
		Format(name, size, "{red}<服主>{name} %s" , name);
	}
	else if (NP_Users_IsAuthorized(client, Authentication:Adm))
	{
		Format(name, size, "{green}<ADMIN>{name} %s" , name);
	}
	else if (NP_Users_IsAuthorized(client, Authentication:Opt))
	{
		Format(name, size, "{green}<管理>{name} %s" , name);
	}
	else if (NP_Users_IsAuthorized(client, Authentication:Ctb))
	{
		Format(name, size, "{green}<员工>{name} %s" , name);
	}
	else if (NP_Users_IsAuthorized(client, Authentication:Vip))
	{
		Format(name, size, "{yellow}<会员>{name} %s" , name);
	}
	else if (NP_Users_IsAuthorized(client, Authentication:Spt))
	{
		Format(name, size, "{pink}<捐助>{name} %s" , name);
	}
}