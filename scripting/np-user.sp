#pragma semicolon 1

#include <NewPage>
#include <NewPage/user>
#include <smjansson>

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

//Handle g_hOnUMAuthChecked;
Handle g_hOnUMDataChecked;

// Stats

int g_iToday;
int g_iTrackingId[MAXPLAYERS+1];
int g_StatsClient[MAXPLAYERS+1][2][Stats];
int g_iConnectTimes[MAXPLAYERS+1];
int g_iClientVitality[MAXPLAYERS+1];

Handle g_TimerClient[MAXPLAYERS+1];

// Modules
#include "user/ban"
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
	
	// Banning
	CreateNative("NP_Users_BanClient",    Native_BanClient);
	//CreateNative("NP_Users_BanIdentity",  Native_BanIdentity);

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
	
	// lib
	RegPluginLibrary("np-user");

	return APLRes_Success;
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
	//g_hOnUMAuthChecked = CreateGlobalForward("OnClientAuthChecked", ET_Ignore, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell);
	g_hOnUMDataChecked = CreateGlobalForward("OnClientDataChecked", ET_Ignore, Param_Cell, Param_Cell);

	// init console
	g_iUserId[0] = 0;
	g_szUsername[0] = "CONSOLE";

	// stats
	// init
	g_iToday = GetDay();
	
	// global timer
	CreateTimer(1.0, Timer_Global, _, TIMER_REPEAT);

	LoadTranslations("np-user.phrases");
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
	{
		//CallAuthForward(client);
		return;
	}

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

	//处理特殊字符
	char m_szQuery[512];
	Format(m_szQuery, 512, "{\"Event\":\"PlayerConnection\",\"PlayerConnection\":{\"SteamID\":\"%s\",\"CIndex\":%d,\"IP\":\"%s\",\"JoinTime\":%d,\"TodayDate\":%i,\"Map\":\"%s\",\"ServerID\":%d,\"ServerModID\":%d}}", steamid, client, ip, GetTime(), g_iToday, map, NP_Core_GetServerId(), NP_Core_GetServerModId());
	Handle json = json_load(m_szQuery);
	json_dump(json, m_szQuery, 512);
	NP_Socket_Write(m_szQuery);
	//防止因为网络波动而无法加载用户数据
	CreateTimer(15.0, Timer_CheckClient, client, TIMER_FLAG_NO_MAPCHANGE);
}


void CheckClientCallback(const char[] data)
{
	Handle json = json_load(data);

	int client = json_object_get_int(json, "CIndex");

	if(!IsValidClient(client))
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
	json_object_get_string(playerinfo, "Username", g_szUsername[client], 32);
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
	
	//check ban
	if(json_object_get_bool(playerinfo, "IsBan"))
	{
		char t_bReason[32];
		json_object_get_string(playerinfo, "BanR", t_bReason, 32);
		KickBannedClient(client, json_object_get_int(playerinfo, "BanT"), json_object_get_int(playerinfo, "BExpired"), t_bReason, t_steamid);
		return;
	}
	
	SetAdmin(client, json_object_get_int(playerinfo, "Imm"));
	//CallAuthForward(client);

	CloseHandle(json);
	CloseHandle(playerinfo);
}

void SetAdmin(int client, int imm)
{
	if(g_authClient[client][Ctb] || g_authClient[client][Opt] || g_authClient[client][Adm] || g_authClient[client][Own])
	{
		AdminId _admin = GetUserAdmin(client);
		if(_admin != INVALID_ADMIN_ID)
		{
			RemoveAdmin(_admin);
			SetUserAdmin(client, INVALID_ADMIN_ID);
		}

		_admin = CreateAdmin(g_szUsername[client]);
		SetUserAdmin(client, _admin, true);
		SetAdminImmunityLevel(_admin, imm);

		_admin.SetFlag(Admin_Reservation, true);
		_admin.SetFlag(Admin_Generic, true);
		_admin.SetFlag(Admin_Kick, true);
		_admin.SetFlag(Admin_Slay, true);
		_admin.SetFlag(Admin_Chat, true);
		_admin.SetFlag(Admin_Vote, true);
		_admin.SetFlag(Admin_Changemap, true);

		if(g_authClient[client][Opt] || g_authClient[client][Adm] || g_authClient[client][Own])
		{
			_admin.SetFlag(Admin_Ban, true);
			_admin.SetFlag(Admin_Unban, true);

			if(g_authClient[client][Adm] || g_authClient[client][Own])
			{
				_admin.SetFlag(Admin_Convars, true);
				_admin.SetFlag(Admin_Config, true);

				if(g_authClient[client][Own])
				{
					_admin.SetFlag(Admin_Password, true);
					_admin.SetFlag(Admin_Cheats, true);
					_admin.SetFlag(Admin_RCON, true);
					_admin.SetFlag(Admin_Root, true);
				}
			}
		}

		// we give admin perm before client admin check
		if(IsClientInGame(client))
			RunAdminCacheChecks(client);
	}
	else if(g_authClient[client][Vip])
	{
		AdminId _admin = GetUserAdmin(client);
		if(_admin != INVALID_ADMIN_ID)
		{
			RemoveAdmin(_admin);
			SetUserAdmin(client, INVALID_ADMIN_ID);
		}

		_admin = CreateAdmin(g_szUsername[client]);
		SetUserAdmin(client, _admin, true);

		_admin.SetFlag(Admin_Reservation, true);

		// we give admin perm before client admin check
		if(IsClientInGame(client))
			RunAdminCacheChecks(client);
	}
}

/*
void CallAuthForward(int client)
{
	Call_StartForward(g_hOnUMAuthChecked);
	Call_PushCell(client);
	for(int i = 0; i < view_as<int>(Authentication); ++i)
		Call_PushCell(g_authClient[client][i]);
	Call_Finish();
}
*/

void CallDataForward(int client)
{
	Call_StartForward(g_hOnUMDataChecked);
	Call_PushCell(client);
	Call_PushCell(g_iUserId[client]);
	Call_Finish();
}

// ---------- functions ------------ end


// ---------- timer ------------

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
		char strFlag[5][4];
		for(int x = 0; x < 5; ++x)
			TickOrCross(g_authClient[index][x], strFlag[x]);
		PrintToConsole(client, "#%s    %s    %N    %s    %s    %s    %s    %s", strSlot, strUser, index, strFlag[0], strFlag[1], strFlag[2], strFlag[3], strFlag[4]);
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