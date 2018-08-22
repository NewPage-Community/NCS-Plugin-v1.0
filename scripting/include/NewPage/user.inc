#define NP_BANURL "https://new-page.cc/bans"

#if defined _NewPage_User_Manager_Include_
    #endinput
#endif

#define _NewPage_User_Manager_Include_

#define VIPMAXLEVEL 8
#define TEAM_OB 1
#define TEAM_ONE 2
#define TEAM_TWO 3
#define STATS_SESSION 0
#define STATS_TOTAL   1

enum Authentication
{
    Spt,  //Supporter
    Vip,  //VIP
    Ctb,  //Contributor
    Opt,  //Operator
    Adm,  //Administrator
    Own   //Owner
}

enum Stats
{
    iObserveOnlineTime,
    iPlayOnlineTime,
    iTotalOnlineTime,
    iTodayOnlineTime,
}

enum ban_f
{
    ban_Client,
    ban_Identity
}

enum ban_t
{
    iTarget,
    iLength,
    iBanType,
    ban_f:banProc,
    bool:bListen,
    String:szAuthId[32],
    String:szReason[256]
}

forward void OnClientDataChecked(int client, int UserIdentity);
native int NP_Users_UserIdentity(int client);
native bool NP_Users_IsAuthorized(int client, Authentication auth);

native int NP_Group_GetUserGId(int client);
native bool NP_Group_IsGIdValid(int gid);

native int NP_Stats_TodayOnlineTime(int client);
native int NP_Stats_TotalOnlineTime(int client);
native int NP_Stats_ObserveOnlineTime(int client);
native int NP_Stats_PlayOnlineTime(int client);
native int NP_Stats_Vitality(int client);

native bool NP_Vip_IsVIP(int client);
native int NP_Vip_VIPLevel(int client);
native void NP_Vip_GrantVip(int client, int duration);
native void NP_Vip_DeleteVip(int client);
native void NP_Vip_AddVipPoint(int client, int point);

native void NP_Users_SetTag(int client, char[] TagName);

native void NP_Users_BanClient(int client, int admin, int banLength, int banType, const char[] banReason);
native void NP_Users_BanIdentity(const char[] steamIdentity, int admin, int banLength, int banType, const char[] banReason);

public SharedPlugin __pl_user =
{
	name = "np-user",
	file = "np-user.smx",
#if !defined REQUIRE_PLUGIN
    required = 0
#else
    required = 1
#endif
};