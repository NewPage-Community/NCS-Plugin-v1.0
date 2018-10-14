#pragma semicolon 1

#include <NewPage>

#define P_NAME P_PRE ... " - All Servers Chat"
#define P_DESC "All Servers Chat plugin"

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

public void OnPluginStart()
{
	RegConsoleCmd("sm_achat", Command_AllChat);
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
		PrintToChatAll("\x04[全服聊天] \x05%s :  \x01%s", name, msg);
	else
		PrintToChatAll("\x04[%s] \x01%s", name, msg);

	CloseHandle(json);
}

public Action CP_OnChatMessage(int& author, ArrayList recipients, char[] flagstring, char[] name, char[] message, bool& processcolors, bool& removecolors)
{
	ProcessChatName(author, name, MAXLENGTH_NAME);
	ProcessColorString(name, MAXLENGTH_NAME);

	return Plugin_Changed;
}

void ProcessChatName(int client, char[] name, int size)
{
	char tagName[32], grpName[32];
	NP_Users_GetName(client, name, size);

	if (NP_Users_GetTag(client, tagName, 32))
	{
		Format(name, size, "{lime}[%s]{default} %s", tagName, name);
	}

	if (NP_Group_GetGrpName(client, grpName, 32))
	{
		Format(name, size, "{purple}<%s>{default} %s", grpName, name);
	}
	else if (NP_Users_IsAuthorized(client, Authentication:Own))
	{
		Format(name, size, "{red}<服主>{default} %s" , name);
	}
	else if (NP_Users_IsAuthorized(client, Authentication:Adm))
	{
		Format(name, size, "{green}<ADMIN>{default} %s" , name);
	}
	else if (NP_Users_IsAuthorized(client, Authentication:Opt))
	{
		Format(name, size, "{green}<管理>{default} %s" , name);
	}
	else if (NP_Users_IsAuthorized(client, Authentication:Ctb))
	{
		Format(name, size, "{green}<员工>{default} %s" , name);
	}
	else if (NP_Users_IsAuthorized(client, Authentication:Vip))
	{
		Format(name, size, "{yellow}<会员>{default} %s" , name);
	}
	else if (NP_Users_IsAuthorized(client, Authentication:Spt))
	{
		Format(name, size, "{pink}<捐助>{default} %s" , name);
	}
}