#pragma semicolon 1

#include <NewPage>
#include <smjansson>
#include <NewPage/allchat>

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

	char name[32], Token[33];
	switch(GetNativeCell(1))
	{
		case PlayerChat: GetNativeString(2, name, 32);
		case Announcement: strcopy(name, 32, "[公告]");
		case Custom: GetNativeString(2, name, 32);
	}

	StringToJson(name, 32);
	StringToJson(msg, inLen+1);

	GetToken(Token, 33);

	System2HTTPRequest httpRequest = new System2HTTPRequest(AllChatRequestCallback, "%s/allchat.php", P_APIURL);
	httpRequest.Timeout = 30;
	httpRequest.SetHeader("Content-Type", "application/json");
	httpRequest.SetData("{\"ServerID\":%d,\"ServerModID\":%d,\"Token\":\"%s\",\"Event\":\"AllServersChat\",\"AllServersChat\":{\"Name\":\"%s\",\"Msg\":\"%s\",\"Type\":%d}}", NP_Core_GetServerId(), NP_Core_GetServerModId(), Token, name, msg, GetNativeCell(1));
	httpRequest.SetPort(P_APIPORT);
	httpRequest.POST();

	char buff[512];
	httpRequest.GetData(buff, 512);
	
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
	char url[256];
	request.GetURL(url, sizeof(url));

	if (!success)
	{
		NP_Core_LogError("AllChat", "AllChatRequestCallback", "ERROR: Couldn't retrieve URL %s - %d. Error: %s", url, method, error);
		CreateTimer(5.0, Timer_RetryRequest, request);
		return;
	}
	
	char[] content = new char[response.ContentLength + 1];
	response.GetContent(content, response.ContentLength + 1);

	char source[512];
	request.GetData(source, 512);

	if (StringToInt(content) == -1)
	{
		NP_Core_LogError("AllChat", "AllChatRequestCallback", "ERROR: Couldn't sent data -> %s", source);
		delete request;
		return;
	}

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

public Action Timer_RetryRequest(Handle timer, System2HTTPRequest request)
{
	request.POST();
	return Plugin_Stop;
}