#define P_AUTHOR "NewPage Dev-Team"
#define P_VERSION "Alpha-v2.3"
#define P_URLS "https://new-page.cc"
#define P_PRE "NewPage Core System (NCS)"
#define P_SQLPRE "np"

#if !defined REQUIRE_PLUGIN
    #endinput
#endif

#if defined _NewPage_Core_Include_
    #endinput
#endif

#define _NewPage_Core_Include_

forward void NP_Core_OnInitialized(int serverId, int modId);

// core
native void NP_Core_LogError(const char[] module = "Global", const char[] func = "Invalid Function", const char[] msg, any ...);
native void NP_Core_LogMessage(const char[] module = "Global", const char[] func = "Invalid Function", const char[] msg, any ...);
native int  NP_Core_GetServerId();
native int  NP_Core_GetServerModId();

// database
native bool NP_MySQL_IsConnected();
native Database NP_MySQL_GetDatabase();
native void NP_MySQL_SaveDatabase(const char[] QueryString);

// socket
native bool NP_Socket_IsReady();
native bool NP_Socket_Write(const char[] sendString);
forward void NP_Socket_OnReceived(const char[] event, const char[] data, const int size);

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

/* return tick or cross */
stock void TickOrCross(bool res, char[] output)
{
    strcopy(output, 4, res ? "✔" : "✘");
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