void GrantVip(int client, int duration)
{
    if(!NP_Socket_IsReady())
    {
        NP_Core_LogError("Vip", "GrantVip", "Error: Socket is unavailable -> \"%L\"", client);
        return;
    }

    char m_szQuery[256];
    FormatEx(m_szQuery, 256, "UPDATE %s_users SET vipexpired = '%d' WHERE uid = '%d'", P_SQLPRE, GetTime()+duration*86400, NP_Users_UserIdentity(client));
    NP_MySQL_SaveDatabase(m_szQuery);
}

void DeleteVip(int client)
{
    //if player isn's vip
    if(!g_authClient[client][Vip])
        return;

    if(!NP_Socket_IsReady())
    {
        NP_Core_LogError("Vip", "GrantVip", "Error: Socket is unavailable -> \"%L\"", client);
        return;
    }

    char m_szQuery[256];
    FormatEx(m_szQuery, 256, "UPDATE %s_users SET vipexpired = '%d' WHERE uid = '%d'", P_SQLPRE, 0, NP_Users_UserIdentity(client));
    NP_MySQL_SaveDatabase(m_szQuery);
}

void AddVipPoint(int client, int point)
{
    //if player isn's vip
    if(!g_authClient[client][Vip])
        return;

    if(!NP_Socket_IsReady())
    {
        NP_Core_LogError("Vip", "GrantVip", "Error: Socket is unavailable -> \"%L\"", client);
        return;
    }

    char m_szQuery[256];
    FormatEx(m_szQuery, 256, "UPDATE %s_users SET vippoint = vippoint + '%d' WHERE uid = '%d'", P_SQLPRE, point, NP_Users_UserIdentity(client));
    NP_MySQL_SaveDatabase(m_szQuery);
}

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