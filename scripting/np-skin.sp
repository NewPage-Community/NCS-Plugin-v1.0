#pragma semicolon 1

#define _Insurgency_

#include <NewPage>
#include <sdktools_functions>

#define MAX_SKINS 64

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
#define P_DESC "Skin plugin - Ins ver"

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
}

public void OnMapStart()
{
	LoadSkin();
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

	iskins = 0;

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

		iskins++;
	}

	g_bIsReady = true;
}

public void NP_OnClientDataChecked(int client, int UserIdentity)
{
	CreateRequest(GetSkinCacheCallback, "skin.php", "\"GetCache\":1, \"UID\":%d", UserIdentity);
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

public void OnClientDisconnect(int client)
{
	g_iClientSkinCache[client][0] = '\0';
}

public Action Timer_SetModel(Handle timer, int client)
{
	if(!IsClientInGame(client) || !IsPlayerAlive(client) || IsFakeClient(client))
		return Plugin_Stop;

	if(strcmp(g_iClientSkinCache[client], "default") != 0 && g_iClientSkinCache[client][0] != '\0')
	{
		int index = GetSkinIndex(g_iClientSkinCache[client]);
		SetEntityModel(client, g_skins[index][model]);
	}
	
	return Plugin_Stop;
}

public Action Command_SkinsMenu(int client, int args)
{
	if(!IsValidClient(client))
		return Plugin_Handled;

	if (!g_bIsReady)
		return Plugin_Handled;

	Menu menu = new Menu(Menu_SkinSelected);
	menu.ExitButton = true;
	menu.SetTitle("选择你喜欢的模型");
	menu.AddItem("default", "默认皮肤");

	for (int i = 0; i < iskins; ++i)
	{
		if (SkinAccess(client, i))
			menu.AddItem(g_skins[i][uid], g_skins[i][name]);
	}

	menu.Display(client, 60);
	return Plugin_Handled;
}

public int Menu_SkinSelected(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_End)
		delete menu;
	else if(action == MenuAction_Select)
	{
		if(!IsValidClient(param1))
			return;

		char skin_uid[32], skin_name[32];
		menu.GetItem(param2, skin_uid, 32, _, skin_name, 32);

		// Save model
		strcopy(g_iClientSkinCache[param1], 32, skin_uid);
		CreateRequest(SetSkinCacheCallback, "skin.php", "\"SetCache\":\"%s\", \"UID\":\"%d\"",skin_uid , NP_Users_UserIdentity(param1));
	
		//if(IsPlayerAlive(param1))
			//SetModel(param1);

		CPrintToChat(param1, "\x04[提示]\x01 已成功更换为 {lime}%s\x01！部署生效，可通过 {olive}!tp\x01 查看模型", skin_name);
	}
}

void SetSkinCacheCallback(bool success, const char[] error, System2HTTPRequest request, System2HTTPResponse response, HTTPRequestMethod method)
{
	if(!CheckRequest(success, error, request, response, method, "Skin", "SetSkinCacheCallback"))
		return;
	delete request;
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

bool SkinAccess(int client, int skinid)
{
	if (NP_Users_IsAuthorized(client, Own)) // All YES!!!!
		return true;
	
	if (g_skins[skinid][personid] != 0) // personal skin
		if (NP_Users_UserIdentity(client) != g_skins[skinid][personid])
			return false;

	if (g_skins[skinid][vip]) // vip skin
		if(!NP_Vip_IsVIP(client) && !IsClientOP(client))
			return false;
			
	if (g_skins[skinid][op]) // op skin
		if(!IsClientOP(client))
			return false;

	return true;
}

public void NP_Ins_OnPlayerResupplyed(int client)
{
	if (!g_bIsReady)
		return;

	CreateTimer(0.2, Timer_SetModel, client);
}