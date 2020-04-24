#pragma semicolon 1

#include <NewPage>
#include <NewPage/user>

#define P_NAME P_PRE ... " - Give money"
#define P_DESC "User module"

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
	RegAdminCmd("sm_money", GiveMoney_Callback, ADMFLAG_BAN, "");
}

public Action GiveMoney_Callback(int client, int args)
{
	if (args < 2)
	{
		ReplyToCommand(client, "[提示] 用法: sm_money <#userid|name> 数量");
		return Plugin_Handled;
	}

	char arg[65];
	char amount[65];
	GetCmdArg(1, arg, sizeof(arg));
	GetCmdArg(2, amount, sizeof(amount));

	char target_name[MAX_TARGET_LENGTH];
	int target_list[MAXPLAYERS], target_count;
	bool tn_is_ml;
	
	if ((target_count = ProcessTargetString(
			arg,
			client,
			target_list,
			MAXPLAYERS,
			COMMAND_FILTER_NO_BOTS,
			target_name,
			sizeof(target_name),
			tn_is_ml)) <= 0)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}

	int money = StringToInt(amount, 10);
	for (int i = 0; i < target_count; i++)
	{
		NP_Users_GiveMoney(target_list[i], money);
		ShowActivity2(client, "[系统提示] ", "%N 给 %N 赠送 %d 软妹币", client, target_list[i], money);
	}
	
	return Plugin_Handled;
}