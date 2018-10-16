void DisplayExchangeVIP(int client)
{
	Menu infoMenu = new Menu(MenuHandler_ExchangeVIP);
	infoMenu.SetTitle("兑换会员");
	infoMenu.AddItem("1000", "兑换 1个月 会员 - 1000软妹币");
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
			if (NP_Vip_GrantVip(client, 30))
				PrintToChat(client, "\x04[提示]\x01 恭喜你成功兑换 \x041个月\x01 会员！");
		}
		else
		{
			PrintToChat(client, "\x04[提示]\x01 你没钱钱买东西啦！");
		}
	}

	return 0;
}