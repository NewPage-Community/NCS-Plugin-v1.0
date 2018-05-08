void GrantVip(int client, int duration)
{
    if(!NP_MySQL_IsConnected())
    {
        NP_Core_LogError("Vip", "GrantVip", "Error: SQL is unavailable -> \"%L\"", client);
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

    if(!NP_MySQL_IsConnected())
    {
        NP_Core_LogError("Vip", "GrantVip", "Error: SQL is unavailable -> \"%L\"", client);
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

    if(!NP_MySQL_IsConnected())
    {
        NP_Core_LogError("Vip", "GrantVip", "Error: SQL is unavailable -> \"%L\"", client);
        return;
    }

    char m_szQuery[256];
    FormatEx(m_szQuery, 256, "UPDATE %s_users SET vippoint = vippoint + '%d' WHERE uid = '%d'", P_SQLPRE, point, NP_Users_UserIdentity(client));
    NP_MySQL_SaveDatabase(m_szQuery);
}