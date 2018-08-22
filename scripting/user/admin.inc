void LoadAdmin(int client, const char[] steamid)
{
	if (g_authClient[client][Vip] || g_authClient[client][Ctb] || g_authClient[client][Opt] || g_authClient[client][Adm] || g_authClient[client][Own])
	{
		AdminId _adminId;
		char auth[32];

		Steam64toSteamID(steamid, auth, 32);

		if ((_adminId = FindAdminByIdentity(AUTHMETHOD_STEAM, auth)) != INVALID_ADMIN_ID)
		{
			RemoveAdmin(_adminId);
			_adminId = INVALID_ADMIN_ID;
		}

		_adminId = CreateAdmin(g_szUsername[client]);
		if (!_adminId.BindIdentity(AUTHMETHOD_STEAM, auth))
		{
			RemoveAdmin(_adminId);
			NP_Core_LogError("User-admin", "LoadAdmin", "Failed to bind admin \"%s\" to identity \"%s\"", g_szUsername[client], auth);
			return;
		}

		_adminId.SetFlag(Admin_Reservation, true);
		_adminId.SetFlag(Admin_Custom1, true); // vip use "o" flag

		if (g_authClient[client][Ctb] || g_authClient[client][Opt] || g_authClient[client][Adm] || g_authClient[client][Own])
		{
			_adminId.SetFlag(Admin_Generic, true);
			_adminId.SetFlag(Admin_Kick, true);
			_adminId.SetFlag(Admin_Slay, true);
			_adminId.SetFlag(Admin_Chat, true);
			_adminId.SetFlag(Admin_Vote, true);
			_adminId.SetFlag(Admin_Changemap, true);

			if(g_authClient[client][Opt] || g_authClient[client][Adm] || g_authClient[client][Own])
			{
				_adminId.SetFlag(Admin_Ban, true);
				_adminId.SetFlag(Admin_Unban, true);

				if(g_authClient[client][Adm] || g_authClient[client][Own])
				{
					_adminId.SetFlag(Admin_Convars, true);
					_adminId.SetFlag(Admin_Config, true);

					if(g_authClient[client][Own])
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