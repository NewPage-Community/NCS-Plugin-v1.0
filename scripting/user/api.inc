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
	CreateNative("NP_Users_SetCustomPrefix", Native_SetCustomPrefix);
	CreateNative("NP_Users_GetPrefix", Native_GetPrefix);

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
			if (IsClientConnected(i))
				return i;

	return 0;
}

// Name
public int Native_GetName(Handle plugin, int numParams)
{
	SetNativeString(2, g_aClient[GetNativeCell(1)][Name], GetNativeCell(3), true);
}

void RegForward()
{
	g_hOnUMDataChecked = CreateGlobalForward("NP_OnClientDataChecked", ET_Ignore, Param_Cell, Param_Cell);
	g_hOnClientSigned = CreateGlobalForward("NP_OnClientSigned",  ET_Ignore, Param_Cell, Param_Cell);
}