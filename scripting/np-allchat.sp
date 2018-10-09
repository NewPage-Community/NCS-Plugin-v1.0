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
	if(GetNativeString(3, msg, inLen+1) != SP_ERROR_NONE)
		return 0;

	char name[32];
	switch(GetNativeCell(1))
	{
		case PlayerChat: GetNativeString(2, name, 32);
		case Announcement: strcopy(name, 32, "[公告]");
		case Custom: GetNativeString(2, name, 32);
	}

	StringToJson(name, 32);
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
	if(!IsValidClient(client))
		return Plugin_Handled;

	char szChat[256];
	if(GetCmdArgString(szChat, 256) <= 0)
	{
		PrintToChat(client, " \x04[提示] \x01聊天内容不能为空");
		return Plugin_Handled;
	}

	char playerName[32];
	GetClientName(client, playerName, 32);

	StringToJson(playerName, 32);
	StringToJson(szChat, 32);

	NP_AllChat_Msg(PlayerChat, playerName, szChat);

	return Plugin_Handled;
}

void AllChatRequestCallback(bool success, const char[] error, System2HTTPRequest request, System2HTTPResponse response, HTTPRequestMethod method)
{
	if(!CheckRequest(success, error, request, response, method, "AllChat", "AllChatRequestCallback"))
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

	char name[32], msg[256];

	if((msgdata = json_object_get(json, "AllServersChat")) == INVALID_HANDLE)
	{
		NP_Core_LogError("AllChat", "AllChatProcess", "Can't find AllServersChat object -> %s", data);
		CloseHandle(json);
		return;
	}
		
	int serModID = json_object_get_int(json, "ServerModID");

	//不需要不同游戏聊天
	if(serModID != NP_Core_GetServerModId())
	{
		CloseHandle(json);
		return;
	}

	json_object_get_string(msgdata, "Name", name, 32);
	json_object_get_string(msgdata, "Msg", msg, 256);
	
	if(view_as<ChatType>(json_object_get_int(msgdata, "Type")) == PlayerChat)
		PrintToChatAll("\x04[全服聊天] \x05%s :  \x01%s", name, msg);
	else
		PrintToChatAll("\x04[%s] \x01%s", name, msg);

	CloseHandle(json);
}