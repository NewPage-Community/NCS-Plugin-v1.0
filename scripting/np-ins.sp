#pragma semicolon 1

#define _Insurgency_

#include <NewPage>
#include <sdktools_functions>

// Ins
int g_iPlayerLastKnife[49+1] = {-1, ...};
int g_iOffsetMyWeapons = -1;

Handle g_hOnPlayerResupplyed;

#define P_NAME P_PRE ... " - Ins lib"
#define P_DESC "Provide Ins library"

public Plugin myinfo = 
{
	name        = P_NAME,
	author      = P_AUTHOR,
	description = P_DESC,
	version     = P_VERSION,
	url         = P_URLS
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	// lib
	RegPluginLibrary("np-ins");

	return APLRes_Success;
}
 
public void OnPluginStart()
{
	g_hOnPlayerResupplyed = CreateGlobalForward("NP_Ins_OnPlayerResupplyed", ET_Ignore, Param_Cell);
	HookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_Pre);

	g_iOffsetMyWeapons = FindSendPropInfo("CINSPlayer", "m_hMyWeapons");
	if (g_iOffsetMyWeapons == -1)
		LogError("Offset Error: Unable to find Offset for \"m_hMyWeapons\"");
}

public void OnMapStart()
{
	CreateTimer(0.1, ThinkTimer, _, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
}

public Action Event_PlayerSpawn(Event event, const char[] name1, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (client < 1 || client > MaxClients || !IsClientInGame(client) || GetClientTeam(client) != 2)
		return Plugin_Continue;

	// #Resupply Check
	int iKnife = GetPlayerWeaponByName(client, "weapon_knife");
	if (iKnife <= MaxClients || !IsValidEdict(iKnife))
		iKnife = GivePlayerItem(client, "weapon_knife");
	if (iKnife > MaxClients && IsValidEdict(iKnife))
		g_iPlayerLastKnife[client] = EntIndexToEntRef(iKnife);

	INS_OnPlayerResupplyed(client);

	return Plugin_Continue;
}

public Action ThinkTimer(Handle timer)
{
	for (int i = 1;i < MaxClients;i++)
	{	
		if (!IsClientInGame(i))
			continue;

		if (!IsPlayerAlive(i))
			continue;

		int client = i;
		if (g_iPlayerLastKnife[client] != -1)
		{
			// #Resupply Check
			int iKnife = GetPlayerWeaponByName(client, "weapon_knife");
			if (iKnife > MaxClients && IsValidEdict(iKnife))
				iKnife = EntIndexToEntRef(iKnife);
			else
			{
				iKnife = GivePlayerItem(client, "weapon_knife");
				if (iKnife <= MaxClients || !IsValidEdict(iKnife))
					iKnife = -1;
				else iKnife = EntIndexToEntRef(iKnife);
			}
			if (iKnife != -1 && iKnife != g_iPlayerLastKnife[client])
			{
				g_iPlayerLastKnife[client] = iKnife;
				INS_OnPlayerResupplyed(client);
			}
		}
	}
}

int GetPlayerWeaponByName(int client, const char[] weaponname)
{
	if (!IsClientInGame(client) || !IsPlayerAlive(client) || g_iOffsetMyWeapons == -1)
		return -1;

	for (int i = 0;i < 48;i++)
	{
		int weapon = GetEntDataEnt2(client, g_iOffsetMyWeapons+(4*i));
		if (weapon == -1) break;

		if (!IsValidEntity(weapon) || weapon <= MaxClients)
			continue;

		char classname[64];
		GetEntityClassname(weapon, classname, sizeof(classname));
		if (StrEqual(classname, weaponname, false))
			return weapon;
	}
	return -1;
}

void INS_OnPlayerResupplyed(int client)
{
	Call_StartForward(g_hOnPlayerResupplyed);
	Call_PushCell(client);
	Call_Finish();
}