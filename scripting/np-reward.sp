#pragma semicolon 1

#include <NewPage>
#include <NewPage/user>

#define P_NAME P_PRE ... " - Reward"
#define P_DESC "User module"

ConVar cv_min_player;
ConVar cv_reward_rmb;

public Plugin myinfo = 
{
	name        = P_NAME,
	author      = P_AUTHOR,
	description = P_DESC,
	version     = P_VERSION,
	url         = P_URLS
};

public void OnPluginStart()
{
	HookEvent("round_end", RoundEnd_Event, EventHookMode_Post);

	cv_min_player = CreateConVar("reward_min_player", "10", "Min player count for reward", 0, true, 0.0);
	cv_reward_rmb = CreateConVar("reward_rmb", "100", "RMB amount for reward", 0, true, 0.0);
}

public Action RoundEnd_Event(Event event, const char[] name, bool dontBroadcast)
{
	int winner = GetEventInt(event, "winner");
	if (winner == 2)
	{
		if (GetClientCount(true) >= cv_min_player.IntValue)
			Reward();
	}
	return Plugin_Continue;
}

void Reward()
{
	int rmb = cv_reward_rmb.IntValue;
	if (rmb <= 0)
	{
		return;
	}
	for (int client = 1; client < MaxClients; client++)
	{
		if (IsValidClient(client))
		{
			NP_Users_GiveMoney(client, rmb);
			CPrintToChat(client, "\x04[系统提示]{blue} 通关成功！奖励：{red}%d软妹币", rmb);
		}
	}
}