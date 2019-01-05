void RegCommand()
{
	RegConsoleCmd("sm_info", Command_UserInfo);
	RegConsoleCmd("sm_sign", Command_Sign);
	RegConsoleCmd("sm_qd", Command_Sign);
	RegConsoleCmd("sm_prefix", Command_Prefix);
	RegAdminCmd("sm_ban", Command_Ban, ADMFLAG_BAN);
	RegAdminCmd("sm_addban", Command_AddBan, ADMFLAG_BAN);
}