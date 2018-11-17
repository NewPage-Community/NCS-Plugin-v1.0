#if defined _NewPage_Ins_Include_
    #endinput
#endif

#define _NewPage_Ins_Include_

forward void NP_Ins_OnPlayerResupplyed(int client);

public SharedPlugin __pl_ins =
{
	name = "np-ins",
	file = "np-ins.smx",
#if !defined REQUIRE_PLUGIN
    required = 0
#else
    required = 1
#endif
};