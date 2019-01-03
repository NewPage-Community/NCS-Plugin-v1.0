#if defined _NewPage_Ins_Include_
    #endinput
#endif

#define _NewPage_Ins_Include_

#include <sdktools>

enum INS_GameState
{
	StartGame = 0,
	GamemodeReset,
	GamemodeStarted,
	RoundDraw,
	SecurityWin,
	InsurgentWin,
	RoundResult,
	PreRoundReset,
	RoundReset,
	RoundStarted,
	GameOver
}

forward void NP_Ins_OnPlayerResupplyed(int client);

public SharedPlugin __pl_ins =
{
	name = "np-ins",
	file = "np-ins.smx",
    required = 0
};

/* Available icons
	"icon_bulb"
	"icon_caution"
	"icon_alert"
	"icon_alert_red"
	"icon_tip"
	"icon_skull"
	"icon_no"
	"icon_run"
	"icon_interact"
	"icon_button"
	"icon_door"
	"icon_arrow_plain"
	"icon_arrow_plain_white_dn"
	"icon_arrow_plain_white_up"
	"icon_arrow_up"
	"icon_arrow_right"
	"icon_fire"
	"icon_present"
	"use_binding"
*/
// Range = 0.0 for all range 
stock void NP_Ins_DisplayInstructorHint(int iTargetEntity, float fTime, float fHeight, float fRange, bool bFollow, bool bShowOffScreen, char[] sIconOnScreen, char[] sIconOffScreen, char[] sCmd, bool bShowTextAlways, int iColor[3], char[] sText)
{
	int iEntity = CreateEntityByName("env_instructor_hint");
	if(iEntity <= 0)
		return;
		
	char sBuffer[32];
	FormatEx(sBuffer, sizeof(sBuffer), "%d", iTargetEntity);
	
	// Target
	DispatchKeyValue(iTargetEntity, "targetname", sBuffer);
	DispatchKeyValue(iEntity, "hint_target", sBuffer);
	
	// Static
	FormatEx(sBuffer, sizeof(sBuffer), "%d", !bFollow);
	DispatchKeyValue(iEntity, "hint_static", sBuffer);
	
	// Timeout
	FormatEx(sBuffer, sizeof(sBuffer), "%d", RoundToFloor(fTime));
	DispatchKeyValue(iEntity, "hint_timeout", sBuffer);
	
	// Height
	FormatEx(sBuffer, sizeof(sBuffer), "%d", RoundToFloor(fHeight));
	DispatchKeyValue(iEntity, "hint_icon_offset", sBuffer);
	
	// Range
	FormatEx(sBuffer, sizeof(sBuffer), "%d", RoundToFloor(fRange));
	DispatchKeyValue(iEntity, "hint_range", sBuffer);
	
	// Show off screen
	FormatEx(sBuffer, sizeof(sBuffer), "%d", !bShowOffScreen);
	DispatchKeyValue(iEntity, "hint_nooffscreen", sBuffer);
	
	// Icons
	DispatchKeyValue(iEntity, "hint_icon_onscreen", sIconOnScreen);
	DispatchKeyValue(iEntity, "hint_icon_offscreen", sIconOffScreen);
	
	// Command binding
	DispatchKeyValue(iEntity, "hint_binding", sCmd);
	
	// Show text behind walls
	FormatEx(sBuffer, sizeof(sBuffer), "%d", bShowTextAlways);
	DispatchKeyValue(iEntity, "hint_forcecaption", sBuffer);
	
	// Text color
	FormatEx(sBuffer, sizeof(sBuffer), "%d %d %d", iColor[0], iColor[1], iColor[2]);
	DispatchKeyValue(iEntity, "hint_color", sBuffer);
	
	//Text
	ReplaceString(sText, 254, "\n", " ");
	Format(sText, 254, "%s", sText);
	DispatchKeyValue(iEntity, "hint_caption", sText);

	if (fTime > 0.0)
	{
		Format(sBuffer, sizeof(sBuffer), "OnUser1 !self:kill::%f:1", fTime);
		SetVariantString(sBuffer);
		AcceptEntityInput(iEntity, "AddOutput");
		AcceptEntityInput(iEntity, "FireUser1");
	}
	
	DispatchSpawn(iEntity);
	AcceptEntityInput(iEntity, "ShowHint");
}

stock void SetGameState(INS_GameState state)
{
	GameRules_SetProp("m_iGameState", view_as<int>(state));
}

stock int GetGameState()
{
	return view_as<INS_GameState>(GameRules_GetProp("m_iGameState"));
}

stock int GetCounterAttack()
{
	return GameRules_GetProp("m_bCounterAttack");
}

stock bool GetTimerPause()
{
	return !GameRules_GetProp("m_bTimerPaused") ? false : true;
}

stock float GetRoundLengthTime()
{
	return GameRules_GetPropFloat("m_flRoundLength");
}

stock float GetRoundStartTime()
{
	return GameRules_GetPropFloat("m_flRoundStartTime");
}

stock bool SetTimerPause(bool pause)
{
	GameRules_SetProp("m_bTimerPaused", pause);
	return pause;
}

stock float SetRoundTime(Float:time)
{
	return GameRules_SetPropFloat("m_flRoundLength", (GetGameTime()-GameRules_GetPropFloat("m_flRoundStartTime"))+time);
}

stock float GetRoundTime()
{
	return GameRules_GetPropFloat("m_flRoundLength")-(GetGameTime()-GameRules_GetPropFloat("m_flRoundStartTime"));
}