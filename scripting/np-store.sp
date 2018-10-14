#pragma semicolon 1

#include <NewPage>
#include <NewPage/store>

#define P_NAME P_PRE ... " - Store"
#define P_DESC "In-game store function"

public Plugin myinfo = 
{
	name        = P_NAME,
	author      = P_AUTHOR,
	description = P_DESC,
	version     = P_VERSION,
	url         = P_URLS
};

bool g_bIsStoreReady = false;

int g_aItems[MAX_ITEMS][Item],
	g_aCategories[MAX_TYPES][Categorie];

Handle g_hOnUserBuy;

public void OnPluginStart()
{
	RegConsoleCmd("sm_store", Command_StoreMenu);
	RegConsoleCmd("sm_shop", Command_StoreMenu);

	g_hOnUserBuy = CreateGlobalForward("NP_Store_UserBuyItem", ET_Ignore, Param_Cell, Param_Cell, Param_Cell, Param_Cell);

	CreateRequest(InitStoreRequest, "store.php", "\"GetItems\":1");
}

void InitStoreRequest(bool success, const char[] error, System2HTTPRequest request, System2HTTPResponse response, HTTPRequestMethod method)
{
	if(!CheckRequest(success, error, request, response, method, "Store", "InitStoreRequest"))
		return;

	char[] content = new char[response.ContentLength + 1];
	response.GetContent(content, response.ContentLength + 1);
		
	InitStore(content);
	
	delete request;
}

void InitStore(const char[] content)
{
	Handle json, Items, Types;

	if ((json = json_load(content)) == INVALID_HANDLE)
	{
		NP_Core_LogError("Store", "BuildItemsMenu", "Error: Json -> \"%s\"", content);
		return;
	}

	Items = json_object_get(json, "Items");
	Types = json_object_get(json, "Types");

	int ItemsLength = json_array_size(Items);
	int TypesLength = json_array_size(Types);

	for(int i = 0, a = 0;i < ItemsLength; i++)
	{
		Handle ItemInfo;
		if ((ItemInfo = json_array_get(Items, i)) == INVALID_HANDLE)
		{
			g_aItems[a][ID] = json_object_get_int(ItemInfo, "ID");
			g_aItems[a][Type] = json_object_get_int(ItemInfo, "Type");
			json_object_get_string(ItemInfo, "Name", g_aItems[a][Name], 32);
			g_aItems[a][Price] = json_object_get_int(ItemInfo, "Price");
			g_aItems[a][Validity] = json_object_get_int(ItemInfo, "Validity");
			g_aItems[a][Buyable] = json_object_get_bool(ItemInfo, "Buyable");
			a++;
		}
		delete ItemInfo;
	}

	for(int i = 0, a = 0;i < TypesLength; i++)
	{
		Handle TypeInfo;
		if ((TypeInfo = json_array_get(Types, i)) == INVALID_HANDLE)
		{
			g_aCategories[a][ID] = json_object_get_int(TypeInfo, "ID");
			json_object_get_string(TypeInfo, "Name", g_aCategories[a][Name], 32);
			g_aCategories[a][Visible] = json_object_get_bool(TypeInfo, "Visible");
			a++;
		}
			
		delete TypeInfo;
	}

	g_bIsStoreReady = true;

	delete json;
	delete Items;
	delete Types;
}

public Action Command_StoreMenu(int client, int args)
{
	if (!IsValidClient(client))
		return Plugin_Handled;

	if (!NP_Users_IsAuthLoaded(client))
	{
		PrintToChat(client, "\x04[提示]\x01 你的账号信息仍未被加载！");
		return Plugin_Handled;
	}

	if (!g_bIsStoreReady)
	{
		PrintToChat(client, "\x04[提示]\x01 商店没有准备就绪！");
		return Plugin_Handled;
	}

	Menu menu = new Menu(MenuHandler_StoreMenu);
	menu.SetTitle("商店 - 现在拥有：%d 软妹币", NP_Users_GetMoney(client));

	for(int i = 0; i < MAX_TYPES; i++)
	{
		if(!g_aCategories[i][ID])
			continue;

		char id[4];
		IntToString(g_aCategories[i][ID], id, 4);
		menu.AddItem(id, g_aCategories[i][Name]);
	}
		
	menu.ExitButton = true;
	menu.Display(client, 0);
	return Plugin_Handled;
}

public int MenuHandler_StoreMenu(Menu menu, MenuAction action, int client, int slot)
{
	if (action == MenuAction_Cancel)
	{
		if(slot == MenuCancel_ExitBack)
			delete menu;
	}
	else if (action == MenuAction_Select)
	{
		char MenuItem[4];
		menu.GetItem(slot, MenuItem, 4);

		int id = StringToInt(MenuItem);

		Menu ItemMenu = new Menu(MenuHandler_ItemMenu);
		ItemMenu.SetTitle("商店 - %s - 现在拥有：%d 软妹币", g_aCategories[id][Name], NP_Users_GetMoney(client));

		for(int i = 0; i < MAX_ITEMS; i++)
		{
			if(!g_aItems[i][ID] || g_aItems[i][Type] != id || !g_aItems[i][Buyable])
				continue;

			char c_id[4];
			IntToString(g_aItems[i][ID], c_id, 4);
			ItemMenu.AddItem(c_id, g_aItems[i][Name]);
		}
			
		ItemMenu.ExitButton = true;
		ItemMenu.Display(client, 0);
	}
}

public int MenuHandler_ItemMenu(Menu menu, MenuAction action, int client, int slot)
{
	if (action == MenuAction_Cancel)
	{
		if(slot == MenuCancel_ExitBack)
			delete menu;
	}
	else if (action == MenuAction_Select)
	{
		char MenuItem[4];
		menu.GetItem(slot, MenuItem, 4);
		int id = StringToInt(MenuItem);

		if(g_aItems[id][Price] > NP_Users_GetMoney(client))
		{
			PrintToChat(client, "\x04[提示]\x01 你没钱钱买东西啦！");
			return;
		}

		Menu BuyMenu = new Menu(MenuHandler_BuyMenu);
		BuyMenu.SetTitle("商店 - 确认购买 %s ？", g_aItems[id][Name]);
		BuyMenu.AddItem(MenuItem, "我买了");
		BuyMenu.AddItem("NO", "我还是不买了");
		BuyMenu.Display(client, 0);
	}
}

public int MenuHandler_BuyMenu(Menu menu, MenuAction action, int client, int slot)
{
	if (action == MenuAction_Cancel)
	{
		if(slot == MenuCancel_ExitBack)
			delete menu;
	}
	else if (action == MenuAction_Select)
	{
		if(slot == 0)
		{
			char MenuItem[4];
			menu.GetItem(slot, MenuItem, 4);
			int id = StringToInt(MenuItem);

			if(NP_Users_PayMoney(client, g_aItems[id][Price]))
			{
				PrintToChat(client, "\x04[提示]\x01 成功购买 %s！", g_aItems[id][Name]);
				Call_StartForward(g_hOnUserBuy);
				Call_PushCell(client);
				Call_PushCell(g_aItems[id][ID]);
				Call_PushCell(g_aItems[id][Type]);
				Call_PushCell(g_aItems[id][Validity]);
				Call_Finish();
			}
			else
				PrintToChat(client, "\x04[提示]\x01 购买失败！");
		}
	}
}