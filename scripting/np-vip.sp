#pragma semicolon 1

#include <NewPage>
#include <adminmenu>

#define P_NAME P_PRE ... " - VIP Function"
#define P_DESC "VIP Function plugin"

//Func
#include "vip/votekick"
#include "vip/namecolor"
#include "vip/exchangevip"

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

	char Time[128], playername[32];
	bool IsVip = NP_Vip_IsVIP(client);
	FormatTime(Time, 128, "%p", GetTime());
	NP_Users_GetName(client, playername, 32);

	Menu infoMenu = new Menu(MenuHandler_VIPMenu);
	infoMenu.SetTitle("尊贵的 %s，%s好！", playername, !strcmp(Time, "AM") ? "上午" : "下午");
	infoMenu.AddItem("FUNC", "会员功能", IsVip ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
	infoMenu.AddItem("GETVIP", "会员兑换", !NP_Vip_IsPermanentVIP(client) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
	infoMenu.ExitButton = true;
	infoMenu.Display(client, 0);
	return Plugin_Handled;
}

public int MenuHandler_VIPMenu(Menu menu, MenuAction action, int client, int slot)
{
	if (action == MenuAction_End)
		delete menu;
	else if (action == MenuAction_Select)
	{
		switch (slot)
		{
			case 0: DisplayVIPFunc(client);
			case 1: DisplayExchangeVIP(client);
		}
	}

	return 0;
}

void DisplayVIPFunc(int client)
{
	if (!IsValidClient(client))
		return;

	if (!NP_Vip_IsVIP(client))
	{
		PrintToChat(client, "\x04[提示]\x01 你不是会员，无法使用该功能！");
		return;
	}

	int viplevel = NP_Vip_VIPLevel(client);

	Menu infoMenu = new Menu(MenuHandler_VIPFunc);
	infoMenu.SetTitle("会员功能");
	infoMenu.AddItem("NAMECOLOR", "更改聊天名字颜色",  viplevel >= 4 ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
	infoMenu.AddItem("VOTEKICK", "投票踢人", viplevel >= 5 ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
	infoMenu.ExitButton = true;
	infoMenu.Display(client, 0);
}

public int MenuHandler_VIPFunc(Menu menu, MenuAction action, int client, int slot)
{
	if (action == MenuAction_End)
		delete menu;
	else if (action == MenuAction_Select)
	{
		switch (slot)
		{
			case 0: ChangeColorMenu(client);
			case 1: DisplayKickTargetMenu(client);
		}
	}

	return 0;
}