#if !defined REQUIRE_PLUGIN
    #endinput
#endif

#if defined _NewPage_Store_Include_
    #endinput
#endif

#define _NewPage_Store_Include_

#define MAX_ITEMS 999
#define MAX_TYPES 999

enum Item
{
	ID,
	Type,
	String:Name[32],
	Price,
	Validity,
	bool:Buyable
};

enum Categorie
{
	ID,
	String:Name[32],
	bool:Visible
};

forward void NP_Store_UserBuyItem(int client, int ItemID, int CategorieID, int Validity);

public SharedPlugin __pl_store =
{
	name = "np-store",
	file = "np-store.smx",
#if !defined REQUIRE_PLUGIN
    required = 0
#else
    required = 1
#endif
};