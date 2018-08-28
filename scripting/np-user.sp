#pragma semicolon 1

#include <NewPage>
#include <NewPage/user>
#include <NewPage/allchat>
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

int	g_iToday;

Handle g_hOnUMDataChecked,
	g_hOnClientSigned;

ArrayList g_aGroupName;

ConVar g_cSignMoney,
	g_cSignVIPMoney,
	g_cSignVIPPoint;

any g_aClient[MAXPLAYERS+1][client_Info];

// Modules
#include "user/vip"
#include "user/stats"
#include "user/admin"
#include "user/ban"
#include "user/tag"
#include "user/group"
#include "user/func"
#include "user/money"

// ---------- API ------------
public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	// Group
	CreateNative("NP_Group_GetUserGId", Native_GetUserGId);
	CreateNative("NP_Group_IsGIdValid", Native_IsGIdValid);
	CreateNative("NP_Group_GetUserGName", Native_GetUserGName);

	// Auth
	CreateNative("NP_Users_IsAuthorized", Native_IsAuthorized);
	CreateNative("NP_Users_IsAuthLoaded", Native_IsAuthLoaded);
	
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

	// Banning
	CreateNative("NP_Users_BanClient",    Native_BanClient);
	CreateNative("NP_Users_BanIdentity",  Native_BanIdentity);

	// Tag
	CreateNative("NP_Users_SetTag", Native_SetTag);

	// Money
	CreateNative("NP_Users_PayMoney", Native_PayMoney);
	CreateNative("NP_Users_GiveMoney", Native_GiveMoney);
	
	// lib
	RegPluginLibrary("np-user");

	return APLRes_Success;
}

// Auth
public int Native_IsAuthorized(Handle plugin, int numParams)
{
	return g_aClient[GetNativeCell(1)][Auth][GetNativeCell(2)];
}

public int Native_IsAuthLoaded(Handle plugin, int numParams)
{
	return g_aClient[GetNativeCell(1)][AuthLoaded];
}

// Identity
public int Native_UserIdentity(Handle plugin, int numParams)
{
	return g_aClient[GetNativeCell(1)][UID];
}

// ---------- API ------------ end

public void OnPluginStart()
{
	// console command
	RegConsoleCmd("sm_info", Command_UserInfo);
	RegConsoleCmd("sm_sign", Command_Sign);
	RegConsoleCmd("sm_qd", Command_Sign);
	RegAdminCmd("sm_ban", Command_Ban, ADMFLAG_BAN);

	// global forwards
	g_hOnUMDataChecked = CreateGlobalForward("NP_OnClientDataChecked", ET_Ignore, Param_Cell, Param_Cell);
	g_hOnClientSigned = CreateGlobalForward("NP_OnClientSigned",  ET_Ignore, Param_Cell, Param_Cell);

	// init console
	g_aClient[0][UID] = 0;
	strcopy(g_aClient[0][Name], 32, "SERVER");

	// stats
	// init
	g_iToday = GetDay();
	
	// global timer
	CreateTimer(1.0, Timer_Global, _, TIMER_REPEAT);

	g_aGroupName = CreateArray(32, 50);

	LoadTranslations("common.phrases.txt");

	HookEvent("round_start", EventRoundStart, EventHookMode_Post);

	g_cSignMoney = CreateConVar("np_user_sign_givemoney", "3000", "签到奖励软妹币", 0, true, 0.0);
	g_cSignVIPMoney = CreateConVar("np_user_sign_VIPgivemoney", "5000", "会员签到奖励软妹币", 0, true, 0.0);
	g_cSignVIPPoint = CreateConVar("np_user_sign_givevippoint", "10", "签到奖励会员经验", 0, true, 0.0);
}

// get group name
public void NP_Core_OnInitialized(int serverId, int modId)
{
	CheckGroup();
}

// ------------ native forward ------------

public Action EventRoundStart(Handle event, const char[] name, bool dontBroadcast)
{
	for (int client = 1; client <= MaxClients; client++)
		if (IsClientInGame(client))
			CreateTimer(1.0, SetTeams, client);
	return Plugin_Handled;
}

public void OnClientConnected(int client)
{
	for(int i = 0; i < view_as<int>(Authentication); ++i)
		g_aClient[client][Auth][i] = false;

	g_aClient[client][AuthLoaded] = false;
	g_aClient[client][Name][0] = '\0';
	g_aClient[client][GID] = -1;
	g_aClient[client][Money] = 0;

	// Tag
	g_aClient[client][Tag][0] = '\0';
	
	g_aClient[client][UID] = 0;

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

	if(!g_aClient[client][AuthLoaded] || g_aClient[client][UID] <= 0)
	{
		CreateTimer(1.0, Timer_Waiting, client, TIMER_FLAG_NO_MAPCHANGE);
		return;
	}

	CallDataForward(client);

	VIPConnected(client);
}

public void OnRebuildAdminCache(AdminCachePart part)
{
	if(part == AdminCache_Admins)
		for(int client = 1; client <= MaxClients; ++client)
			if(IsClientAuthorized(client))
			{
				SetClientName(client, g_aClient[client][Name]);
				OnClientAuthorized(client, "");
			}
}

public void OnClientAuthorized(int client, const char[] auth)
{
	if(strcmp(auth, "BOT") == 0 || IsFakeClient(client) || IsClientSourceTV(client))
		return;

	char steamid[32];
	if(!GetClientAuthId(client, AuthId_SteamID64, steamid, 32, true))
	{
		NP_Core_LogMessage("User", "OnClientAuthorized", "Error: Can not verify client`s SteamId64 -> \"%L\"", client);
		KickClient(client, "无效SteamID/Invalid Steam Id");
		return;
	}

	CheckClient(client, steamid);
}

// ------------ native forward ------------ end

// ---------- functions ------------
void CheckClient(int client, const char[] steamid)
{
	if(g_aClient[client][AuthLoaded])
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
	CreateTimer(10.0, Timer_CheckClient, client, TIMER_FLAG_NO_MAPCHANGE);
}


void CheckClientCallback(const char[] data)
{
	Handle json = json_load(data);

	if (json == INVALID_HANDLE)
	{
		NP_Core_LogError("User", "CheckClientCallback", "Error: Json -> \"%s\"", data);
		return;
	}

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
	
	g_aClient[client][AuthLoaded] = true;

	g_aClient[client][UID] = json_object_get_int(playerinfo, "UID");
	g_aClient[client][Auth][Spt] = json_object_get_bool(playerinfo, "Spt");
	g_aClient[client][Auth][Vip] = json_object_get_bool(playerinfo, "Vip");
	g_aClient[client][Auth][Ctb] = json_object_get_bool(playerinfo, "Ctb");
	g_aClient[client][Auth][Opt] = json_object_get_bool(playerinfo, "Opt");
	g_aClient[client][Auth][Adm] = json_object_get_bool(playerinfo, "Adm");
	g_aClient[client][Auth][Own] = json_object_get_bool(playerinfo, "Own");
	g_aClient[client][VipLevel] = json_object_get_int(playerinfo, "Tviplevel");
	g_aClient[client][GID] = json_object_get_int(playerinfo, "Grp");

	g_aClient[client][StatsTotal][iTotalOnlineTime]   = json_object_get_int(playerinfo, "OnlineTotal");
	g_aClient[client][StatsTotal][iTodayOnlineTime]   = json_object_get_int(playerinfo, "OnlineToday");
	g_aClient[client][StatsTotal][iObserveOnlineTime] = json_object_get_int(playerinfo, "OnlineOB");
	g_aClient[client][StatsTotal][iPlayOnlineTime]    = json_object_get_int(playerinfo, "OnlinePlay");

	g_aClient[client][ConnectTimes]   = json_object_get_int(playerinfo, "ConnectTimes")+1;
	g_aClient[client][Vitality] = json_object_get_int(playerinfo, "Vitality");

	g_aClient[client][StatsTrackingId] = json_object_get_int(playerinfo, "TrackingID");

	g_aClient[client][Money] = json_object_get_int(playerinfo, "Money");

	g_aClient[client][SignTimes] = json_object_get_int(playerinfo, "SignTimes");
	g_aClient[client][SignDate] = json_object_get_int(playerinfo, "SignDate");

	g_aClient[client][VIPPoint] = json_object_get_int(playerinfo, "VIPPoint");
	g_aClient[client][VIPExpired] = json_object_get_int(playerinfo, "VIPExpired");

	if(!CheckBan(client, playerinfo))
		return;

	CloseHandle(json);
	CloseHandle(playerinfo);

	LoadAdmin(client, t_steamid);

	GetClientName(client, g_aClient[client][Name], 32);
	ChangePlayerPreName(client);
}

void CallDataForward(int client)
{
	Call_StartForward(g_hOnUMDataChecked);
	Call_PushCell(client);
	Call_PushCell(g_aClient[client][UID]);
	Call_Finish();
}

// ---------- functions ------------ end


// ---------- timer ------------

public Action Timer_CheckClient(Handle timer, int client)
{
	if(!IsClientInGame(client))
		return Plugin_Stop;

	if(!g_aClient[client][AuthLoaded] || g_aClient[client][UID] <= 0)
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

public Action Timer_ReAuthorize(Handle timer, int client)
{
	if(!IsClientConnected(client))
		return Plugin_Stop;

	char steamid[32];
	if(!GetClientAuthId(client, AuthId_SteamID64, steamid, 32, true))
	{
		NP_Core_LogMessage("User", "OnClientAuthorized", "Error: Can not verify client`s SteamId64 -> \"%L\"", client);
		return Plugin_Continue;
	}

	CheckClient(client, steamid);
	
	return Plugin_Stop;
}

// ---------- timer ------------ end

// ---------- socket ------------ start

public void NP_Socket_OnReceived(const char[] event, const char[] data, const int size)
{
	if(!strcmp(event, "PlayerInfo"))
		CheckClientCallback(data);
	if(!strcmp(event, "BanClient"))
		BanClientCallback(data);
}

// ---------- socket ------------ end