#pragma semicolon 1

#include <NewPage>
#include <NewPage/user>
#include <adminmenu>

#define P_NAME P_PRE ... " - VIP Function"
#define P_DESC "VIP Function plugin"

//Func
#include "vip/votekick"

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
	LoadTranslations("common.phrases");
	LoadTranslations("basevotes.phrases");
	LoadTranslations("plugin.basecommands");

	RegConsoleCmd("sm_vip", Command_VIPCmd);
	RegConsoleCmd("sm_vipvotekick", Command_Votekick);
}

public Action Command_VIPCmd(int client, int args)
{
	if (!IsValidClient(client))
		return Plugin_Handled;

	if (!NP_Users_IsAuthLoaded(client))
	{
		PrintToChat(client, "\x04[提示]\x01 你的账号信息仍未被加载！");
		return Plugin_Handled;
	}

	if (!NP_Vip_IsVIP(client))
	{
		PrintToChat(client, "\x04[提示]\x01 你不是会员，无法使用该功能！");
		return Plugin_Handled;
	}

	char Time[128], playername[32];
	int level = NP_Vip_VIPLevel(client);
	FormatTime(Time, 128, "%p", GetTime());
	NP_Users_GetName(client, playername, 32);

	Menu infoMenu = new Menu(MenuHandler_VIPFunc);
	infoMenu.SetTitle("尊贵的会员 %s，%s好！", playername, !strcmp(Time, "AM") ? "上午" : "下午");
	infoMenu.AddItem("VOTEKICK", "投票踢人", level >= 5 ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
	infoMenu.ExitButton = true;
	infoMenu.Display(client, 0);
	return Plugin_Handled;
}

public int MenuHandler_VIPFunc(Menu menu, MenuAction action, int client, int slot)
{
	if (action == MenuAction_End)
		delete menu;
	else if (action == MenuAction_Select)
	{
		switch (slot)
		{
			case 0: DisplayKickTargetMenu(client);
		}
	}
}