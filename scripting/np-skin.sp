#pragma semicolon 1

#include <NewPage>
#include <NewPage/user>
#include <sdktools>
#include <sdkhooks>

#define MAX_SKINS 512
#define MAX_OWNERS 64

enum BuyPlan
{
	BP_time[5],
	BP_price[5]
}

enum Skin
{
	String:uid[32],
	String:name[32],
	String:model[PLATFORM_MAX_PATH],
	String:arm[PLATFORM_MAX_PATH],
	vip,
	op,
	personid[MAX_OWNERS],
	bool:buyable,
	plan[BuyPlan]
}

enum PlayerSkin
{
	String:PS_uid[32],
	PS_time
}

int g_skins[MAX_SKINS][Skin];
int iskins = 0;
int g_iBuySkin[MAXPLAYERS+1];
int g_iClientSkin[MAXPLAYERS+1][MAX_SKINS][PlayerSkin];
int g_iPreviewEnt[2048];
int g_iPreMdlRef[MAXPLAYERS+1] = {INVALID_ENT_REFERENCE, ...};
Handle g_tPreMdl[MAXPLAYERS+1];
bool g_bIsReady = false;
StringMap SkinIndex;
char g_iClientSkinCache[MAXPLAYERS+1][32];

Menu g_mSkin;
Menu g_mSkinBuy;

#define P_NAME P_PRE ... " - Skin"
#define P_DESC "Skin plugin"

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
	RegConsoleCmd("sm_skin", Command_SkinsMenu);
	RegConsoleCmd("sm_skins", Command_SkinsMenu);
	RegConsoleCmd("sm_model", Command_SkinsMenu);
	RegConsoleCmd("sm_models", Command_SkinsMenu);

	HookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_Pre);
}

public void OnMapStart()
{
	CreateTimer(5.0, Timer_Restart, TIMER_FLAG_NO_MAPCHANGE); // Delay for waiting map started
}

void LoadSkin()
{
	if (!NP_MySQL_IsConnected())
	{
		NP_Core_LogError("Skin", "LoadSkin", "Database is not ready!");
		CreateTimer(5.0, Timer_Restart);
		g_bIsReady = false;
		return;
	}
	
	Database mySQL = NP_MySQL_GetDatabase();

	DBResultSet skin = SQL_Query(mySQL, "SELECT `uid`, `name`, `op`, `vip`, `model`, `arm`, `owners`, `plan` FROM np_skins ORDER BY uid ASC;");
	if (skin == null)
	{
		char error[256];
		SQL_GetError(mySQL, error, 256);
		NP_Core_LogError("Skin", "LoadSkin", "Can not retrieve skin from database: %s", error);
		return;
	}

	if (skin.RowCount <= 0)
	{
		NP_Core_LogError("Skin", "LoadSkin", "Can not retrieve skin from database: no result row");
		return;
	}

	if (SkinIndex != INVALID_HANDLE)
		SkinIndex.Clear();
	SkinIndex = new StringMap();

	iskins = 0;

	// uid, name, team, vip, model, arm
	while (skin.FetchRow())
	{
		char temp_plan[512];
		char temp_owners[512];

		skin.FetchString(0, g_skins[iskins][uid], 32);
		skin.FetchString(1, g_skins[iskins][name], 32);
		g_skins[iskins][op] = skin.FetchInt(2);
		g_skins[iskins][vip] = skin.FetchInt(3);
		skin.FetchString(4, g_skins[iskins][model], PLATFORM_MAX_PATH);
		skin.FetchString(5, g_skins[iskins][arm], PLATFORM_MAX_PATH);
		skin.FetchString(6, temp_owners, 128);
		skin.FetchString(7, temp_plan, 128);

		if (!FileExists(g_skins[iskins][model], true))
		{
			NP_Core_LogError("Skin", "LoadSkin", "Can't precache Model! -> %s", g_skins[iskins][model]);
			continue;
		}
		
		SetTrieValue(SkinIndex, g_skins[iskins][uid], iskins, true);

		// Precache Model
		PrecacheModel(g_skins[iskins][model], true);
		//if (strlen(g_skins[iskins][arm]) > 3 && FileExists(g_skins[iskins][arm], true))
			//PrecacheModel(g_skins[iskins][arm], true);

		// Load owners
		if (temp_owners[0] != '\0')
		{
			Handle ownersJson;
			if ((ownersJson = json_load(temp_owners)) == INVALID_HANDLE)
			{
				g_skins[iskins][personid][0] = -1; // No one own this
			}
			else
			{
				int ownersNum = json_array_size(ownersJson);

				for (int i = 0, a = 0;i < ownersNum && i < MAX_OWNERS; i++)
					if ((g_skins[iskins][personid][a] = json_array_get_int(ownersJson, i)) != 0)
						a++;

				delete ownersJson;
			}
		}
		else
			g_skins[iskins][personid][0] = -1;

		// Load plan
		if (temp_plan[0] != '\0')
		{
			Handle planJson;
			if ((planJson = json_load(temp_plan)) == INVALID_HANDLE)
			{
				g_skins[iskins][buyable] = false; // Can not buy it :(
			}
			else
			{
				int planNum = json_array_size(planJson);
				for (int i = 0, a = 0;i < planNum && i < MAX_SKINS; i++)
				{
					Handle planInfo;
					if ((planInfo = json_array_get(planJson, i)) != INVALID_HANDLE)
					{
						g_skins[iskins][plan][BP_time][a] = json_object_get_int(planInfo, "Time");
						g_skins[iskins][plan][BP_price][a] = json_object_get_int(planInfo, "Price");
						a++;
					}
					delete planInfo;
				}

				g_skins[iskins][buyable] = true;
				delete planJson;
			}
		}
		else
			g_skins[iskins][buyable] = false;

		iskins++;
	}

	g_bIsReady = true;
}

public void NP_OnClientDataChecked(int client, int UserIdentity)
{
	g_iPreMdlRef[client] = INVALID_ENT_REFERENCE;

	CreateRequest(GetSkinCacheCallback, "skin.php", "\"GetCache\":1, \"UID\":%d", UserIdentity);
}

void GetSkinCacheCallback(bool success, const char[] error, System2HTTPRequest request, System2HTTPResponse response, HTTPRequestMethod method)
{
	if(!CheckRequest(success, error, request, response, method, "Skin", "GetSkinCacheCallback"))
		return;

	char[] content = new char[response.ContentLength + 1];
	response.GetContent(content, response.ContentLength + 1);

	LoadClient(content);
	
	delete request;
}

void LoadClient(const char[] content)
{
	Handle json;
	if ((json = json_load(content)) == INVALID_HANDLE)
	{
		NP_Core_LogError("Skin", "GetSkinCacheCallback", "Error: Json -> \"%s\"", content);
		return;
	}

	int client = NP_Users_FindUserByID(json_object_get_int(json, "uid"));
	if (!client)
		return;

	g_iClientSkinCache[client][0] = '\0';
	g_iBuySkin[client] = 0;

	for (int i = 0; i < MAX_SKINS; i++)
	{
		g_iClientSkin[client][i][PS_uid] = '\0';
		g_iClientSkin[client][i][PS_time] = 0;
	}

	json_object_get_string(json, "skin_cache", g_iClientSkinCache[client], 32);

	// Get Client Skin
	Handle ClientSkin = json_object_get(json, "skin");
	int SkinLength = json_array_size(ClientSkin);

	for (int i = 0, num = 0;i < SkinLength; i++)
	{
		Handle SkinList;
		if ((SkinList = json_array_get(ClientSkin, i)) != INVALID_HANDLE)
		{
			json_object_get_string(SkinList, "uid", g_iClientSkin[client][num][PS_uid], 32);
			g_iClientSkin[client][num][PS_time] = json_object_get_int(SkinList, "time");
			num++;
		}
		delete SkinList;
	}

	delete json;
	delete ClientSkin;
}

void SetModel(int client)
{
	if (!IsClientInGame(client) || !IsPlayerAlive(client) || IsFakeClient(client) || GetClientTeam(client) != 2) // For Insurgency PVE
		return;

	if (strcmp(g_iClientSkinCache[client], "default") != 0 && g_iClientSkinCache[client][0] != '\0')
	{
		int index = GetSkinIndex(g_iClientSkinCache[client]);
		if (SkinAccess(client, index))
			SetEntityModel(client, g_skins[index][model]);
		else
			SetSkinCache(client, "default");
	}
	
	return;
}

public Action Command_SkinsMenu(int client, int args)
{
	if(!IsValidClient(client))
		return Plugin_Handled;

	if (!g_bIsReady)
		return Plugin_Handled;

	g_mSkin = new Menu(Menu_Skin);
	g_mSkin.ExitButton = true;
	g_mSkin.SetTitle("皮肤系统");
	g_mSkin.AddItem("chooser", "更换皮肤");
	g_mSkin.AddItem("buy", "购买皮肤");
	g_mSkin.AddItem("bought", "已购皮肤");
	g_mSkin.Display(client, 60);
	return Plugin_Handled;
}

public int Menu_Skin(Menu menu, MenuAction action, int client, int slot)
{
	if (action == MenuAction_End && slot == MenuEnd_Exit)
	{
		delete menu;
	}
	else if (action == MenuAction_Select)
	{
		if (!IsValidClient(client))
			return;

		switch (slot)
		{
			case 0: DisplaySkinChooser(client);
			case 1: DisplayBuySkin(client);
			case 2: DisplayBoughtSkin(client);
		}
	}
}

void DisplaySkinChooser(int client)
{
	Menu menu = new Menu(Menu_SkinSelected);
	menu.ExitButton = true;
	menu.ExitBackButton = true;
	menu.SetTitle("选择你喜欢的模型");
	menu.AddItem("default", "默认皮肤");

	for (int i = 0; i < iskins; ++i)
		if (SkinAccess(client, i))
			menu.AddItem(g_skins[i][uid], g_skins[i][name]);

	menu.Display(client, 60);
}

public int Menu_SkinSelected(Menu menu, MenuAction action, int client, int slot)
{
	if (action == MenuAction_End)
	{
		delete menu;
	}
	else if (action == MenuAction_Cancel && slot == MenuCancel_ExitBack)
	{
		g_mSkin.Display(client, 60);
	}
	else if (action == MenuAction_Select)
	{
		if (!IsValidClient(client))
			return;

		char skin_uid[32], skin_name[32];
		menu.GetItem(slot, skin_uid, 32, _, skin_name, 32);

		// Save model
		SetSkinCache(client, skin_uid);
	
		CPrintToChat(client, "\x04[系统提示]{blue} 已成功更换为 {lime}%s{blue}！可通过 {olive}!tp{blue} 查看模型", skin_name);
	}
}

void SetSkinCache(int client, const char[] skin_uid)
{
	strcopy(g_iClientSkinCache[client], 32, skin_uid);
	CreateRequest(SetSkinCacheCallback, "skin.php", "\"SetCache\":\"%s\", \"UID\":\"%d\"",skin_uid , NP_Users_UserIdentity(client));
}

void SetSkinCacheCallback(bool success, const char[] error, System2HTTPRequest request, System2HTTPResponse response, HTTPRequestMethod method)
{
	if (!CheckRequest(success, error, request, response, method, "Skin", "SetSkinCacheCallback"))
		return;
	delete request;
}

int GetSkinIndex(const char[] skin_uid)
{
	int i;
	if (SkinIndex != INVALID_HANDLE)
		if (GetTrieValue(SkinIndex, skin_uid, i))
			return i;
	return 0; //Can not find the skin uid
}

public Action Timer_Restart(Handle timer)
{
	LoadSkin();
}

bool SkinAccess(int client, int skinid)
{
	// Server owner All YES!!!!
	if (NP_Users_IsAuthorized(client, Own))
		return true;

	// Store skin
	for (int i = 0; i < MAX_SKINS; i++)
		if (!strcmp(g_iClientSkin[client][i][PS_uid], g_skins[skinid][uid]))
			return true;
	
	// personal skin
	if (g_skins[iskins][personid][0] != -1)
	{
		int clientuid = NP_Users_UserIdentity(client);
		for (int i = 0; i < MAX_OWNERS; i++)
			if (clientuid == g_skins[skinid][personid][i])
				return true;
	}

	// vip skin
	if (g_skins[skinid][vip] && (NP_Vip_IsVIP(client) || IsClientOP(client))) 
		return true;
	
	// op skin
	if (g_skins[skinid][op] && IsClientOP(client)) 
		return true;

	return false;
}

public Action ModelCheck(Handle timer, int client)
{
	if (!IsClientInGame(client) || !IsPlayerAlive(client) || IsFakeClient(client))
		return Plugin_Stop;

	int index = GetSkinIndex(g_iClientSkinCache[client]);
	char sModelPath[128];

	GetEntPropString(client, Prop_Data, "m_ModelName", sModelPath, sizeof(sModelPath));

	if (StrContains(sModelPath, g_skins[index][model], true) == -1)
	{
		RequestFrame(SetModel, client);
	}

	return Plugin_Continue;
}

public Action Event_PlayerSpawn(Event event, const char[] name1, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (client < 1 || client > MaxClients || !IsClientInGame(client) || GetClientTeam(client) < 2)
		return Plugin_Continue;

	RequestFrame(SetModel, client);
	CreateTimer(0.1, ModelCheck, client, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);

	if(g_tPreMdl[client] != INVALID_HANDLE)
		KillTimer(g_tPreMdl[client]);
	g_tPreMdl[client] = INVALID_HANDLE;

	return Plugin_Continue;
}

void DisplayBuySkin(client)
{
	g_mSkinBuy = new Menu(Menu_BuySkin);
	g_mSkinBuy.ExitButton = true;
	g_mSkinBuy.ExitBackButton = true;
	g_mSkinBuy.SetTitle("购买皮肤");

	for (int i = 0; i < iskins; ++i)
		if (g_skins[i][buyable])	
			g_mSkinBuy.AddItem(g_skins[i][uid], g_skins[i][name]);

	g_mSkinBuy.Display(client, 60);
}

public int Menu_BuySkin(Menu menu, MenuAction action, int client, int slot)
{
	if (action == MenuAction_End && slot == MenuEnd_Exit)
	{
		delete menu;
	}
	else if (action == MenuAction_Cancel && slot == MenuCancel_ExitBack)
	{
		g_mSkin.Display(client, 60);
	}
	else if (action == MenuAction_Select)
	{
		if (!IsValidClient(client))
			return;

		char skin_uid[32], skin_name[32];
		menu.GetItem(slot, skin_uid, 32, _, skin_name, 32);

		int skin_id = GetSkinIndex(skin_uid);
		int client_money = NP_Users_GetMoney(client);

		g_iBuySkin[client] = skin_id;

		Menu menu1 = new Menu(Menu_PaySkin);
		menu1.ExitButton = true;
		menu1.ExitBackButton = true;
		menu1.SetTitle("购买：%s\n你拥有的软妹币：%d\n", skin_name, client_money);

		bool IsPermanent = false;
		for (int i = 0; i < MAX_SKINS; i++)
		{
			if (!strcmp(g_iClientSkin[client][i][PS_uid], skin_uid))
			{
				if (!g_iClientSkin[client][i][PS_time])
					IsPermanent = true;

				break;
			}
		}

		menu1.AddItem("Preview", "预览皮肤");

		for (int i = 0; i < 5; ++i)
		{
			if (g_skins[skin_id][plan][BP_price][i] > 0)
			{
				char mInfo[32], mName[32];
				Format(mInfo, 32, "%d", i);
				if (!g_skins[skin_id][plan][BP_time][i])
					Format(mName, 32, "永久 - %d软妹币", g_skins[skin_id][plan][BP_price][i]);
				else
					Format(mName, 32, "%d天 - %d软妹币", g_skins[skin_id][plan][BP_time][i], g_skins[skin_id][plan][BP_price][i]);

				menu1.AddItem(mInfo, mName, (client_money >= g_skins[skin_id][plan][BP_price][i] && !IsPermanent) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
			}
		}		
				
		menu1.Display(client, 60);
	}
}

public int Menu_PaySkin(Menu menu, MenuAction action, int client, int slot)
{
	if (action == MenuAction_End)
	{
		delete menu;
	}
	else if (action == MenuAction_Cancel && slot == MenuCancel_ExitBack)
	{
		g_mSkinBuy.Display(client, 60);
	}
	else if (action == MenuAction_Select)
	{
		if (!IsValidClient(client))
			return;

		char tplan[32];
		menu.GetItem(slot, tplan, 32);

		if (slot == 0)
		{
			PreviewSkin(client, g_iBuySkin[client]);
			return;
		}

		int iplan = StringToInt(tplan);

		if (NP_Users_PayMoney(client, g_skins[g_iBuySkin[client]][plan][BP_price][iplan]))
		{
			CreateRequest(BuySkinCallback, "skin.php", "\"AddSkin\":\"%s\", \"UID\":\"%d\", \"Time\":%d", g_skins[g_iBuySkin[client]][uid], NP_Users_UserIdentity(client), g_skins[g_iBuySkin[client]][plan][BP_time][iplan]);
			CPrintToChat(client, "\x04[系统提示]{blue} 成功购买皮肤 {lime}%s{blue}！", g_skins[g_iBuySkin[client]][name]);
		}
	}
}

void BuySkinCallback(bool success, const char[] error, System2HTTPRequest request, System2HTTPResponse response, HTTPRequestMethod method)
{
	if (!CheckRequest(success, error, request, response, method, "Skin", "BuySkinCallback"))
		return;

	char[] content = new char[response.ContentLength + 1];
	response.GetContent(content, response.ContentLength + 1);

	LoadClient(content);
	delete request;
}

void DisplayBoughtSkin(int client)
{
	Panel panel = CreatePanel();

	panel.SetTitle("已购皮肤");
	DrawPanelTextEx(panel, " ");
	
	for (int i = 0; i < MAX_SKINS; i++)
	{
		if (g_iClientSkin[client][i][PS_uid][0] != '\0')
		{
			int skinid = GetSkinIndex(g_iClientSkin[client][i][PS_uid]);
			char expireTime[128];
			if (!g_iClientSkin[client][i][PS_time])
				Format(expireTime, 128, "永久");
			else
				FormatTime(expireTime, 128, "%Y-%m-%d 到期", g_iClientSkin[client][i][PS_time]);

			DrawPanelTextEx(panel, "%s (%s)", g_skins[skinid][name], expireTime);
		}
	}

	DrawPanelTextEx(panel, " ");
	panel.DrawItem("返回");
	panel.DrawItem("退出");

	panel.Send(client, Menu_BoughtSkin, 30);
}

public int Menu_BoughtSkin(Menu menu, MenuAction action, int client, int slot)
{
	if (action == MenuAction_End)
	{
		delete menu;
	}
	else if (action == MenuAction_Select && slot == 1)
	{
		g_mSkin.Display(client, 60);
	}
}

void PreviewSkin(int client, int skinid)
{
	if(skinid == -1)
		return;
	
	if(g_tPreMdl[client] != INVALID_HANDLE)
		KillTimer(g_tPreMdl[client]);

	Timer_ClearPreMdl(INVALID_HANDLE, client);
	
	int m_iViewModel = CreateEntityByName("prop_dynamic_override");
	
	char m_szTargetName[32];
	FormatEx(m_szTargetName, 32, "Skin_Preview_%d", m_iViewModel);
	DispatchKeyValue(m_iViewModel, "targetname", m_szTargetName);

	DispatchKeyValue(m_iViewModel, "spawnflags", "64");
	DispatchKeyValue(m_iViewModel, "model", g_skins[skinid][model]);
	DispatchKeyValue(m_iViewModel, "rendermode", "0");
	DispatchKeyValue(m_iViewModel, "renderfx", "0");
	DispatchKeyValue(m_iViewModel, "rendercolor", "255 255 255");
	DispatchKeyValue(m_iViewModel, "renderamt", "255");
	DispatchKeyValue(m_iViewModel, "solid", "0");
	
	DispatchSpawn(m_iViewModel);
	
	SetEntProp(m_iViewModel, Prop_Send, "m_CollisionGroup", 11);
	
	AcceptEntityInput(m_iViewModel, "Enable");
	
	int offset = GetEntSendPropOffs(m_iViewModel, "m_clrGlow");
	SetEntProp(m_iViewModel, Prop_Send, "m_bShouldGlow", true, true);
	SetEntProp(m_iViewModel, Prop_Send, "m_nGlowStyle", 0);
	SetEntPropFloat(m_iViewModel, Prop_Send, "m_flGlowMaxDist", 2000.0);

	//Miku Green
	SetEntData(m_iViewModel, offset    ,  57, _, true);
	SetEntData(m_iViewModel, offset + 1, 197, _, true);
	SetEntData(m_iViewModel, offset + 2, 187, _, true);
	SetEntData(m_iViewModel, offset + 3, 255, _, true);

	float m_fOrigin[3], m_fAngles[3], m_fRadians[2], m_fPosition[3];

	GetClientAbsOrigin(client, m_fOrigin);
	GetClientAbsAngles(client, m_fAngles);

	m_fRadians[0] = DegToRad(m_fAngles[0]);
	m_fRadians[1] = DegToRad(m_fAngles[1]);

	m_fPosition[0] = m_fOrigin[0] + 64 * Cosine(m_fRadians[0]) * Cosine(m_fRadians[1]);
	m_fPosition[1] = m_fOrigin[1] + 64 * Cosine(m_fRadians[0]) * Sine(m_fRadians[1]);
	m_fPosition[2] = m_fOrigin[2] + 4 * Sine(m_fRadians[0]);
	
	m_fAngles[0] *= -1.0;
	m_fAngles[1] *= -1.0;

	TeleportEntity(m_iViewModel, m_fPosition, m_fAngles, NULL_VECTOR);

	g_iPreMdlRef[client] = EntIndexToEntRef(m_iViewModel);

	SDKHook(m_iViewModel, SDKHook_SetTransmit, Hook_SetTransmit_Preview);
	g_iPreviewEnt[m_iViewModel] = client;
	
	g_tPreMdl[client] = CreateTimer(30.0, Timer_ClearPreMdl, client);

	CPrintToChat(client, "\x04[系统提示]{blue} 预览皮肤 {lime}%s{blue}！", g_skins[skinid][name]);
}

public Action Timer_ClearPreMdl(Handle timer, int client)
{
	g_tPreMdl[client] = INVALID_HANDLE;
	
	if(g_iPreMdlRef[client] != INVALID_ENT_REFERENCE)
	{
		int entity = EntRefToEntIndex(g_iPreMdlRef[client]);

		if(IsValidEdict(entity))
		{
			g_iPreviewEnt[entity] = 0;
			SDKUnhook(entity, SDKHook_SetTransmit, Hook_SetTransmit_Preview);
			AcceptEntityInput(entity, "Kill");
		}
		
		g_iPreMdlRef[client] = INVALID_ENT_REFERENCE;
	}

	return Plugin_Stop;
}

public Action Hook_SetTransmit_Preview(int ent, int client)
{
	return (g_iPreviewEnt[ent] == client) ? Plugin_Continue : Plugin_Handled;
}