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
	GetNativeStringLength(1, inLen);
	char[] input = new char[inLen+1];
	if(GetNativeString(1, input, inLen+1) != SP_ERROR_NONE)
		return 0;

	char buff[512];
	Format(buff, 512, "{\"Event\":\"AllServersChat\",\"AllServersChat\":{\"ServerID\":%d,\"PlayerName\":\"###MSG###\",\"Msg\":\"%s\"}}", NP_Core_GetServerId(), input);

	return (NP_Socket_Write(buff)) ? 1 : 0;
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

	char buff[512], m_szUsername[32];
	GetClientName(client, m_szUsername, 32);
	Format(buff, 512, "{\"Event\":\"AllServersChat\",\"AllServersChat\":{\"ServerID\":%d,\"ServerModID\":%d,\"PlayerName\":\"%s\",\"Msg\":\"%s\"}}", NP_Core_GetServerId(), NP_Core_GetServerModId(), m_szUsername, szChat);
	Handle json = json_load(buff);
	json_dump(json, buff, 512);

	if(!NP_Socket_Write(buff))
		NP_Core_LogError("AllChat", "Command_AllChat", "Socket write failed -> %s", buff);

	return Plugin_Handled;
}

public void NP_Socket_OnReceived(const char[] event, const char[] data, const int size)
{
	if(!strcmp(event, "AllServersChat"))
		AllChatProcess(data);
}

void AllChatProcess(const char[] data)
{
	Handle json = json_load(data);
	Handle msgdata;
	char playername[32], msg[256];

	if((msgdata = json_object_get(json, "AllServersChat")) == INVALID_HANDLE)
	{
		NP_Core_LogError("AllChat", "NP_Socket_OnReceived", "Can't find AllServersChat object -> %s", data);
		CloseHandle(json);
		return;
	}
		
	//int serID = json_object_get_int(msgdata, "ServerID");
	int serModID = json_object_get_int(msgdata, "ServerModID");

	//不需要不同游戏聊天
	if(serModID != NP_Core_GetServerModId())
	{
		CloseHandle(json);
		return;
	}

	json_object_get_string(msgdata, "PlayerName", playername, 32);
	json_object_get_string(msgdata, "Msg", msg, 256);

	if(!strcmp(playername, "###MSG###"))
		PrintToChatAll("\x04[公告] \x01%s", msg);
	else
		PrintToChatAll("\x04[全服聊天] \x05%s :  \x01%s", playername, msg);

	CloseHandle(json);
}
