#pragma semicolon 1

#include <sdktools>
#include <NewPage>
#include <NewPage/user>
#include <NewPage/ins>

#define P_NAME P_PRE ... " - NewYear"
#define P_DESC "Happy new year"

int newyear = 1546272000; //New Year time

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
	newyearmessage[2] = "为大家献上一首《Pianophonic》！";
	newyearmessage[3] = "希望大家能在新的一年里心想事成、学业进步、工作顺利！";
	newyearmessage[4] = "NewPage社区很高兴继续为大家提供优质的游戏环境！";
	newyearmessage[5] = "NewPage社区管理团队致敬~";
}

public void OnMapStart()
{
	PrecacheSound("newpage/pianophonic.ogg");
	AddFileToDownloadsTable("sound/newpage/pianophonic.ogg");
}

public Action NewYearCheck(Handle timer)
{
	int time = GetTime();

	if (time >= newyear - 11 && time <= newyear)
	{
		CreateTimer(1.0, NewYearCount, 0, TIMER_REPEAT);
		return Plugin_Stop;
	}

	return Plugin_Continue;
}

public void NP_OnClientSigned(int client, int signtimes)
{
	if (GetTime() > newyear && GetTime() < (newyear + 86400))
	{
		if (GetTime() < (newyear + 300))
		{
			CPrintToChat(client, "{green}[系统提示] {blue}感谢您本社区服务器跨年！奖励你 \x05500{blue} 软妹币!");
			NP_Users_GiveMoney(client, 500);
		}

		SetRandomSeed(GetTime());
		int ranrmb = GetRandomInt(500, 3000);
		CPrintToChat(client, "{green}[系统提示] {blue}新年快乐! 奖励你 \x05%i {blue}软妹币!", ranrmb);
		NP_Users_GiveMoney(client, ranrmb);
	}
}

public Action NewYearCount(Handle timer)
{
	int time = GetTime();

	if(time >= newyear)
	{
		CreateTimer(4.0, HappyNewYear, 0);
		CPrintToChatAll("{green}[系统提示] {blue}现在聊天输入指令 {red}!qd{blue} 进行签到，可获得丰厚奖励哦~");
		PlayGameSoundToAll("newpage/pianophonic.ogg");
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
	if (times > 5)
		return Plugin_Stop;

	CPrintToChatAll("{green}[系统提示] {blue}%s", newyearmessage[times]);
	if (GetEngineVersion() == Engine_Insurgency)
		for (int i = 1; i <= MaxClients; i++)
			NP_Ins_DisplayInstructorHint(i, 5.0, 0.0, 3.0, true, true, "icon_tip", "icon_tip", "", true, {255, 255, 255}, newyearmessage[times]);
	else
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