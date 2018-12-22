#pragma semicolon 1

#include <sdktools>
#include <NewPage>

#define P_NAME P_PRE ... " - NewYear"
#define P_DESC "Happy new year"

int newyear = 1546272000;
int bntime[MAXPLAYERS + 1];

char newyearmessage[6][128];

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
	CreateTimer(0.1, NewYearCheck, 0, TIMER_REPEAT);

	newyearmessage[0] = "NewPage社区在这里祝各位新年快乐！Happy New Year~";
	newyearmessage[1] = "很高兴各位能在本社区服务器跨年！";
	newyearmessage[2] = "为大家献上一首《好运来》，祝大家好运！";
	newyearmessage[3] = "希望大家能在新的一年里心想事成、学业进步、工作顺利！";
	newyearmessage[4] = "NewPage社区很高兴继续为大家提供优质的游戏环境！";
	newyearmessage[5] = "NewPage社区管理团队致敬~";
}

public void OnMapStart()
{
	PrecacheSound("newpage/haoyunlai.ogg");
	AddFileToDownloadsTable("sound/newpage/haoyunlai.ogg");
}

public Action NewYearCheck(Handle timer)
{
	int time = GetTime();

	if (time >= newyear - 11 && time < (newyear + 61))
	{
		CreateTimer(1.0, NewYearCount, 0, TIMER_REPEAT);
		return Plugin_Stop;
	}

	return Plugin_Continue;
}

public Action OnClientSayCommand(int client, const char[] command, const char[] text)
{
	if (client > 0 && StrContains(command, "say") != -1)
	{
		if (GetTime() > newyear && GetTime() < (newyear + 61))
		{
			if (StrContains(text, "新年快乐", false) != -1)
			{
				if (bntime[client] < newyear)
				{
					SetRandomSeed(GetTime());
					int ranrmb = GetRandomInt(500, 3000);
					CPrintToChat(client, "{green}[系统提示] {blue}新年快乐! 奖励你 {red}%i {blue}软妹币!", ranrmb);
					bntime[client] = GetTime();
					NP_Users_GiveMoney(client, ranrmb);
				}
			}
		}
	}
	return Plugin_Continue;
}

public Action NewYearCount(Handle timer)
{
	int time = GetTime();

	if(time >= newyear)
	{
		CreateTimer(4.0, HappyNewYear, 0);
		CPrintToChatAll("{green}[系统提示] {blue}聊天输入含 {red}新年快乐{blue} 的贺词可获得奖励！（全服聊天无效）");
		PlayGameSoundToAll("newpage/haoyunlai.ogg");
		return Plugin_Stop;
	}
	else
	{
		CPrintToChatAll("{green}[系统提示] {blue}新年倒数：{red}%i", newyear - time);
	}

	return Plugin_Continue;
}

public Action HappyNewYear(Handle timer, int times)
{
	if (times > 6)
		return Plugin_Stop;

	CPrintToChatAll("{green}[系统提示] {blue}%s", newyearmessage[times]);
	PrintHintTextToAll("%s", newyearmessage[times]);

	CreateTimer(4.0, HappyNewYear, ++times);

	return Plugin_Continue;
}

void PlayGameSoundToAll(const char[] sample)
{
	for (int j = 1;j < MaxClients; j++)
		if (IsClientInGame(j))
			ClientCommand(j, "playgamesound %s", sample);
}