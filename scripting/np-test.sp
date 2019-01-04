#pragma semicolon 1

#include <NewPage>
#include <NewPage/user>

#define P_NAME P_PRE ... " - Test"
#define P_DESC "Test server plugin"

public Plugin myinfo = 
{
	name        = P_NAME,
	author      = P_AUTHOR,
	description = P_DESC,
	version     = P_VERSION,
	url         = P_URLS
};

public void NP_OnClientDataChecked(int client, int UserIdentity)
{
	if (NP_Users_IsAuthorized(client, Ctb) || NP_Users_IsAuthorized(client, Opt) || NP_Users_IsAuthorized(client, Adm) || NP_Users_IsAuthorized(client, Own))
		return;

	if (NP_Users_IsAuthorized(client, Vip))
		if (NP_Vip_VIPLevel(client) >= 3 || NP_Vip_IsPermanentVIP(client))
			return;

	KickClient(client, "你没有权限进入内测服");
}