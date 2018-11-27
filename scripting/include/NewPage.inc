#define AUTOLOAD_EXTENSIONS
#define REQUIRE_EXTENSIONS

#if !defined REQUIRE_PLUGIN
	#endinput
#endif

#if defined _NewPage_Core_Include_
	#endinput
#endif

#define _NewPage_Core_Include_

#define P_AUTHOR "NewPage Dev-Team"
#define P_VERSION "Alpha-v3.7"
#define P_URLS "https://new-page.xyz"
#define P_PRE "NewPage Core System (NCS)"
#define P_SQLPRE "np"
#define P_APIURL "http://127.0.0.1/ncs"
#define P_APIPORT 83

#include <system2>
#include <smjansson>
#include <NewPage/chat>
#include <NewPage/user>

#if defined _Insurgency_
	#include <NewPage/ins>
#endif

forward void NP_Core_OnInitialized(int serverId, int modId);

// core
native void NP_Core_LogError(const char[] module = "Global", const char[] func = "Invalid Function", const char[] msg, any ...);
native void NP_Core_LogMessage(const char[] module = "Global", const char[] func = "Invalid Function", const char[] msg, any ...);
native int  NP_Core_GetServerId();
native int  NP_Core_GetServerModId();

// database
native bool NP_MySQL_IsConnected();
native Database NP_MySQL_GetDatabase();
native bool NP_MySQL_SaveDatabase(const char[] QueryString);

forward void NP_Core_RconData(const char[] data, const char[] event);

public SharedPlugin __pl_core =
{
	name = "np-core",
	file = "np-core.smx",
	required = 1 // force requires
};

// funtions

stock int GetDay()
{
	char time[32];
	FormatTime(time, 32, "%Y%m%d", GetTime());
	return StringToInt(time);
}

/*  Check client validation  */
stock bool IsValidClient(int index)
{
	return (index > 0 && index <= MaxClients && IsClientInGame(index) && !IsFakeClient(index) && !IsClientSourceTV(index));
}

/* String.PadLeft */
stock void StringPad(int number, int length, char c, char[] output, int maxLen)
{
	char[] buffer = new char[length];
	IntToString(number, buffer, length);

	int padLen = length - strlen(buffer);
	for(int i = 0; i < padLen; ++i)
	{
		output[i] = c;
	}
	output[padLen] = '\0';

	StrCat(output, maxLen, buffer);
}

/*  Convert Steam64 To SteamID  */ 
stock void Steam64toSteamID(const char[] friendId, char[] steamid, int iLen)
{
	char[] szBase = "76561197960265728";
	char szSteam[18], szAccount[18];
	int iBorrow, iY, iZ, iTemp;

	strcopy(szSteam, 18, friendId);

	if(CharToNumber(szSteam[16]) % 2 == 1)
	{
		iY = 1;
		szSteam[16] = NumberToChar(CharToNumber(szSteam[16]) - 1);
	}
	
	for(int k = 16; k >= 0; k--)
	{
		if(iBorrow > 0)
		{
			iTemp = CharToNumber(szSteam[k]) - 1;
			
			if(iTemp >= CharToNumber(szBase[k]))
			{
				iBorrow = 0;
				szAccount[k] = NumberToChar(iTemp - CharToNumber(szBase[k]));
			}
			else
			{
				iBorrow = 1;
				szAccount[k] = NumberToChar((iTemp + 10) - CharToNumber(szBase[k]));
			}
		}
		else
		{
			if(CharToNumber(szSteam[k]) >= CharToNumber(szBase[k]))
			{
				iBorrow = 0;
				szAccount[k] = NumberToChar(CharToNumber(szSteam[k]) - CharToNumber(szBase[k]));
			}
			else
			{
				iBorrow = 1;
				szAccount[k] = NumberToChar((CharToNumber(szSteam[k]) + 10) - CharToNumber(szBase[k]));
			}
		}
	}
	
	iZ = StringToInt(szAccount);
	iZ /= 2;
	
	FormatEx(steamid, iLen, "STEAM_1:%d:%d", iY, iZ);
}

stock int NumberToChar(const int iNum)
{
	return '0' + ((iNum >= 0 && iNum <= 9) ? iNum : 0);
}

stock int CharToNumber(const int cNum)
{
	return (cNum >= '0' && cNum <= '9') ? (cNum - '0') : 0;
}

stock void GenerateRandomString(char[] buffer, int maxLen)
{
	// terminator
	maxLen--;

	char random[] = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ01234556789";
	int randlen = strlen(random) - 1;

	int n = 0;
	int c = 0;

	while(n < maxLen)
	{
		if(random[0] == '\0')
		{
			c = GetRandomInt(33, 126);
			buffer[n] = c;
		}
		else
		{
			c = GetRandomInt(0, randlen);
			buffer[n] = random[c];
		}

		n++;
	}

	buffer[maxLen] = '\0';
}

stock int FindClientBySteamId(AuthIdType authType, const char[] authId, bool validate = false)
{
	char steamId[32];
	for(int client = 1; client <= MaxClients; client++)
		if(IsValidClient(client))
			if(GetClientAuthId(client, authType, steamId, 32, validate))
				if(strcmp(steamId, authId) == 0)
					return client;

	return -1;
}

stock void StringToJson(char[] string, int length)
{
	ReplaceString(string, length, "\\", "\\\\");
	ReplaceString(string, length, "\"", "\\\"");
	TerminateNameUTF8(string);
}

stock void DrawPanelTextEx(Handle panel, const char[] fmt, any ...)
{
	char vf[256];
	VFormat(vf, 256, fmt, 3);
	DrawPanelText(panel, vf);
}

stock bool AddMenuItemEx(Handle menu, int style, const char[] info, const char[] display, any ...)
{
	char m_szBuffer[256];
	VFormat(m_szBuffer, 256, display, 5);
	return AddMenuItem(menu, info, m_szBuffer, style);
}

stock void CreateRequest(System2HTTPResponseCallback callback, const char[] url, const char[] data, any ...)
{
	char vf[1024], rcon[24], md5[33];
	FindConVar("rcon_password").GetString(rcon, 24);
	System2_GetStringMD5(rcon, md5, 33);
	VFormat(vf, 1024, data, 4);

	System2HTTPRequest httpRequest = new System2HTTPRequest(callback, "%s/%s", P_APIURL, url);
	httpRequest.Timeout = 30;
	httpRequest.SetHeader("Content-Type", "application/json");
	httpRequest.SetData("{\"ServerID\":%d,\"Token\":\"%s\",%s}", NP_Core_GetServerId(), md5, vf);
	httpRequest.SetPort(P_APIPORT);
	httpRequest.POST();
}

stock bool CheckRequest(bool success, const char[] error, System2HTTPRequest request, System2HTTPResponse response, HTTPRequestMethod method, const char[] module = "Global", const char[] func = "Invalid Function")
{
	char url[256];
	request.GetURL(url, sizeof(url));

	if (!success)
	{
		NP_Core_LogError(module, func, "ERROR: Couldn't retrieve URL %s - %d. Error: %s", url, method, error);
		CreateTimer(5.0, Timer_RetryRequest, request);
		return false;
	}
	
	char[] content = new char[response.ContentLength + 1];
	response.GetContent(content, response.ContentLength + 1);

	char source[1024];
	request.GetData(source, 1024);

	if (StrContains(content, "!###ERROR###!") != -1 || StrContains(content, "<b>Fatal error</b>") != -1 || StrContains(content, "<b>Warning</b>") != -1)
	{
		NP_Core_LogError(module, func, "ERROR: Couldn't sent data -> (%s) (%s)", source, content);
		delete request;
		return false;
	}

	return true;
}

public Action Timer_RetryRequest(Handle timer, System2HTTPRequest request)
{
	request.POST();
	return Plugin_Stop;
}

stock void ProcessColorString(char[] message, int maxLen)
{
	char game[32];
	GetGameFolderName(game, 32);

	if (!strcmp(game, "insurgency") || !strcmp(game, "doi"))
	{
		ReplaceString(message, maxLen, "{normal}",      "\x01", false);
		ReplaceString(message, maxLen, "{default}",     "\x01", false);
		ReplaceString(message, maxLen, "{white}",       "\x01", false);
		ReplaceString(message, maxLen, "{darkred}",     "\x088B0000FF", false);
		ReplaceString(message, maxLen, "{pink}",        "\x08FFC0CBFF", false);
		ReplaceString(message, maxLen, "{green}",       "\x083EFF3EFF", false);
		ReplaceString(message, maxLen, "{lime}",        "\x0800FF00FF", false);
		ReplaceString(message, maxLen, "{yellow}",      "\x08FFFF00FF", false);
		ReplaceString(message, maxLen, "{lightgreen}",  "\x0899FF99FF", false);
		ReplaceString(message, maxLen, "{lightred}",    "\x08FF4040FF", false);
		ReplaceString(message, maxLen, "{red}",         "\x08FF4040FF", false);
		ReplaceString(message, maxLen, "{gray}",        "\x08CCCCCCFF", false);
		ReplaceString(message, maxLen, "{grey}",        "\x08CCCCCCFF", false);
		ReplaceString(message, maxLen, "{olive}",       "\x089EC34FFF", false);
		ReplaceString(message, maxLen, "{orange}",      "\x08FFA500FF", false);
		ReplaceString(message, maxLen, "{silver}",      "\x08C0C0C0FF", false);
		ReplaceString(message, maxLen, "{lightblue}",   "\x08ADD8E6FF", false);
		ReplaceString(message, maxLen, "{blue}",        "\x0899CCFFFF", false);
		ReplaceString(message, maxLen, "{purple}",      "\x08800080FF", false);
		ReplaceString(message, maxLen, "{darkorange}",  "\x08FF8C00FF", false);
		ReplaceString(message, maxLen, "{name}",		"\x05", false);
	}
	else
	{
		ReplaceString(message, maxLen, "{normal}",      "\x01", false);
		ReplaceString(message, maxLen, "{default}",     "\x01", false);
		ReplaceString(message, maxLen, "{white}",       "\x01", false);
		ReplaceString(message, maxLen, "{darkred}",     "\x02", false);
		ReplaceString(message, maxLen, "{pink}",        "\x03", false);
		ReplaceString(message, maxLen, "{green}",       "\x04", false);
		ReplaceString(message, maxLen, "{lime}",        "\x05", false);
		ReplaceString(message, maxLen, "{yellow}",      "\x05", false);
		ReplaceString(message, maxLen, "{lightgreen}",  "\x06", false);
		ReplaceString(message, maxLen, "{lightred}",    "\x07", false);
		ReplaceString(message, maxLen, "{red}",         "\x07", false);
		ReplaceString(message, maxLen, "{gray}",        "\x08", false);
		ReplaceString(message, maxLen, "{grey}",        "\x08", false);
		ReplaceString(message, maxLen, "{olive}",       "\x09", false);
		ReplaceString(message, maxLen, "{orange}",      "\x10", false);
		ReplaceString(message, maxLen, "{silver}",      "\x0A", false);
		ReplaceString(message, maxLen, "{lightblue}",   "\x0B", false);
		ReplaceString(message, maxLen, "{blue}",        "\x0C", false);
		ReplaceString(message, maxLen, "{purple}",      "\x0E", false);
		ReplaceString(message, maxLen, "{darkorange}",  "\x0F", false);
	}
}

stock void CPrintToChat(int client, const char[] format, any...)
{
	char buffer[254];
	VFormat(buffer, sizeof(buffer), format, 3);
	ProcessColorString(buffer, sizeof(buffer));
	PrintToChat(client, "%s", buffer);
}

stock void CPrintToChatAll(const char[] format, any...)
{
	char buffer[254];

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			SetGlobalTransTarget(i);
			VFormat(buffer, sizeof(buffer), format, 2);
			ProcessColorString(buffer, sizeof(buffer));
			PrintToChat(i, "%s", buffer);
		}
	}
}

stock bool IsClientOP(int client)
{
	return NP_Users_IsAuthorized(client, Ctb) || NP_Users_IsAuthorized(client, Opt) || NP_Users_IsAuthorized(client, Adm) || NP_Users_IsAuthorized(client, Own);
}

stock void TerminateNameUTF8(char[] name)
{
	int len = strlen(name);
	for(int i = 0; i < len; i++)
	{
		int bytes = IsCharMB(name[i]);
		if(bytes > 1)
		{
			if(len - i < bytes)
			{
				name[i] = '\0';
				return;
			}

			i += bytes - 1;
		}
	}
}