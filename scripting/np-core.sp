#pragma semicolon 1

#include <NewPage>

// game rules.
#include <sdktools_gamerules>

#define AUTOLOAD_EXTENSIONS
#define REQUIRE_EXTENSIONS

#include <async_socket>
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
	g_iServerModId = -1,
	g_iSocketRetry = 0,
	g_iSSPort = 23000;

bool g_bConnected = false,
	g_bSocketReady = false;

static char g_szServerIp[24]  = "127.0.0.1";
static char g_szRconPswd[24]  = "RCONPASSWORD";
static char g_szHostName[128] = "NewPage Server";
static char g_sSSIP[24] = "127.0.0.1";

Handle g_hOnInitialized = INVALID_HANDLE;
Handle g_hOnSocketReceived = INVALID_HANDLE;

Database g_hSQL = null;

EngineVersion g_Engine = Engine_Unknown;

AsyncSocket g_hSocket;

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

	// socket
	CreateNative("NP_Socket_Write", Native_SocketWrite);
	CreateNative("NP_Socket_IsReady", Native_SocketReady);

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

public int Native_SocketReady(Handle plugin, int numParams)
{
	return g_bSocketReady;
}

public int Native_SocketWrite(Handle plugin, int numParams)
{
	if(g_hSocket == null)
		return 0;

	// dynamic length
	int inLen = 0;
	GetNativeStringLength(1, inLen);
	char[] input = new char[inLen+1];
	if(GetNativeString(1, input, inLen+1) != SP_ERROR_NONE)
		return 0;

	return g_hSocket.Write(input);
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
	if(g_hSocket == null)
		return 0;

	// dynamic length
	int inLen = 0;
	GetNativeStringLength(1, inLen);
	char[] input = new char[inLen+1];
	if(GetNativeString(1, input, inLen+1) != SP_ERROR_NONE)
		return 0;

	char buff [1024];
	FormatEx(buff, 1024, "{\"Event\":\"SQLSave\",\"SQLSave\":\"%s\"}", input);
	return g_hSocket.Write(buff);
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
	// forwards
	g_hOnInitialized = CreateGlobalForward("NP_Core_OnInitialized",  ET_Ignore, Param_Cell, Param_Cell);
	g_hOnSocketReceived = CreateGlobalForward("NP_Socket_OnReceived",  ET_Ignore, Param_String, Param_String, Param_Cell);

	// connections
	ConnectToDatabase(0);
	
	// log dir
	CheckLogsDirectory();

	// Connect to socket server
	ConnectToSocketServer();
}

public void OnPluginEnd()
{
	CloseHandle(g_hSQL);
	CloseHandle(g_hSocket);
}

void ConnectToSocketServer()
{
	if(++g_iSocketRetry > 10)
	{
		NP_Core_LogError("Socket", "ConnectToSocketServer", "Connect to socket server failed!");
		return;
	}

	g_hSocket = new AsyncSocket();
	g_hSocket.Connect(g_sSSIP, g_iSSPort);
	if(g_hSocket != null)
	{
		g_hSocket.SetConnectCallback(OnSocketConnected);
		g_hSocket.SetErrorCallback(SocketErrorCallback);
		g_hSocket.SetDataCallback(OnSocketReceived);
	}
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
	CheckCvar();
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

public void OnSocketConnected(AsyncSocket socket)
{
	g_bSocketReady = true;
	g_iSocketRetry = 0;
	PrintToServer("Newpage Core - Socket server connected!");
}

public void SocketErrorCallback(AsyncSocket socket, int error, const char[] errorName)
{
	NP_Core_LogError("Socket", "SocketErrorCallback", "%d - %s", error, errorName);
	// Server close the connect
	if(error == -4077 || error == -4078)
	{
		g_bSocketReady = false;
		CloneHandle(socket);
		CreateTimer(5.0, Timer_SocketReconnect);
	}
}

public Action Timer_SocketReconnect(Handle timer)
{
	ConnectToSocketServer();
	return Plugin_Stop;
}

public void OnSocketReceived(AsyncSocket socket, const char[] data, const int size)
{
	Handle json = json_load(data);

	if(json == INVALID_HANDLE)
		return;

	char event[16];
	json_object_get_string(json, "Event", event, 16);
	CloseHandle(json);

	Call_StartForward(g_hOnSocketReceived);
	Call_PushString(event);
	Call_PushString(data);
	Call_PushCell(size);
	Call_Finish();
}

void CheckCvar()
{
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
		_result.FetchString(1, _key,  32);
		_result.FetchString(2, _val, 128);

		ConVar cvar = FindConVar(_key);
		if(cvar != null)
			cvar.SetString(_val, true, false);
	}
}