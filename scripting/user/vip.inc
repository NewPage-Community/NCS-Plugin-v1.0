int g_iVIPReward[MAXPLAYERS+1];

bool GrantVip(int client, int duration)
{
	if (!NP_Users_IsAuthLoaded(client))
		return false;

	char m_szQuery[256];
	FormatEx(m_szQuery, 256, "CALL user_addvip(%d, %d)", NP_Users_UserIdentity(client), duration*86400);
	return NP_MySQL_SaveDatabase(m_szQuery);
}

bool DeleteVip(int client)
{
	//if player isn's vip
	if(!NP_Vip_IsVIP(client))
		return false;

	char m_szQuery[256];
	FormatEx(m_szQuery, 256, "UPDATE %s_users SET vipexpired = 0 WHERE uid = %d", P_SQLPRE, NP_Users_UserIdentity(client));
	return NP_MySQL_SaveDatabase(m_szQuery);
}

bool AddVipPoint(int client, int point)
{
	//if player isn's vip
	if(!NP_Vip_IsVIP(client))
		return false;

	char m_szQuery[256];
	FormatEx(m_szQuery, 256, "UPDATE %s_users SET vippoint = vippoint + %d WHERE uid = %d", P_SQLPRE, point, NP_Users_UserIdentity(client));
	
	if (NP_MySQL_SaveDatabase(m_szQuery))
	{
		g_aClient[client][VIPPoint] += point;
		return true;
	}

	return false;
}

public int Native_IsVIP(Handle plugin, int numParams)
{
	return g_aClient[GetNativeCell(1)][Auth][Vip];
}

public int Native_VIPLevel(Handle plugin, int numParams)
{
	return g_aClient[GetNativeCell(1)][VipLevel];
}

public int Native_GrantVip(Handle plugin, int numParams)
{
	return GrantVip(GetNativeCell(1), GetNativeCell(2));
}

public int Native_DeleteVip(Handle plugin, int numParams)
{
	return DeleteVip(GetNativeCell(1));
}

public int Native_AddVipPoint(Handle plugin, int numParams)
{
	return AddVipPoint(GetNativeCell(1), GetNativeCell(2));
}

public int Native_VipGetPoint(Handle plugin, int numParams)
{
	return g_aClient[GetNativeCell(1)][VIPPoint];
}

public int Native_IsPermanentVIP(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	return (g_aClient[client][Auth][Vip] && g_aClient[client][VIPExpired] == 99999999999) ? 1 : 0;
}

void VIPConnected(int client)
{
	if (!NP_Vip_IsVIP(client))
		return;

	if (NP_Stats_TodayOnlineTime(client) == 0)
	{
		char msg[512];
		FormatEx(msg, 512, "{red}%s{default} ： 叛乱，启动！", g_aClient[client][Name]);
		NP_AllChat_Msg(Custom, "会员", msg);
	}

	CPrintToChatAll("{green}欢迎 {yellow}LEVEL %i{green} %s会员 {red}%s{green} 加入服务器！", NP_Vip_VIPLevel(client), NP_Vip_IsPermanentVIP(client) ? "永久" : "", g_aClient[client][Name]);
}

void VIPSigned(int client)
{
	int point = g_cSignVIPPoint.IntValue;

	if (!NP_Vip_IsVIP(client))
		return;

	if (AddVipPoint(client, point) && point > 0)
		CPrintToChat(client, "\x04[系统提示]{blue} 签到获得 \x05%d{blue} 点经验！", point);
}

void VIPReward(int client, int onlinetime)
{
	if (!NP_Vip_IsVIP(client))
		return;

	if (!(onlinetime%3600))
	{
		int reward = g_cVIPOnlineReward.IntValue;

		if(g_iVIPReward[client] < g_cVIPOnlineMaxReward.IntValue)
		{
			char m_szQuery[256];
			FormatEx(m_szQuery, 256, "UPDATE %s_users SET vipreward = %d WHERE uid = %d", P_SQLPRE, g_iVIPReward[client] + reward, NP_Users_UserIdentity(client));
	
			if (NP_MySQL_SaveDatabase(m_szQuery))
			{
				g_iVIPReward[client] += reward;
				AddVipPoint(client, reward);
				
				// Client does not have to be in game
				if (IsClientInGame(client))
				{
					CPrintToChat(client, "\x04[系统提示]{blue} 今日累计在线1小时获得 \x05%d{blue} 点经验！", reward);

					if (!(onlinetime%7200))
					{
						if (GetEngineVersion() == Engine_Insurgency)
							NP_Ins_DisplayInstructorHint(client, 10.0, 0.0, 3.0, true, true, "icon_tip", "icon_tip", "", true, {255, 255, 255}, "你已经在线时间很长啦，注意休息哦~");
						else
							PrintHintText(client, "你已经在线时间很长啦，注意休息哦~");
					}
				}
			}
		}
	}
}

bool VIPRewardReset(int client)
{
	if (!NP_Vip_IsVIP(client))
		return false;

	char m_szQuery[256];
	FormatEx(m_szQuery, 256, "UPDATE %s_users SET vipreward = 0 WHERE uid = %d", P_SQLPRE, NP_Users_UserIdentity(client));
	
	if (NP_MySQL_SaveDatabase(m_szQuery))
		return true;
	
	return false;
}