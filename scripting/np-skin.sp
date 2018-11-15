#pragma semicolon 1

#include <NewPage>
#include <sdktools_functions>

#define COOKIE_TEs  0
#define COOKIE_CTs  1
#define COOKIE_ANY  2
#define MAX_SKINS 64

#define D_MODEL "models/characters/security_light.mdl"
#define D_ARM "models/weapons/v_hands_sec_l.mdl"

enum Skin
{
	String:uid[32],
	String:name[32],
	String:model[PLATFORM_MAX_PATH],
	String:arm[PLATFORM_MAX_PATH],
	vip,
	op,
	personid
}

int g_skins[MAX_SKINS][Skin];
int iskins = 0;
bool g_bIsReady = false;
StringMap SkinIndex;
char g_iClientSkinCache[MAXPLAYERS+1][32];

#define P_NAME P_PRE ... " - Skin"
#define P_DESC "Skin function plugin"

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

	HookEventEx("player_spawn", Event_PlayerSpawn, EventHookMode_Pre);	
}

public void OnMapStart()
{
	LoadSkin();

	PrecacheModel(D_MODEL, true);
	PrecacheModel(D_ARM, true);
}

void LoadSkin()
{
	if (NP_MySQL_IsConnected())
	{
		NP_Core_LogError("Skin", "LoadSkin", "Database is not ready!");
		CreateTimer(5.0, Timer_Restart);
		g_bIsReady = false;
		return;
	}	

	Database mySQL = NP_MySQL_GetDatabase();

	DBResultSet skin = SQL_Query(mySQL, "SELECT * FROM np_skins ORDER BY uid ASC;");
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

	// uid, name, team, vip, model, arm
	while (skin.FetchRow())
	{
		skin.FetchString(0, g_skins[iskins][uid], 32);
		skin.FetchString(1, g_skins[iskins][name], 32);
		g_skins[iskins][op] = skin.FetchInt(2);
		g_skins[iskins][vip] = skin.FetchInt(3);
		skin.FetchString(4, g_skins[iskins][model], PLATFORM_MAX_PATH);
		skin.FetchString(5, g_skins[iskins][arm], PLATFORM_MAX_PATH);
		g_skins[iskins][personid] = skin.FetchInt(6);

		if (!FileExists(g_skins[iskins][model]))
			continue;
		
		SetTrieValue(SkinIndex, g_skins[iskins][uid], iskins, true);

		// Precache Model
		PrecacheModel(g_skins[iskins][model], true);
		if (strlen(g_skins[iskins][arm]) > 3 && FileExists(g_skins[iskins][arm], true))
			PrecacheModel(g_skins[iskins][arm], true);

		iskins++;
	}

	g_bIsReady = true;
}

public void NP_OnClientDataChecked(int client, int UserIdentity)
{
	CreateRequest(GetSkinCacheCallback, "query.php", "\"SQL\":\"SELECT `uid`, skin_uid FROM np_skins_cache WHERE `uid` = %d\"", UserIdentity);
}

void GetSkinCacheCallback(bool success, const char[] error, System2HTTPRequest request, System2HTTPResponse response, HTTPRequestMethod method)
{
	if(!CheckRequest(success, error, request, response, method, "Skin", "GetSkinCacheCallback"))
		return;

	char[] content = new char[response.ContentLength + 1];
	response.GetContent(content, response.ContentLength + 1);
		
	Handle json;
	if ((json = json_load(content)) == INVALID_HANDLE)
	{
		NP_Core_LogError("Skin", "GetSkinCacheCallback", "Error: Json -> \"%s\"", content);
		return;
	}

	int client = NP_Users_FindUserByID(json_object_get_int(json, "uid"));
	if (!client)
		return;

	json_object_get_string(json, "skin_uid", g_iClientSkinCache[client], 32);

	CloseHandle(json);
	delete request;
}

public Action Event_PlayerSpawn(Event event, const char[] ename, bool dontBroadcast)
{
	if (!g_bIsReady)
		return Plugin_Continue;

	int client = GetClientOfUserId(event.GetInt("userid"));

	CreateTimer(0.2, Timer_SetModel, client);

	return Plugin_Continue;
}

void SetModel(int client)
{
	CreateTimer(0.02, Timer_SetModel, client);
}

public Action Timer_SetModel(Handle timer, int client)
{
	if(!IsClientInGame(client) || !IsPlayerAlive(client))
		return Plugin_Stop;
	
	//get cache skin uid	
	int index = GetSkinIndex(g_iClientSkinCache[client]);
	
	if(!index)
	{
		SetEntityModel(client, D_MODEL);
		SetEntPropString(client, Prop_Send, "m_hViewModel", D_ARM);
	}
	else
	{
		SetEntityModel(client, g_skins[index][model]);
		if(strlen(g_skins[index][arm]) > 3 && IsModelPrecached(g_skins[index][arm]))
			SetEntPropString(client, Prop_Send, "m_hViewModel", g_skins[index][arm]);
		else
			SetEntPropString(client, Prop_Send, "m_hViewModel", D_ARM);
	}
	
	return Plugin_Stop;
}

public Action Command_SkinsMenu(int client, int args)
{
	if(!IsValidClient(client))
		return;

	if (!g_bIsReady)
		return;

	Menu menu = new Menu(Menu_SkinSelected);
	menu.ExitButton = true;
	menu.SetTitle("选择你喜欢的模型");
	menu.AddItem("default", "默认皮肤");

	for (int i = 0; i < iskins; ++i)
	{
		if (g_skins[i][personid] != 0) // personal skin
			if(NP_Users_UserIdentity(client) == g_skins[i][personid])
				continue;

		if (g_skins[i][vip]) // vip skin
			if(!NP_Vip_IsVIP(client))
				continue;

		if (g_skins[i][op]) // op skin
			if(!IsClientOP(client))
				continue;
		
		menu.AddItem(g_skins[i][uid], g_skins[i][name]);
	}

	menu.Display(client, 60);
}

public int Menu_SkinSelected(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_End)
		delete menu;
	else if(action == MenuAction_Select)
	{
		if(!IsValidClient(param1))
			return;

		char skin_uid[32], handle[32], buffer[256];
		menu.GetItem(param2, skin_uid, 32, _, handle, 32);

		// Save model
		strcopy(g_iClientSkinCache[param1], 32, skin_uid);
		Format(buffer, 256, "UPDATE %s_skins_cache SET skin_uid = '%s' WHERE `uid` = %d", P_SQLPRE, skin_uid, NP_Users_UserIdentity(param1));
		NP_MySQL_SaveDatabase(buffer);
	
		if(IsPlayerAlive(param1))
			SetModel(param1);
	}
}

int GetSkinIndex(const char[] skin_uid)
{
	int i;
	if(SkinIndex != INVALID_HANDLE)
		if(GetTrieValue(SkinIndex, skin_uid, i))
			return i;
	return 0; //Can not find the skin uid
}

public Action Timer_Restart(Handle timer)
{
	LoadSkin();
}