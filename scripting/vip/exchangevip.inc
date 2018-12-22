void DisplayExchangeVIP(int client)
{
	Menu infoMenu = new Menu(MenuHandler_ExchangeVIP);
	infoMenu.SetTitle("兑换会员");
	infoMenu.AddItem("1500", "兑换 7天 会员 - 1500软妹币");
	infoMenu.AddItem("5000", "兑换 30天 会员 - 5000软妹币");
	infoMenu.ExitButton = true;
	infoMenu.Display(client, 0);
}

public int MenuHandler_ExchangeVIP(Menu menu, MenuAction action, int client, int slot)
{
	if (action == MenuAction_End)
		delete menu;
	else if (action == MenuAction_Select)
	{
		char price[8];
		menu.GetItem(slot, price, 8);

		if (NP_Users_PayMoney(client, StringToInt(price)))
		{
			if (slot == 0)
			{
				if (NP_Vip_GrantVip(client, 7))
					CPrintToChat(client, "\x04[提示]{blue} 恭喜你成功兑换 \x047天{blue} 会员！");
			}
			else if (slot == 1)
			{
				if (NP_Vip_GrantVip(client, 30))
					CPrintToChat(client, "\x04[提示]{blue} 恭喜你成功兑换 \x0430天{blue} 会员！");
			}
		}
		else
		{
			CPrintToChat(client, "\x04[提示]{blue} 你没钱钱买东西啦！");
		}
	}

	return 0;
}