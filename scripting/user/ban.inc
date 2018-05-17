void User_BanClient(int admin, int target, int btype, int length, const char[] reason)
{
    if(NP_Core_GetServerId() < 0)
        return;
    
    if(!NP_MySQL_IsConnected())
        return;
    
    Database db = NP_MySQL_GetDatabase();

    char ip[24];
    GetClientIP(target, ip, 24, false);
    
    char name[64], nickname[128];
    GetClientName(target, name, 64);
    db.Escape(name, nickname, 128);
    
    char adminName[64];
    db.Escape(g_szUsername[admin], adminName, 64);

    char bReason[256];
    db.Escape(reason, bReason, 256);
    
    char steamid[32];
    if(!GetClientAuthId(target, AuthId_SteamID64, steamid, 32, true))
    {
        NP_Core_LogError("User", "Native_BanClient", "We can not fetch target`s steamid64 -> \"%L\"", target);
        return;
    }

    char m_szQuery[1024];
    FormatEx(m_szQuery, 1024, "CALL user_ban('%s', '%s', '%s', %d, %d, %d, %d, %d, '%s', '%s');", steamid, ip, nickname, GetTime()+length*60, btype, NP_Core_GetServerId(), NP_Core_GetServerModId(), g_iUserId[admin], g_szUsername[admin], bReason);
    
    DataPack pack = new DataPack();
    pack.WriteCell(admin);
    pack.WriteCell(GetClientUserId(target));
    pack.WriteCell(btype);
    pack.WriteCell(length);
    pack.WriteString(reason);
    pack.WriteString(m_szQuery);

    db.Query(BanClientCallback, m_szQuery, pack);
}

/* void User_BanIdentity(int admin, char[] steamIdentity, int btype, int length, const char[] reason)
{
    if(NP_Core_GetServerId() < 0)
        return;

    // we using php auto-check target`s steam nickname.

    Database db = NP_MySQL_GetDatabase();

    char adminName[64];
    db.Escape(g_szUsername[admin], adminName, 64);

    char bReason[256];
    db.Escape(reason, bReason, 256);

    char m_szQuery[1024];
    FormatEx(m_szQuery, 1024, "INSERT INTO %s_bans VALUES (DEFAULT, '%s', '127.0.0.1', 'php_auto_check', %d, %d, %d, %d, %d, %d, '%s', '%s', -1);", P_SQLPRE, steamIdentity, GetTime()+length*60, btype, NP_Core_GetServerId(), NP_Core_GetServerModId(), g_iUserId[admin], g_szUsername[admin], bReason);

    NP_MySQL_SaveDatabase(m_szQuery);
    
    PrintToChatAll("%t", "Ban by server message", steamIdentity);
} */

public void BanClientCallback(Database db, DBResultSet results, const char[] error, DataPack pack)
{
    pack.Reset();
    int admin  = pack.ReadCell();
    int target = pack.ReadCell(); target = GetClientOfUserId(target);
    int btype  = pack.ReadCell();
    int length = pack.ReadCell();
    char reason[128];
    pack.ReadString(reason, 128);
    char query[1024];
    pack.ReadString(query, 1024);
    delete pack;

    if(results == null || error[0])
    {
        NP_Core_LogError("User", "BanClientCallback", "SQL Error:  %s -> \n%s", error, query);
        return;
    }

    if(results.FetchInt(0) == 1)
    {
        PrintToChat(admin, "Repeat ban", target);
        return;
    }
    
    if(!target || !IsClientConnected(target))
        return;
    
    char adminName[32];
    if(IsClientInGame(admin))
        GetClientName(admin, adminName, 32);
    else
        strcopy(adminName, 32, g_szUsername[admin]);

    char targetName[32];
    if(IsClientInGame(target))
        GetClientName(target, targetName, 32);
    else
        strcopy(targetName, 32, g_szUsername[target]);

    PrintToChatAll("%t", "Ban by admin message", targetName, adminName, reason);

    char timeExpired[64];
    if(length != 0)
        FormatTime(timeExpired, 64, "%Y.%m.%d %H:%M:%S", GetTime()+length*60);
    else
        FormatEx(timeExpired, 64, "%t", "Permanent ban");

    char kickReason[256];
    char g_banType[32];
    Bantype(btype, g_banType, 32);
    FormatEx(kickReason, 256, "%t", "Blocking information", g_banType, reason, timeExpired, NP_BANURL);
    BanClient(target, 5, BANFLAG_AUTHID, kickReason, kickReason);
}

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