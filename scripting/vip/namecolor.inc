void ChangeColorMenu(int client)
{
	Menu infoMenu = new Menu(MenuHandler_ChangeColor);
	infoMenu.SetTitle("名字颜色");
	infoMenu.AddItem("{white}", "白色");
	infoMenu.AddItem("{green}", "绿色");
	infoMenu.AddItem("{yellow}", "黄色");
	infoMenu.AddItem("{gray}", "灰色");
	infoMenu.AddItem("{olive}", "橄榄色");
	infoMenu.AddItem("{orange}", "橙色");
	infoMenu.AddItem("{blue}", "蓝色");
	infoMenu.AddItem("{purple}", "紫色");
	infoMenu.ExitButton = true;
	infoMenu.Display(client, 0);
}

public int MenuHandler_ChangeColor(Menu menu, MenuAction action, int client, int slot)
{
	if (action == MenuAction_End)
		delete menu;
	else if (action == MenuAction_Select)
	{
		char color[16];
		menu.GetItem(slot, color, 16);
		NP_Chat_SetNameColor(client, color);
		CPrintToChat(client, "\x04[提示]{blue} 名字颜色更换成功！");
	}

	return 0;
}