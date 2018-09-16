#if !defined REQUIRE_PLUGIN
    #endinput
#endif

#if defined _NewPage_AllChat_Include_
    #endinput
#endif

#define _NewPage_AllChat_Include_

enum ChatType
{
    PlayerChat = 0,
    Announcement,
    Custom
}

native bool NP_AllChat_Msg(ChatType type, const char[] name, const char[] msg);