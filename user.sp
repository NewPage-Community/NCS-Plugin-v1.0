#pragma semicolon 1
#pragma newdecls required

#include <NewPage>
#include <NewPage/user>

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
bool g_authClient[MAXPLAYERS+1][Authentication];
bool g_bAuthLoaded[MAXPLAYERS+1];
bool g_bBanChecked[MAXPLAYERS+1];
char g_szUsername[MAXPLAYERS+1][32];

Handle g_hOnUMAuthChecked;
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

// ---------- API ------------
public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
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

// Vip
public int Native_IsVIP(Handle plugin, int numParams)
{
    return g_authClient[GetNativeCell(1)][Vip];
}

public int Native_VIPLevel(Handle plugin, int numParams)
{
    return g_ivipLevel[GetNativeCell(1)];
}

public int Native_GrantVip(Handle plugin, int numParams)
{
    GrantVip(GetNativeCell(1), GetNativeCell(2));
}

public int Native_DeleteVip(Handle plugin, int numParams)
{
    DeleteVip(GetNativeCell(1));
}

public int Native_AddVipPoint(Handle plugin, int numParams)
{
    AddVipPoint(GetNativeCell(1), GetNativeCell(2));
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

// Banning
public int Native_BanClient(Handle plugin, int numParams)
{
    char reason[128];
    GetNativeString(5, reason, 128);
    User_BanClient(GetNativeCell(1), GetNativeCell(2), GetNativeCell(3), GetNativeCell(4), reason);
}

/* public int Native_BanIdentity(Handle plugin, int numParams)
{
    char steamIdentity[32], reason[128];
    GetNativeString(2, steamIdentity, 32);
    GetNativeString(5, reason, 128);
    User_BanIdentity(GetNativeCell(1), steamIdentity, GetNativeCell(3), GetNativeCell(4), reason);
} */

// Stats
public int Native_TodayOnlineTime(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    return g_StatsClient[client][STATS_SESSION][iTodayOnlineTime] + g_StatsClient[client][STATS_TOTAL][iTodayOnlineTime];
}

public int Native_TotalOnlineTime(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    return g_StatsClient[client][STATS_SESSION][iTotalOnlineTime] + g_StatsClient[client][STATS_TOTAL][iTotalOnlineTime];
}

public int Native_ObserveOnlineTime(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    return g_StatsClient[client][STATS_SESSION][iObserveOnlineTime] + g_StatsClient[client][STATS_TOTAL][iObserveOnlineTime];
}

public int Native_PlayOnlineTime(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    return g_StatsClient[client][STATS_SESSION][iPlayOnlineTime] + g_StatsClient[client][STATS_TOTAL][iPlayOnlineTime];
}

public int Native_Vitality(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    return g_iClientVitality[client];
}

// ---------- API ------------ end

public void OnPluginStart()
{
    // console command
    AddCommandListener(Command_Who, "sm_who");

    // global forwards
    g_hOnUMAuthChecked = CreateGlobalForward("OnClientAuthChecked", ET_Ignore, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell);
    g_hOnUMDataChecked = CreateGlobalForward("OnClientDataChecked", ET_Ignore, Param_Cell, Param_Cell);

    // init console
    g_iUserId[0] = 0;
    g_szUsername[0] = "CONSOLE";

    // stats
    // init
    g_iToday = GetDay();
    
    // global timer
    CreateTimer(1.0, Timer_Global, _, TIMER_REPEAT);
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
    g_iTrackingId[client]   = -1;
    g_iConnectTimes[client] = 0;

    for(int i = 0; i < view_as<int>(Stats); ++i)
    {
        g_StatsClient[client][STATS_SESSION][i] = 0;
        g_StatsClient[client][STATS_TOTAL][i] = 0;
    }

    if(IsFakeClient(client) || IsClientSourceTV(client))
        return;

    g_TimerClient[client] = CreateTimer(1.0, Timer_Client, client, TIMER_REPEAT);
}

public void OnClientDisconnect(int client)
{
    if(g_TimerClient[client] != INVALID_HANDLE)
        KillTimer(g_TimerClient[client]);

    g_TimerClient[client] = INVALID_HANDLE;

    if(g_iTrackingId[client] <= 0)
        return;

    char m_szQuery[256], m_szUsername[32], m_szEscape[64];
    GetClientName(client, m_szUsername, 32);
    NP_MySQL_GetDatabase().Escape(m_szUsername, m_szEscape, 64);
    FormatEx(m_szQuery, 256, "CALL user_stats (%d, %d, %d, %d, %d, %d, '%s')", NP_Users_UserIdentity(client), g_iTrackingId[client], g_StatsClient[client][STATS_SESSION][iTodayOnlineTime], g_StatsClient[client][STATS_SESSION][iTotalOnlineTime], g_StatsClient[client][STATS_SESSION][iObserveOnlineTime], g_StatsClient[client][STATS_SESSION][iPlayOnlineTime], m_szEscape);
    NP_MySQL_SaveDatabase(m_szQuery);
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
        CallAuthForward(client);
        return;
    }

    char steamid[32];
    if(!GetClientAuthId(client, AuthId_SteamID64, steamid, 32, true))
    {
        NP_Core_LogMessage("User", "OnClientAuthorized", "Error: We can not verify client`s SteamId64 -> \"%L\"", client);
        CreateTimer(0.1, Timer_ReAuthorize, client, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
        return;
    }

    //LoadClientAuth(client, steamid);
    //CheckClientBanStats(client, steamid);
    CheckClient(client, steamid);
}

// ------------ native forward ------------ end

// ---------- functions ------------
void CheckClient(int client, const char[] steamid)
{
    if(g_bAuthLoaded[client])
        return; 

    if(!NP_MySQL_IsConnected())
    {
        NP_Core_LogError("User", "LoadClientAuth", "Error: SQL is unavailable -> \"%L\"", client);
        CreateTimer(5.0, Timer_ReAuthorize, client, TIMER_FLAG_NO_MAPCHANGE);
        return;
    }

    Database db = NP_MySQL_GetDatabase();

    char ip[32];
    GetClientIP(client, ip, 32);
    
    char map[128];
    GetCurrentMap(map, 128);

    char m_szQuery[256];
    FormatEx(m_szQuery, 256, "CALL user_join (%s, %d, %s, %s, %d, %d)", steamid, NP_Core_GetServerId(), ip, map, GetTime(), g_iToday);
    db.Query(CheckClientCallback, m_szQuery, GetClientUserId(client));
}

public void CheckClientCallback(Database db, DBResultSet results, const char[] error, int userid)
{
    int client = GetClientOfUserId(userid);
    if(!client)
        return;

    if(results == null || error[0])
    {
        NP_Core_LogError("User", "LoadClientCallback", "SQL Error:  %s -> \"%L\"", error, client);
        CreateTimer(5.0, Timer_ReAuthorize, client, TIMER_FLAG_NO_MAPCHANGE);
        return;
    }
    
    g_bAuthLoaded[client] = true;

    // 0uid, 1name, 2imm, 3spt, 4vip, 5ctb, 6opt, 7adm, 8own, 9viplevel, 10onlineTotal, 11onlineToday, 12onlineOB, 13onlinePlay, 14connectTimes, 15vitality, 16insertId, 17isBan, 18bType, 19bExpired, 20bReason

    g_iUserId[client] = results.FetchInt(0);
    results.FetchString(1, g_szUsername[client], 32);
    g_authClient[client][Spt] = (results.FetchInt(3) == 1);
    g_authClient[client][Vip] = (results.FetchInt(4) == 1);
    g_authClient[client][Ctb] = (results.FetchInt(5) == 1);
    g_authClient[client][Opt] = (results.FetchInt(6) == 1);
    g_authClient[client][Adm] = (results.FetchInt(7) == 1);
    g_authClient[client][Own] = (results.FetchInt(8) == 1);
    g_ivipLevel[client] = results.FetchInt(9);

    g_StatsClient[client][STATS_TOTAL][iTotalOnlineTime]   = results.FetchInt(10);
    g_StatsClient[client][STATS_TOTAL][iTodayOnlineTime]   = results.FetchInt(11);
    g_StatsClient[client][STATS_TOTAL][iObserveOnlineTime] = results.FetchInt(12);
    g_StatsClient[client][STATS_TOTAL][iPlayOnlineTime]    = results.FetchInt(13);

    g_iConnectTimes[client]   = results.FetchInt(14)+1;
    g_iClientVitality[client] = results.FetchInt(15);

    g_iTrackingId[client] = results.FetchInt(16);
    
    //check ban
    if(results.FetchInt(17) == 1)
    {
        char t_bReason[32];
        results.FetchString(20, t_bReason, 32);
        KickBannedClient(client, results.FetchInt(18), results.FetchInt(19), t_bReason);
        return;
    }
    
    SetAdmin(client, results);
    CallAuthForward(client);
}

void KickBannedClient(int client, int bType, int bExpired, char[] bReason)
{
    char timeExpired[64];
    if(bExpired != 0)
        FormatTime(timeExpired, 64, "%Y.%m.%d %H:%M:%S", bExpired);
    else
        FormatEx(timeExpired, 64, "%t", "Permanent ban");

    char kickReason[256];
    char g_banType[32];
    Bantype(bType, g_banType, 32);
    FormatEx(kickReason, 256, "%t", "Blocking information", g_banType, bReason, timeExpired, NP_BANURL);
    BanClient(client, 5, BANFLAG_AUTHID, kickReason, kickReason);
}

void SetAdmin(int client, DBResultSet results)
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
        SetAdminImmunityLevel(_admin, results.FetchInt(2));

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

// old

/*
public void LoadClientCallback(Database db, DBResultSet results, const char[] error, int userid)
{
    int client = GetClientOfUserId(userid);
    if(!client)
        return;

    if(results == null || error[0])
    {
        NP_Core_LogError("User", "LoadClientCallback", "SQL Error:  %s -> \"%L\"", error, client);
        CreateTimer(5.0, Timer_ReAuthorize, client, TIMER_FLAG_NO_MAPCHANGE);
        return;
    }
    
    g_bAuthLoaded[client] = true;

    if(results.RowCount <= 0 || !results.FetchRow())
    {
        InsertNewUserData(client);
        CallAuthForward(client);
        return;
    }

    g_iUserId[client] = results.FetchInt(0);
    results.FetchString(1, g_szUsername[client], 32);
    g_authClient[client][Spt] = (results.FetchInt(3) == 1);
    g_authClient[client][Vip] = (results.FetchInt(4) == 1);
    g_authClient[client][Ctb] = (results.FetchInt(5) == 1);
    g_authClient[client][Opt] = (results.FetchInt(6) == 1);
    g_authClient[client][Adm] = (results.FetchInt(7) == 1);
    g_authClient[client][Own] = (results.FetchInt(8) == 1);

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
        SetAdminImmunityLevel(_admin, results.FetchInt(2));

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
    
    CallAuthForward(client);
} */

void CallAuthForward(int client)
{
    Call_StartForward(g_hOnUMAuthChecked);
    Call_PushCell(client);
    for(int i = 0; i < view_as<int>(Authentication); ++i)
        Call_PushCell(g_authClient[client][i]);
    Call_Finish();
}

void CallDataForward(int client)
{
    Call_StartForward(g_hOnUMDataChecked);
    Call_PushCell(client);
    Call_PushCell(g_iUserId[client]);
    Call_Finish();
}

// ---------- functions ------------ end


// ---------- timer ------------

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

    //LoadClientAuth(client, steamid);
    //CheckClientBanStats(client, steamid);
    CheckClient(client, steamid);
    
    return Plugin_Stop;
}

public Action Timer_Client(Handle timer, int client)
{
    if(IsClientInGame(client) && GetClientTeam(client) > TEAM_OB)
    {
        g_StatsClient[client][STATS_SESSION][iPlayOnlineTime]++;
    }
    else
    {
        g_StatsClient[client][STATS_SESSION][iObserveOnlineTime]++;
    }
    
    g_StatsClient[client][STATS_SESSION][iTodayOnlineTime]++;
    g_StatsClient[client][STATS_SESSION][iTotalOnlineTime]++;
 
    return Plugin_Continue;
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