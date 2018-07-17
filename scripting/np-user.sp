#pragma semicolon 1

#include <NewPage>
#include <NewPage/user>
#include <smjansson>
#include <sdktools_functions>

#define P_NAME P_PRE ... " - User Manager"
#define P_DESC "User Manager"

public Plugin myinfo = 
{
	name        = P_NAME,
	author      = P_AUTHOR,
	description = P_DESC,
	version     = P_VERSION,
	url         = P_URLS
};

int  g_iUserId[MAXPLAYERS+1];
int g_ivipLevel[MAXPLAYERS+1];
int g_iUserGroupId[MAXPLAYERS+1];
bool g_authClient[MAXPLAYERS+1][Authentication];
bool g_bAuthLoaded[MAXPLAYERS+1];
bool g_bBanChecked[MAXPLAYERS+1];
char g_szUsername[MAXPLAYERS+1][32];
char g_szUserTag[MAXPLAYERS+1][16];

Handle g_hOnUMDataChecked;

ArrayList g_aGroupName;

// Stats

int g_iToday;
int g_iTrackingId[MAXPLAYERS+1];
int g_StatsClient[MAXPLAYERS+1][2][Stats];
int g_iConnectTimes[MAXPLAYERS+1];
int g_iClientVitality[MAXPLAYERS+1];

Handle g_TimerClient[MAXPLAYERS+1];

// Modules
#include "user/vip"
#include "user/stats"

// ---------- API ------------
public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	// Group
	CreateNative("NP_Group_GetUserGId", Native_GetUserGId);
	CreateNative("NP_Group_IsGIdValid", Native_IsGIdValid);

	// Auth
	CreateNative("NP_Users_IsAuthorized", Native_IsAuthorized);
	
	// Identity
	CreateNative("NP_Users_UserIdentity", Native_UserIdentity);

	// Vip
	CreateNative("NP_Vip_IsVIP", Native_IsVIP);
	CreateNative("NP_Vip_VIPLevel", Native_VIPLevel);
	CreateNative("NP_Vip_GrantVip", Native_GrantVip);
	CreateNative("NP_Vip_DeleteVip", Native_DeleteVip);
	CreateNative("NP_Vip_AddVipPoint", Native_AddVipPoint);

	// Stats
	CreateNative("NP_Stats_TodayOnlineTime",   Native_TodayOnlineTime);
	CreateNative("NP_Stats_TotalOnlineTime",   Native_TotalOnlineTime);
	CreateNative("NP_Stats_ObserveOnlineTime", Native_ObserveOnlineTime);
	CreateNative("NP_Stats_PlayOnlineTime",    Native_PlayOnlineTime);
	CreateNative("NP_Stats_Vitality",          Native_Vitality);

	// Tag
	CreateNative("NP_Users_SetTag", Native_SetTag);
	
	// lib
	RegPluginLibrary("np-user");

	return APLRes_Success;
}

public int Native_SetTag(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	GetNativeString(2, g_szUserTag[client], 16);
	ChangePlayerPreName(client);
}

// Group
public int Native_GetUserGId(Handle plugin, int numParams)
{
	return g_iUserGroupId[GetNativeCell(1)];
}

public int Native_IsGIdValid(Handle plugin, int numParams)
{
	return (GetNativeCell(1) != -1) ? 1 : 0;
}

// Auth
public int Native_IsAuthorized(Handle plugin, int numParams)
{
	return g_authClient[GetNativeCell(1)][GetNativeCell(2)];
}

// Identity
public int Native_UserIdentity(Handle plugin, int numParams)
{
	return g_iUserId[GetNativeCell(1)];
}

// ---------- API ------------ end

public void OnPluginStart()
{
	// console command
	AddCommandListener(Command_Who, "sm_who");

	// global forwards
	g_hOnUMDataChecked = CreateGlobalForward("OnClientDataChecked", ET_Ignore, Param_Cell, Param_Cell);

	// init console
	g_iUserId[0] = 0;
	g_szUsername[0] = "CONSOLE";

	// stats
	// init
	g_iToday = GetDay();
	
	// global timer
	CreateTimer(1.0, Timer_Global, _, TIMER_REPEAT);

	g_aGroupName = CreateArray(32, 50);
}

// get group name
public void NP_Core_OnInitialized(int serverId, int modId)
{
	if(!NP_MySQL_IsConnected())
	{
		NP_Core_LogError("User", "CheckGroupName", "Mysql is not ready!");
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
		NP_Core_LogError("Mysql", "CheckGroupName", "Query Server Info: %s", error);
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

// ------------command------------

public Action Command_Who(int client, const char[] command, int argc)
{
	if(!IsValidClient(client))
		return Plugin_Handled;

	static int _iLastUse[MAXPLAYERS+1] = {0, ...};
	
	if(_iLastUse[client] > GetTime() - 5)
		return Plugin_Handled;
	
	_iLastUse[client] = GetTime();

	// dont print all in one time. if players > 48 will not working.
	CreateTimer(0.3, Timer_PrintConsole, client, TIMER_REPEAT);
	
	return Plugin_Handled;
}

// ------------command------------ end

// ------------ native forward ------------
public void OnClientConnected(int client)
{
	for(int i = 0; i < view_as<int>(Authentication); ++i)
		g_authClient[client][i] = false;

	g_bAuthLoaded[client] = false;
	g_bBanChecked[client] = false;
	g_szUsername[client][0] = '\0';

	// Tag
	g_szUserTag[client][0] = '\0';
	
	g_iUserId[client] = 0;

	// Stats
	StartStats(client);
}

public void OnClientDisconnect(int client)
{
	// Stats
	EndStats(client);
}

// we call this forward after client is fully in-game.
// this forward -> tell other plugins, we are available, allow to load client`s data.
public void OnClientPutInServer(int client)
{
	if(IsFakeClient(client) || IsClientSourceTV(client))
	{
		CallDataForward(client);
		return;
	}

	if(!g_bAuthLoaded[client] || g_iUserId[client] <= 0)
	{
		CreateTimer(1.0, Timer_Waiting, client, TIMER_FLAG_NO_MAPCHANGE);
		return;
	}

	CallDataForward(client);
}

public void OnRebuildAdminCache(AdminCachePart part)
{
	if(part == AdminCache_Admins)
		for(int client = 1; client <= MaxClients; ++client)
			if(IsClientAuthorized(client))
				OnClientAuthorized(client, "");
}

public void OnClientAuthorized(int client, const char[] auth)
{
	if(strcmp(auth, "BOT") == 0 || IsFakeClient(client) || IsClientSourceTV(client))
		return;

	char steamid[32];
	if(!GetClientAuthId(client, AuthId_SteamID64, steamid, 32, true))
	{
		NP_Core_LogMessage("User", "OnClientAuthorized", "Error: We can not verify client`s SteamId64 -> \"%L\"", client);
		CreateTimer(0.1, Timer_ReAuthorize, client, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
		return;
	}

	CheckClient(client, steamid);
}

// ------------ native forward ------------ end

// ---------- functions ------------
void CheckClient(int client, const char[] steamid)
{
	if(g_bAuthLoaded[client])
		return; 

	if(!NP_Socket_IsReady())
	{
		NP_Core_LogError("User", "LoadClientAuth", "Error: Socket is unavailable -> \"%L\"", client);
		CreateTimer(5.0, Timer_ReAuthorize, client, TIMER_FLAG_NO_MAPCHANGE);
		return;
	}

	char ip[32];
	GetClientIP(client, ip, 32);
	
	char map[128];
	GetCurrentMap(map, 128);

	char m_szQuery[256];
	FormatEx(m_szQuery, 256, "{\"Event\":\"PlayerConnection\",\"PlayerConnection\":{\"SteamID\":\"%s\",\"CIndex\":%d,\"IP\":\"%s\",\"JoinTime\":%d,\"TodayDate\":%i,\"Map\":\"%s\",\"ServerID\":%d,\"ServerModID\":%d}}", steamid, client, ip, GetTime(), g_iToday, map, NP_Core_GetServerId(), NP_Core_GetServerModId());
	NP_Socket_Write(m_szQuery);
	//防止因为网络波动而无法加载用户数据
	CreateTimer(5.0, Timer_CheckClient, client, TIMER_FLAG_NO_MAPCHANGE);
}


void CheckClientCallback(const char[] data)
{
	Handle json = json_load(data);

	int client = json_object_get_int(json, "CIndex");

	if(!client)
	{
		CloseHandle(json);
		return;
	}

	//Verification is whether player information matches
	char d_steamid[32], t_steamid[32];
	json_object_get_string(json, "SteamID", d_steamid, 32);
	GetClientAuthId(client, AuthId_SteamID64, t_steamid, 32, true);

	//Drop the data
	if(strcmp(d_steamid, t_steamid) != 0)
	{
		CloseHandle(json);
		return;
	}

	Handle playerinfo = json_object_get(json, "PlayerInfo");

	if(playerinfo == INVALID_HANDLE)
	{
		CloseHandle(json);
		CloseHandle(playerinfo);
		return;
	}
	
	g_bAuthLoaded[client] = true;

	g_iUserId[client] = json_object_get_int(playerinfo, "UID");
	g_authClient[client][Spt] = json_object_get_bool(playerinfo, "Spt");
	g_authClient[client][Vip] = json_object_get_bool(playerinfo, "Vip");
	g_authClient[client][Ctb] = json_object_get_bool(playerinfo, "Ctb");
	g_authClient[client][Opt] = json_object_get_bool(playerinfo, "Opt");
	g_authClient[client][Adm] = json_object_get_bool(playerinfo, "Adm");
	g_authClient[client][Own] = json_object_get_bool(playerinfo, "Own");
	g_ivipLevel[client] = json_object_get_int(playerinfo, "Tviplevel");
	g_iUserGroupId[client] = json_object_get_int(playerinfo, "Grp");

	g_StatsClient[client][STATS_TOTAL][iTotalOnlineTime]   = json_object_get_int(playerinfo, "OnlineTotal");
	g_StatsClient[client][STATS_TOTAL][iTodayOnlineTime]   = json_object_get_int(playerinfo, "OnlineToday");
	g_StatsClient[client][STATS_TOTAL][iObserveOnlineTime] = json_object_get_int(playerinfo, "OnlineOB");
	g_StatsClient[client][STATS_TOTAL][iPlayOnlineTime]    = json_object_get_int(playerinfo, "OnlinePlay");

	g_iConnectTimes[client]   = json_object_get_int(playerinfo, "ConnectTimes")+1;
	g_iClientVitality[client] = json_object_get_int(playerinfo, "Vitality");

	g_iTrackingId[client] = json_object_get_int(playerinfo, "TrackingID");

	CloseHandle(json);
	CloseHandle(playerinfo);

	GetClientName(client, g_szUsername[client], 32);
	ChangePlayerPreName(client);
}

void CallDataForward(int client)
{
	Call_StartForward(g_hOnUMDataChecked);
	Call_PushCell(client);
	Call_PushCell(g_iUserId[client]);
	Call_Finish();
}

void ChangePlayerPreName(int client)
{
	char newName[64];

	strcopy(newName, 64, g_szUsername[client]);

	// Tag
	if(g_szUserTag[client][0] == '\0')
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

	if (!StrEqual(g_szUsername[client], newName))
		SetClientName(client, newName);
}

// ---------- functions ------------ end


// ---------- timer ------------

public Action Timer_CheckGroupName(Handle timer)
{
	NP_Core_OnInitialized(0, 0);
	return Plugin_Stop;
}

public Action Timer_CheckClient(Handle timer, int client)
{
	if(!IsClientInGame(client))
		return Plugin_Stop;

	if(!g_bAuthLoaded[client] || g_iUserId[client] <= 0)
		OnClientAuthorized(client, "");

	return Plugin_Stop;
}

public Action Timer_Waiting(Handle timer, int client)
{
	if(!IsClientInGame(client))
		return Plugin_Stop;
	
	OnClientPutInServer(client);

	return Plugin_Stop;
}

public Action Timer_PrintConsole(Handle timer, int client)
{
	static int _iCurrentIndex[MAXPLAYERS+1] = {0, ...};
	
	if(!IsClientInGame(client))
	{
		_iCurrentIndex[client] = 0;
		return Plugin_Stop;
	}

	int left = 16; // we loop 16 clients one time.
	while(left--)
	{
		if(_iCurrentIndex[client] == 0)
			PrintToConsole(client, "#slot    userid      name      Supporter    Vip    Contributor    Operator    Administrator    Owner");

		int index = ++_iCurrentIndex[client];
		
		if(index >= MaxClients)
		{
			_iCurrentIndex[client] = 0;
			return Plugin_Stop;
		}

		if(!IsValidClient(index))
			continue;
		
		char strSlot[8], strUser[8];
		StringPad(index, 4, ' ', strSlot, 8);
		StringPad(GetClientUserId(index), 6, ' ', strUser, 8);
		PrintToConsole(client, "#%s    %s    %N    %s    %s    %s    %s    %s    %s", strSlot, strUser, index, g_authClient[index][0], g_authClient[index][1], g_authClient[index][2], g_authClient[index][3], g_authClient[index][4], g_authClient[index][5]);
	}

	return Plugin_Continue;
}

public Action Timer_ReAuthorize(Handle timer, int client)
{
	if(!IsClientConnected(client))
		return Plugin_Stop;

	char steamid[32];
	if(!GetClientAuthId(client, AuthId_SteamID64, steamid, 32, true))
	{
		NP_Core_LogMessage("User", "OnClientAuthorized", "Error: We can not verify client`s SteamId64 -> \"%L\"", client);
		return Plugin_Continue;
	}

	CheckClient(client, steamid);
	
	return Plugin_Stop;
}

public Action Timer_Global(Handle timer)
{
	int today = GetDay();

	if(today != g_iToday)
	{
		g_iToday = today;
		
		for(int client = 1; client <= MaxClients; ++client)
		{
			g_StatsClient[client][STATS_SESSION][iTodayOnlineTime] = 0;
			g_StatsClient[client][STATS_TOTAL][iTodayOnlineTime]   = 0;
		}
	}
	
	return Plugin_Continue;
}

// ---------- timer ------------ end

// ---------- socket ------------ start

public void NP_Socket_OnReceived(const char[] event, const char[] data, const int size)
{
	if(!strcmp(event, "PlayerInfo"))
		CheckClientCallback(data);
}

// ---------- socket ------------ end