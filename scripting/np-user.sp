#pragma semicolon 1

#include <NewPage>
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

ConVar g_cSignTipsTimer,
	g_cSignMoney,
	g_cSignVIPMoney,
	g_cSignVIPPoint,
	g_cVIPOnlineReward,
	g_cVIPOnlineMaxReward,
	g_cSignOPMoney;

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
	CreateNative("NP_Group_GetGrpName", Native_GetGrpGName);

	// Auth
	CreateNative("NP_Users_IsAuthorized", Native_IsAuthorized);
	CreateNative("NP_Users_IsAuthLoaded", Native_IsAuthLoaded);
	
	// Identity
	CreateNative("NP_Users_UserIdentity", Native_UserIdentity);
	CreateNative("NP_Users_FindUserByID", Native_FindUserByID);

	// Vip
	CreateNative("NP_Vip_IsVIP", Native_IsVIP);
	CreateNative("NP_Vip_VIPLevel", Native_VIPLevel);
	CreateNative("NP_Vip_GrantVip", Native_GrantVip);
	CreateNative("NP_Vip_DeleteVip", Native_DeleteVip);
	CreateNative("NP_Vip_AddVipPoint", Native_AddVipPoint);
	CreateNative("NP_Vip_GetPoint", Native_VipGetPoint);
	CreateNative("NP_Vip_IsPermanentVIP", Native_IsPermanentVIP);

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
	CreateNative("NP_Users_GetTag", Native_GetTag);

	// Name
	CreateNative("NP_Users_GetName", Native_GetName);

	// Money
	CreateNative("NP_Users_PayMoney", Native_PayMoney);
	CreateNative("NP_Users_GiveMoney", Native_GiveMoney);
	CreateNative("NP_Users_GetMoney", Native_GetMoney);
	
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

public int Native_FindUserByID(Handle plugin, int numParams)
{
	int id = GetNativeCell(1);

	for (int i = 1; i <= MaxClients; i++)
		if (g_aClient[i][UID] == id)
			if (IsClientInGame(i))
				return i;

	return 0;
}

// Name
public int Native_GetName(Handle plugin, int numParams)
{
	SetNativeString(2, g_aClient[GetNativeCell(1)][Name], GetNativeCell(3), true);
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

	g_cSignTipsTimer = CreateConVar("np_user_sign_tipstimer", "120.0", "签到提示时间", 0, true, 0.0);
	g_cSignMoney = CreateConVar("np_user_sign_givemoney", "100", "签到奖励软妹币", 0, true, 0.0);
	g_cSignVIPMoney = CreateConVar("np_user_sign_VIPgivemoney", "120", "会员签到奖励软妹币", 0, true, 0.0);
	g_cSignVIPPoint = CreateConVar("np_user_sign_givevippoint", "10", "签到奖励会员经验", 0, true, 0.0);
	g_cVIPOnlineReward = CreateConVar("np_user_vip_onlinereward", "1", "会员每小时增加的成长值", 0, true, 0.0);
	g_cVIPOnlineMaxReward = CreateConVar("np_user_vip_onlinemaxreward", "12", "会员每天增加的成长值上限", 0, true, 0.0);
	g_cSignOPMoney = CreateConVar("np_user_sign_opmoney", "100", "管理工资", 0, true, 0.0);
}

// get group name
public void NP_Core_OnInitialized(int serverId, int modId)
{
	CheckGroup();
}

// ------------ native forward ------------

public void OnClientConnected(int client)
{
	for(int i = 0; i < view_as<int>(Authentication); ++i)
		g_aClient[client][Auth][i] = false;

	g_aClient[client][AuthLoaded] = false;
	g_aClient[client][Name][0] = '\0';
	g_aClient[client][GID] = -1;
	g_aClient[client][Money] = 0;
	g_iVIPReward[client] = 0;

	// Tag
	g_aClient[client][Tag][0] = '\0';
	
	g_aClient[client][UID] = 0;
}

public void OnClientDisconnect(int client)
{
	// Stats
	EndStats(client);
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

public Action OnLogAction(Handle source, Identity ident, int client, int target, const char[] message)
{
	AdminLog(client, message);
}

// ------------ native forward ------------ end

// ---------- functions ------------
void CheckClient(int client, const char[] steamid)
{
	if(g_aClient[client][AuthLoaded])
		return; 

	char ip[32], map[128];
	GetClientIP(client, ip, 32);
	GetCurrentMap(map, 128);

	CreateRequest(CheckClientCallback, "playerinfo.php", "\"SteamID\":\"%s\",\"Client\":%d,\"IP\":\"%s\",\"Map\":\"%s\"", steamid, client, ip, map);

	//防止因为网络波动而无法加载用户数据
	CreateTimer(5.0, Timer_CheckClient, client, TIMER_FLAG_NO_MAPCHANGE);
}

void CheckClientCallback(bool success, const char[] error, System2HTTPRequest request, System2HTTPResponse response, HTTPRequestMethod method)
{
	if(!CheckRequest(success, error, request, response, method, "User", "CheckClientCallback"))
		return;

	char[] content = new char[response.ContentLength + 1];
	response.GetContent(content, response.ContentLength + 1);
		
	LoadClient(content);

	delete request;
}

void LoadClient(char[] data)
{
	Handle json;

	if ((json = json_load(data)) == INVALID_HANDLE)
	{
		NP_Core_LogError("User", "LoadClient", "Error: Json -> \"%s\"", data);
		return;
	}

	int client = json_object_get_int(json, "Client");
	if (!client)
		return;

	//matche player information
	char data_steamid[32], steamid[32];
	json_object_get_string(json, "SteamID", data_steamid, 32);
	GetClientAuthId(client, AuthId_SteamID64, steamid, 32);
	if(strcmp(data_steamid, steamid) != 0)
		return;

	//init data
	StartStats(client);

	//get data
	g_aClient[client][UID] = json_object_get_int(json, "UID");
	g_aClient[client][Auth][Spt] = json_object_get_bool(json, "Spt");
	g_aClient[client][Auth][Vip] = json_object_get_bool(json, "Vip");
	g_aClient[client][Auth][Ctb] = json_object_get_bool(json, "Ctb");
	g_aClient[client][Auth][Opt] = json_object_get_bool(json, "Opt");
	g_aClient[client][Auth][Adm] = json_object_get_bool(json, "Adm");
	g_aClient[client][Auth][Own] = json_object_get_bool(json, "Own");
	g_aClient[client][VipLevel] = json_object_get_int(json, "Viplevel");
	g_aClient[client][GID] = json_object_get_int(json, "Grp");

	g_aClient[client][StatsTotal][iTotalOnlineTime]   = json_object_get_int(json, "OnlineTotal");
	g_aClient[client][StatsTotal][iTodayOnlineTime]   = json_object_get_int(json, "OnlineToday");
	g_aClient[client][StatsTotal][iObserveOnlineTime] = json_object_get_int(json, "OnlineOB");
	g_aClient[client][StatsTotal][iPlayOnlineTime]    = json_object_get_int(json, "OnlinePlay");

	g_aClient[client][ConnectTimes]   = json_object_get_int(json, "ConnectTimes")+1;
	g_aClient[client][Vitality] = json_object_get_int(json, "Vitality");

	g_aClient[client][StatsTrackingId] = json_object_get_int(json, "TrackingID");

	g_aClient[client][Money] = json_object_get_int(json, "Money");

	g_aClient[client][SignTimes] = json_object_get_int(json, "SignTimes");
	g_aClient[client][SignDate] = json_object_get_int(json, "SignDate");

	g_aClient[client][VIPPoint] = json_object_get_int(json, "VIPPoint");
	g_aClient[client][VIPExpired] = json_object_get_int(json, "VIPExpired");
	g_iVIPReward[client] = json_object_get_int(json, "VIPReward");

	char color[16];
	json_object_get_string(json, "NameColor", color, 16);
	NP_Chat_SetNameColor(client, color);

	GetClientName(client, g_aClient[client][Name], 32);

	g_aClient[client][AuthLoaded] = true;

	if(!CheckBan(client, json))
		return;

	CloseHandle(json);

	LoadAdmin(client, steamid);

	ChangePlayerPreName(client);
	VIPConnected(client);

	// Sign
	CreateTimer(g_cSignTipsTimer.FloatValue, Timer_SignTips, client, TIMER_REPEAT);

	CallDataForward(client);
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
	if(!IsClientConnected(client))
		return Plugin_Stop;

	if(!g_aClient[client][AuthLoaded])
	{
		NP_Core_LogMessage("User", "Timer_CheckClient", "Log: Client data have not loaded! -> \"%L\"", client);
		OnClientAuthorized(client, "");
	}

	return Plugin_Stop;
}

public Action Timer_ReAuthorize(Handle timer, int client)
{
	if(!IsClientConnected(client))
		return Plugin_Stop;

	char steamid[32];
	if(!GetClientAuthId(client, AuthId_SteamID64, steamid, 32, true))
	{
		NP_Core_LogMessage("User", "Timer_ReAuthorize", "Log: Can not verify client`s SteamId64 -> \"%L\"", client);
		return Plugin_Continue;
	}

	CheckClient(client, steamid);
	
	return Plugin_Stop;
}

// ---------- timer ------------ end

public void NP_Core_RconData(const char[] data, const char[] event)
{
	if(!strcmp(event, "BanCallback"))
		BanCallback(data);
}