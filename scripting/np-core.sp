#pragma semicolon 1

#include <NewPage>

// game rules.
#include <sdktools_gamerules>

#define AUTOLOAD_EXTENSIONS
#define REQUIRE_EXTENSIONS

#include <smjansson>

#define P_NAME P_PRE ... " - Core"
#define P_DESC "Server initialization plugin"

public Plugin myinfo = 
{
	name        = P_NAME,
	author      = P_AUTHOR,
	description = P_DESC,
	version     = P_VERSION,
	url         = P_URLS
};


int g_iServerId = -1,
	g_iServerPort = 27015,
	g_iServerModId = -1;

bool g_bConnected = false;

static char g_szServerIp[24]  = "127.0.0.1",
			g_szRconPswd[24]  = "RCONPASSWORD",
			g_szHostName[128] = "NewPage Server";

Handle g_hOnInitialized = INVALID_HANDLE,
	g_hRconData = INVALID_HANDLE;

Database g_hSQL = null;

EngineVersion g_Engine = Engine_Unknown;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	// database
	CreateNative("NP_MySQL_IsConnected", Native_IsConnected);
	CreateNative("NP_MySQL_GetDatabase", Native_GetDatabase);
	CreateNative("NP_MySQL_SaveDatabase", Native_SaveDatabase);

	// core
	CreateNative("NP_Core_GetServerId",    Native_GetServerId);
	CreateNative("NP_Core_GetServerModId", Native_GetServerModId);
	
	// logs
	CreateNative("NP_Core_LogError",   Native_LogError);
	CreateNative("NP_Core_LogMessage", Native_LogMessage);

	// lib
	RegPluginLibrary("np-core");

	/* Init plugin */
	SetConVarInt(FindConVar("sv_hibernate_when_empty"), 0);
	g_Engine = GetEngineVersion();
	int ip = GetConVarInt(FindConVar("hostip"));
	FormatEx(g_szServerIp, 24, "%d.%d.%d.%d", ((ip & 0xFF000000) >> 24) & 0xFF, ((ip & 0x00FF0000) >> 16) & 0xFF, ((ip & 0x0000FF00) >>  8) & 0xFF, ((ip & 0x000000FF) >>  0) & 0xFF);
	g_iServerPort = GetConVarInt(FindConVar("hostport"));

	return APLRes_Success;
}

public int Native_IsConnected(Handle plugin, int numParams)
{
	return g_bConnected;
}

public int Native_GetDatabase(Handle plugin, int numParams)
{
	return view_as<int>(g_hSQL);
}

public int Native_SaveDatabase(Handle plugin, int numParams)
{
	// dynamic length
	int inLen = 0;
	GetNativeStringLength(1, inLen);
	char[] input = new char[inLen+1];
	if(GetNativeString(1, input, inLen+1) != SP_ERROR_NONE)
		return 0;

	char Token[33];
	GetToken(Token, 33);

	System2HTTPRequest httpRequest = new System2HTTPRequest(SaveSQLCallback, "%s/savesql.php", P_APIURL);
	httpRequest.Timeout = 30;
	httpRequest.SetHeader("Content-Type", "application/json");
	httpRequest.SetData("{\"ServerID\":%d,\"Token\":\"%s\",\"SQL\":\"%s\"}", g_iServerId, Token, input);
	httpRequest.SetPort(P_APIPORT);
	httpRequest.POST();

	return 1;
}

public int Native_GetServerId(Handle plugin, int numParams)
{
	return g_iServerId;
}

public int Native_GetServerModId(Handle plugin, int numParams)
{
	return g_iServerModId;
}

public int Native_LogError(Handle plugin, int numParams)
{
	char module[32], func[64], format[256];
	GetNativeString(1, module,  32);
	GetNativeString(2, func,    64);
	GetNativeString(3, format, 256);

	char error[2048];
	FormatNativeString(0, 0, 4, 2048, _, error, format);
	
	char path[128];
	BuildPath(Path_SM, path, 128, "logs/NewPage/%s_err.log", module);
	
	LogToFileEx(path, "[%s] -> %s", func, error);
}

public int Native_LogMessage(Handle plugin, int numParams)
{
	char module[32], func[64], format[256];
	GetNativeString(1, module,  32);
	GetNativeString(2, func,    64);
	GetNativeString(3, format, 256);

	char message[2048];
	FormatNativeString(0, 0, 4, 2048, _, message, format);
	
	char path[128];
	BuildPath(Path_SM, path, 128, "logs/NewPage/%s_msg.log", module);
	
	LogToFileEx(path, "[%s] -> %s", func, message);
}

public void OnPluginStart()
{
	RegServerCmd("np_restart", Command_Restart);
	RegServerCmd("np_rcondata", Command_RconData);

	// forwards
	g_hOnInitialized = CreateGlobalForward("NP_Core_OnInitialized",  ET_Ignore, Param_Cell, Param_Cell);
	g_hRconData = CreateGlobalForward("NP_Core_RconData",  ET_Ignore, Param_String, Param_String);

	// connections
	ConnectToDatabase(0);
	
	// log dir
	CheckLogsDirectory();
}

public void CheckLogsDirectory()
{
	char path[128];
	BuildPath(Path_SM, path, 128, "logs/NewPage");
	if(!DirExists(path))
		CreateDirectory(path, 755);
}

void ConnectToDatabase(int retry)
{
	// connected?
	if(g_bConnected)
		return;

	// not null
	if(g_hSQL != null)
	{
		g_bConnected = true;
		return;
	}

	Database.Connect(OnConnected, "default", retry);
}

public void OnConnected(Database db, const char[] error, int retry)
{
	if(db == null)
	{
		NP_Core_LogError("MySQL", "OnConnected", "Connect failed -> %s", error);
		if(++retry <= 10)
			CreateTimer(5.0, Timer_Reconnect, retry);
		else
			SetFailState("connect to database failed! -> %s", error);
		return;
	}

	g_hSQL = db;
	g_hSQL.SetCharset("utf8");
	g_bConnected = true;

	// Initialize
	CheckingServer();
	
	PrintToServer("Newpage Core - Initialized!");
}

public Action Timer_Reconnect(Handle timer, int retry)
{
	ConnectToDatabase(retry);
	return Plugin_Stop;
}

public void NativeSave_Callback(Database db, DBResultSet results, const char[] error, DataPack pack)
{
	if(results == null || error[0] || results.AffectedRows == 0)
	{
		char m_szQueryString[2048];
		pack.Reset();
		pack.ReadString(m_szQueryString, 2048);
		NP_Core_LogError("MySQL", "NativeSave_Callback", "SQL Error: %s\nQuery: %s", (results == null || error[0]) ? error : "No affected row", m_szQueryString);
	}

	delete pack;
}

void CheckingServer()
{
	char m_szQuery[128];
	FormatEx(m_szQuery, 128, "SELECT * FROM `%s_servers` WHERE `ip`='%s' AND `port`='%d'", P_SQLPRE, g_szServerIp, g_iServerPort);
	DBResultSet _result = SQL_Query(g_hSQL, m_szQuery);
	if(_result == null)
	{
		char error[256];
		SQL_GetError(g_hSQL, error, 256);
		NP_Core_LogError("MySQL", "CheckingServer", "Query Server Info: %s", error);
		RetrieveInfoFromKV();
		return;
	}
	
	if(!_result.FetchRow())
	{
		AddNewServer();
		return;
	}
	
	g_iServerId = _result.FetchInt(0);
	g_iServerModId = _result.FetchInt(1);
	_result.FetchString(2, g_szHostName, 128);
	
	delete _result;

	ChangeHostname(g_szHostName);

	SaveInfoToKV();

	// we used random rcon password.
	GenerateRandomString(g_szRconPswd, 24);

	SetConVarString(FindConVar("rcon_password"), g_szRconPswd, false, false);
	HookConVarChange(FindConVar("rcon_password"), RconProtect);

	// sync to database
	FormatEx(m_szQuery, 128, "UPDATE `%s_servers` SET `rcon`='%s' WHERE `sid`='%d';", P_SQLPRE, g_szRconPswd, g_iServerId);
	if(!SQL_FastQuery(g_hSQL, m_szQuery, 128))
	{
		char error[256];
		SQL_GetError(g_hSQL, error, 256);
		NP_Core_LogError("MySQL", "CheckingServer", "Update RCON password: %s", error); 
	}

	Call_StartForward(g_hOnInitialized);
	Call_PushCell(g_iServerId);
	Call_PushCell(g_iServerModId);
	Call_Finish();
}

void RetrieveInfoFromKV()
{
	char path[128];
	BuildPath(Path_SM, path, 128, "configs/NewPage/core.cfg");
	
	if(!FileExists(path))
		SetFailState("Connect to database error and kv NOT FOUND");
	
	KeyValues kv = new KeyValues("NewPage");
	
	if(!kv.ImportFromFile(path))
		SetFailState("Connect to database error and kv load failed!");
	
	g_iServerId = kv.GetNum("serverid", -1);
	g_iServerModId = kv.GetNum("modid", -1);
	kv.GetString("hostname", g_szHostName, 128, "NewPage Server");

	if(g_Engine == Engine_CSGO) 
	{ 
		// fix host name in gotv 
		ConVar host_name_store = FindConVar("host_name_store"); 
		if(host_name_store != null) 
			host_name_store.SetString("1", false, false); 
	} 

	SetConVarString(FindConVar("hostname"), g_szHostName, false, false); 
	
	delete kv;
	
	if(g_iServerId == -1)
		SetFailState("Why your server id still is -1");
}

void SaveInfoToKV()
{
	KeyValues kv = new KeyValues("NewPage");
	
	kv.SetNum("serverid", g_iServerId);
	kv.SetNum("modid", g_iServerModId);
	kv.SetString("hostname", g_szHostName);
	kv.Rewind();

	char path[128];
	BuildPath(Path_SM, path, 128, "configs/NewPage/core.cfg");
	kv.ExportToFile(path);
	
	delete kv;
}

public void OnMapStart()
{
	// fake offical server
	if(g_Engine == Engine_CSGO)
		GameRules_SetProp("m_bIsValveDS", 1, 0, 0, true);

	ChangeHostname(g_szHostName);
	CreateTimer(3.0, Timer_CheckCvar);
}

void ChangeHostname(char[] hostname)
{
	if(g_Engine == Engine_CSGO)
	{
		// fix host name in gotv
		ConVar host_name_store = FindConVar("host_name_store");
		if(host_name_store != null)
			host_name_store.SetString("1", false, false);
	}

	SetConVarString(FindConVar("hostname"), hostname, false, false);
}

void AddNewServer()
{
	char m_szQuery[128];
	FormatEx(m_szQuery, 128, "INSERT INTO `%s_servers` VALUES (DEFAULT, DEFAULT, DEFAULT, '%s', '%d', DEFAULT);", P_SQLPRE, g_szServerIp, g_iServerPort);
	if(!SQL_FastQuery(g_hSQL, m_szQuery, 128))
	{
		char error[256];
		SQL_GetError(g_hSQL, error, 256);
		NP_Core_LogError("MySQL", "AddNewServer", "AddNewServer Info: %s", error); 
		return;
	}

	CheckingServer();
}

void CheckCvar()
{
	if (g_hSQL == null)
	{
		NP_Core_LogError("Core", "CheckCvar", "Database is unavailable now");
		CreateTimer(1.0, Timer_CheckCvar);
		return;
	}

	char m_szQuery[128];
	FormatEx(m_szQuery, 128, "SELECT * FROM `%s_cvars`", P_SQLPRE);
	DBResultSet _result = SQL_Query(g_hSQL, m_szQuery);
	if(_result == null)
	{
		char error[256];
		SQL_GetError(g_hSQL, error, 256);
		NP_Core_LogError("Core", "CheckCvar", "Can't get cvar from database: %s", error);
		RetrieveInfoFromKV();
		return;
	}
	
	char _key[32], _val[128];
	while(_result.FetchRow())
	{
		_result.FetchString(0, _key,  32);
		_result.FetchString(1, _val, 128);

		ConVar cvar = FindConVar(_key);
		if(cvar != null)
			cvar.SetString(_val, true, false);
	}
}

public Action Timer_CheckCvar(Handle timer, int client)
{
	CheckCvar();
	return Plugin_Handled;
}

void SaveSQLCallback(bool success, const char[] error, System2HTTPRequest request, System2HTTPResponse response, HTTPRequestMethod method)
{
	char url[256];
	request.GetURL(url, sizeof(url));

	if (!success)
	{
		NP_Core_LogError("Core", "SaveSQLCallback", "ERROR: Couldn't retrieve URL %s - %d. Error: %s", url, method, error);
		CreateTimer(5.0, Timer_RetryRequest, request);
		return;
	}
	
	char[] content = new char[response.ContentLength + 1];
	response.GetContent(content, response.ContentLength + 1);

	if (StringToInt(content) == -1)
	{
		NP_Core_LogError("Core", "SaveSQLCallback", "ERROR: Couldn't Save SQL data -> %s", content);
		delete request;
		return;
	}

	delete request;
}

public Action Timer_RetryRequest(Handle timer, System2HTTPRequest request)
{
	request.POST();
	return Plugin_Stop;
}

public Action Command_Restart(int args)
{
	PrintToChatAll("\x04[提示] \x01服务器将进行重启更新!");
	PrintCenterTextAll("服务器将进行重启更新!");
	CreateTimer(1.0, Timer_Restart, 0);
}

public Action Timer_Restart(Handle timer, int time)
{
	if(time < 10)
	{
		PrintToChatAll("\x04[提示] \x01服务器将在 \x04%ds\x01 后重启!", 10 - time);
		PrintCenterTextAll("服务器将在 %ds 后重启!", 10 - time);
		CreateTimer(1.0, Timer_Restart, time + 1);
		return Plugin_Stop;
	}

	for(int i = 1; i <= GetMaxClients(); i++)
		if (IsClientInGame(i))
				ClientCommand(i, "retry");

	ServerCommand("quit");

	return Plugin_Stop;
}

public Action Command_RconData(int args)
{
	char data[512];
	GetCmdArgString(data, 512);

	Handle json = json_load(data);

	if(json == INVALID_HANDLE)
	{
		NP_Core_LogError("Core", "RconData", "Error: Json -> %s", data);
		return;
	}

	char event[16];
	json_object_get_string(json, "Event", event, 16);
	CloseHandle(json);

	Call_StartForward(g_hRconData);
	Call_PushString(data);
	Call_PushString(event);
	Call_Finish();
}

void RconProtect(ConVar convar, const char[] oldValue, const char[] newValue)
{
	PrintToServer("RconProtect : %s -> %s", oldValue, newValue);
	SetConVarString(convar, g_szRconPswd, false, false);
}