#if defined _NewPage_Chat_Include_
    #endinput
#endif

#define _NewPage_Chat_Include_

#define MAXLENGTH_FLAG		32
#define MAXLENGTH_NAME		128
#define MAXLENGTH_MESSAGE	128
#define MAXLENGTH_BUFFER	255

enum ChatType
{
    PlayerChat = 0,
    Announcement,
    Custom
}

native bool NP_AllChat_Msg(ChatType type, const char[] name, const char[] msg);

native void NP_Chat_SetNameColor(int client, const char[] colorname);

public SharedPlugin __pl_chat =
{
	name = "np-chat",
	file = "np-chat.smx",
#if !defined REQUIRE_PLUGIN
    required = 0
#else
    required = 1
#endif
};

stock void CSayText2(int iClient, char[] sMessage, int iAuthor, bool bChat = true)
{
	Handle hMsg = StartMessageOne("SayText2", iClient, USERMSG_RELIABLE|USERMSG_BLOCKHOOKS);
	if(GetFeatureStatus(FeatureType_Native, "GetUserMessageType") == FeatureStatus_Available && GetUserMessageType() == UM_Protobuf) {
		PbSetInt(hMsg, "ent_idx", iAuthor);
		PbSetBool(hMsg, "chat", bChat);
		PbSetString(hMsg, "msg_name", sMessage);
		PbAddString(hMsg, "params", "");
		PbAddString(hMsg, "params", "");
		PbAddString(hMsg, "params", "");
		PbAddString(hMsg, "params", "");
	} else {
		BfWriteByte(hMsg, iAuthor);
		BfWriteByte(hMsg, true);
		BfWriteString(hMsg, sMessage);
	}
	EndMessage();
}

stock void SendPlayerMessage(int iClient, char[] sMessage, int iAuthor  = 0)
{
	if (iAuthor < 1 || iAuthor > MaxClients || !IsClientInGame(iAuthor)) {
		PrintToChat(iClient, sMessage);

		if (iAuthor != 0) {
			LogError("Client %d is not valid or in game", iAuthor);
		}
	} else {
		CSayText2(iClient, sMessage, iAuthor);
	}
}
