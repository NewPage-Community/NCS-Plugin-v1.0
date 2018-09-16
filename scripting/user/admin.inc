void LoadAdmin(int client, const char[] steamid)
{
	if (g_aClient[client][Auth][Vip] || g_aClient[client][Auth][Ctb] || g_aClient[client][Auth][Opt] || g_aClient[client][Auth][Adm] || g_aClient[client][Auth][Own])
	{
		AdminId _adminId;
		char auth[32];

		Steam64toSteamID(steamid, auth, 32);

		if ((_adminId = FindAdminByIdentity(AUTHMETHOD_STEAM, auth)) != INVALID_ADMIN_ID)
		{
			RemoveAdmin(_adminId);
			_adminId = INVALID_ADMIN_ID;
		}

		_adminId = CreateAdmin(g_aClient[client][Name]);
		if (!_adminId.BindIdentity(AUTHMETHOD_STEAM, auth))
		{
			RemoveAdmin(_adminId);
			NP_Core_LogError("User", "LoadAdmin", "Failed to bind admin \"%s\" to identity \"%s\"", g_aClient[client][Name], auth);
			return;
		}

		_adminId.SetFlag(Admin_Reservation, true);
		_adminId.SetFlag(Admin_Custom1, true); // vip use "o" flag

		if (g_aClient[client][Auth][Ctb] || g_aClient[client][Auth][Opt] || g_aClient[client][Auth][Adm] || g_aClient[client][Auth][Own])
		{
			_adminId.SetFlag(Admin_Generic, true);
			_adminId.SetFlag(Admin_Kick, true);
			_adminId.SetFlag(Admin_Slay, true);
			_adminId.SetFlag(Admin_Chat, true);
			_adminId.SetFlag(Admin_Vote, true);
			_adminId.SetFlag(Admin_Changemap, true);

			if(g_aClient[client][Auth][Opt] || g_aClient[client][Auth][Adm] || g_aClient[client][Auth][Own])
			{
				_adminId.SetFlag(Admin_Ban, true);
				_adminId.SetFlag(Admin_Unban, true);

				if(g_aClient[client][Auth][Adm] || g_aClient[client][Auth][Own])
				{
					_adminId.SetFlag(Admin_Convars, true);
					_adminId.SetFlag(Admin_Config, true);

					if(g_aClient[client][Auth][Own])
					{
						_adminId.SetFlag(Admin_Password, true);
						_adminId.SetFlag(Admin_Cheats, true);
						_adminId.SetFlag(Admin_RCON, true);
						_adminId.SetFlag(Admin_Root, true);
						SetAdminImmunityLevel(_adminId, 99);
					}
				}
			}
		}

		if(IsClientInGame(client))
			RunAdminCacheChecks(client);
	}
}

void AdminLog(int client, const char[] message)
{
	if (client < 1 || GetUserAdmin(client) == INVALID_ADMIN_ID || !NP_Users_IsAuthLoaded(client))
		return;

	char m_szQuery[1024], msg[512];
	NP_MySQL_GetDatabase().Escape(message, msg, 512);
	StringToJson(msg, 512);
	Format(m_szQuery, 1024, "INSERT INTO `%s_adminlog` VALUES (DEFAULT, %d, %d, '%s', DEFAULT)", P_SQLPRE, NP_Users_UserIdentity(client), NP_Core_GetServerId(), msg);
	NP_MySQL_SaveDatabase(m_szQuery);
}