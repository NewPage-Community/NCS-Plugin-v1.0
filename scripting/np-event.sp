#pragma semicolon 1

#include <NewPage>
#include <NewPage/user>

#define P_NAME P_PRE ... " - Event controller"
#define P_DESC "User module"

bool b_IsInEvent = false;
int i_RMBReward = 0;
int i_VIPReward = 0;

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
	HookEvent("round_start", RoundStart_Event, EventHookMode_Post);
	HookEvent("round_end", RoundEnd_Event, EventHookMode_Post);
	RegAdminCmd("sm_startevent", StartEvent_Callback, ADMFLAG_BAN, "");
}

public void OnMapStart()
{
	EventStop();
}

public void OnMapEnd()
{
	EventStop();
}

public Action RoundStart_Event(Event event, const char[] name, bool dontBroadcast)
{
	if (b_IsInEvent)
	{
		FindConVar("mp_maxrounds").SetInt(99);
	}
}

public Action RoundEnd_Event(Event event, const char[] name, bool dontBroadcast)
{
	int winner = GetEventInt(event, "winner");
	if (winner == 2)
	{
		Reward();
		EventStop();
		CPrintToChatAll("\x04[系统提示]{blue} 通关目标已达成，活动结束！");
	}
	return Plugin_Continue;
}

public Action StartEvent_Callback(int client, int args)
{
	if (args < 2)
	{
		ReplyToCommand(client, "[提示] 用法: sm_startevent VIP奖励(天) 软妹币奖励");
		return Plugin_Handled;
	}

	if (b_IsInEvent)
	{
		ReplyToCommand(client, "[提示] 活动已开始，无需重复开启");
		return Plugin_Handled;
	}

	char vip[65];
	char rmb[65];
	GetCmdArg(1, vip, sizeof(vip));
	GetCmdArg(2, rmb, sizeof(rmb));

	int vip_reward = StringToInt(vip, 10);
	int rmb_reward = StringToInt(rmb, 10);

	EventStart(vip_reward, rmb_reward);
	CPrintToChatAll("\x04[系统提示]{blue} 活动正式开始！本次活动通关将奖励：{red}%d天VIP  %d软妹币", vip_reward, rmb_reward);
	return Plugin_Handled;
}

void EventStart(int vip_reward, int rmb_reward)
{
	b_IsInEvent = true;
	i_VIPReward = vip_reward;
	i_RMBReward = rmb_reward;
	FindConVar("mp_restartgame").SetInt(1);
}

void EventStop()
{
	b_IsInEvent = false;
	i_VIPReward = 0;
	i_RMBReward = 0;
	FindConVar("mp_maxrounds").SetInt(1);
}

void Reward()
{
	for (int client = 1; client < MaxClients; client++)
	{
		if (IsValidClient(client))
		{
			bool success = true;
			success = NP_Users_GiveMoney(client, i_RMBReward);
			success = NP_Vip_GrantVip(client, i_VIPReward);

			if (success)
			{
				CPrintToChat(client, "\x04[系统提示]{blue} 活动奖励已发送到你的账户！奖励：{red}%d天VIP  %d软妹币", i_VIPReward, i_RMBReward);
			}
			else
			{
				CPrintToChat(client, "\x04[系统提示]{blue} 发送奖励失败，请截图并联系管理！");
			}
		}
	}
}