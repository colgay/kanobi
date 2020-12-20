#include <amxmodx>
#include <amxmisc>

#define VERSION "0.1"

#define IsValidStore(%1) (0 <= %1 < g_NumStores)
#define IsValidStoreItem(%1,%2) (0 <= %2 < %1[StoreItem_Num])
#define IsValidPlayer(%1) (1 <= %1 <= MaxClients)

#define FindStoreByName(%1,%2) TrieGetCell(g_Stores[Store_Trie], %1, %2)
#define GetStoreItems(%1,%2) ArrayGetArray(g_Stores[Store_Items], %1, %2)
#define GetStoreItemInfo(%1,%2,%3) ArrayGetArray(%1[StoreItem_Info], %2, %3)
#define GetStoreItemData(%1,%2,%3) ArrayGetArray(%1[StoreItem_Data], %2, %3)
#define SetStoreItemData(%1,%2,%3) ArraySetArray(%1[StoreItem_Data], %2, %3)
#define GetStoreMenu(%1) ArrayGetCell(g_Stores[Store_Menu], %1)

enum _:Store_t
{
	Array:Store_Info,
	Array:Store_Data,
	Array:Store_Items,
	Array:Store_Menu,
	Array:Store_MenuCallback,
	Trie:Store_Trie
};

enum _:StoreInfo_t
{
	Store_Name[32],
	Store_Title[32],
	Store_Desc[64]
};

enum _:StoreData_t
{
	Store_Flags,
};

enum _:StoreItem_t
{
	Array:StoreItem_Info,
	Array:StoreItem_Data,
	StoreItem_Num
}

enum _:StoreItemInfo_t
{
	SItem_Name[32],
	SItem_Desc[32],
	SItem_Class[32],
};

enum _:StoreItemData_t
{
	SItem_Price,
	SItem_Amount,
	SItem_Flags,
};

new g_Stores[Store_t];
new g_NumStores;

public plugin_precache()
{
	g_Stores[Store_Info] = ArrayCreate(StoreInfo_t);
	g_Stores[Store_Data] = ArrayCreate(StoreData_t);
	g_Stores[Store_Items] = ArrayCreate(StoreItem_t);
	g_Stores[Store_Menu] = ArrayCreate(1);
	g_Stores[Store_MenuCallback] = ArrayCreate(1);
	g_Stores[Store_Trie] = TrieCreate();
}

public plugin_init()
{
	register_plugin("[Kano-bi] Store", VERSION, "peter5001");

	register_clcmd("kanobi_store_menu", "CmdStoreMenu");
}

public plugin_natives()
{
	register_library("kanobi_store");

	register_native("kanobi_CreateStore", "native_create_store");
	register_native("kanobi_GetStoreInfo", "native_get_store_info");
	register_native("kanobi_GetStoreData", "native_get_store_data");
	register_native("kanobi_SetStoreData", "native_set_store_data");
	register_native("kanobi_AddStoreItem", "native_add_store_item");
	register_native("kanobi_GetStoreItems", "native_get_store_items");
	register_native("kanobi_GetStoreItemInfo", "native_get_store_item_info");
	register_native("kanobi_GetStoreItemData", "native_get_store_item_data");
	register_native("kanobi_SetStoreItemData", "native_set_store_item_data");
	register_native("kanobi_DisplayStoreMenu", "native_display_store_menu");
}

public CmdStoreMenu(id)
{
	new name[32];
	read_argv(1, name, charsmax(name));

	new storeid;
	if (!FindStoreByName(name, storeid))
	{
		console_print(id, "store '%s' not found.", name);
		return PLUGIN_HANDLED;
	}

	new menu = GetStoreMenu(storeid);
	menu_display(id, menu);

	return PLUGIN_HANDLED;
}

public StoreMenuItemCallback(id, menu, item)
{
	return ITEM_IGNORE;
}

public HandleStoreMenu(id, menu, item)
{
	if (item == MENU_EXIT)
		return;

	new info[32];
	new access, callback;

	menu_item_getinfo(menu, item, access, info, charsmax(info), _, _, callback);

	new storeid;
	if (!FindStoreByName(info, storeid) || !IsValidStore(storeid))
		return;

	static items[StoreItem_t];
	static iteminfo[StoreItemInfo_t], itemdata[StoreItemData_t];

	GetStoreItems(storeid, items);

	if (!IsValidStoreItem(items, item))
		return;
	
	GetStoreItemInfo(items, item, iteminfo);
	GetStoreItemData(items, item, itemdata);

	client_print(id, print_console, "[Store] Buy '%s' for $%d.", iteminfo[SItem_Name], itemdata[SItem_Price]);
}

public native_create_store()
{
	new info[StoreInfo_t], data[StoreData_t];
	get_array(1, info, StoreInfo_t);
	get_array(2, data, StoreData_t);

	ArrayPushArray(g_Stores[Store_Info], info);
	ArrayPushArray(g_Stores[Store_Data], data);

	new items[StoreItem_t];
	items[StoreItem_Info] = ArrayCreate(StoreItemInfo_t);
	items[StoreItem_Data] = ArrayCreate(StoreItemData_t);
	items[StoreItem_Num] = 0;

	ArrayPushArray(g_Stores[Store_Items], items);

	new menu = menu_create(info[Store_Title], "HandleStoreMenu");
	new callback = menu_makecallback("StoreMenuItemCallback");

	menu_setprop(menu, MPROP_NUMBER_COLOR, "\y");

	ArrayPushCell(g_Stores[Store_Menu], menu);
	ArrayPushCell(g_Stores[Store_MenuCallback], callback);

	//server_print("%s", info[Store_Name]);

	TrieSetCell(g_Stores[Store_Trie], info[Store_Name], g_NumStores);

	g_NumStores++;
	return (g_NumStores - 1);
}

public native_get_store_info()
{
	new storeid = get_param(1);
	if (!IsValidStore(storeid))
		return 0;

	new info[StoreInfo_t];
	ArrayGetArray(g_Stores[Store_Info], storeid, info);
	set_array(2, info, StoreInfo_t);
	return 1;
}

public native_get_store_data()
{
	new storeid = get_param(1);
	if (!IsValidStore(storeid))
		return 0;

	new data[StoreData_t];
	ArrayGetArray(g_Stores[Store_Data], storeid, data);
	set_array(2, data, StoreData_t);
	return 1;
}

public native_set_store_data()
{
	new storeid = get_param(1);
	if (!IsValidStore(storeid))
		return 0;

	new data[StoreData_t];
	get_array(2, data, StoreData_t);
	ArraySetArray(g_Stores[Store_Data], storeid, data);
	return 1;
}

public native_add_store_item()
{
	new storeid = get_param(1);
	if (!IsValidStore(storeid))
		return 0;

	new items[StoreItem_t];
	ArrayGetArray(g_Stores[Store_Items], storeid, items);

	if (items[StoreItem_Info] == Invalid_Array || items[StoreItem_Data] == Invalid_Array)
		return 0;
	
	new info[StoreItemInfo_t], data[StoreItemData_t];
	get_array(2, info, StoreItemInfo_t);
	get_array(3, data, StoreItemData_t);

	ArrayPushArray(items[StoreItem_Info], info);
	ArrayPushArray(items[StoreItem_Data], data);
	items[StoreItem_Num]++;

	new menu = ArrayGetCell(g_Stores[Store_Menu], storeid);
	new callback = ArrayGetCell(g_Stores[Store_MenuCallback], storeid);

	new buffer[100];
	formatex(buffer, charsmax(buffer), "%s \y%s\R$%d", info[SItem_Name], info[SItem_Desc], data[SItem_Price]);
	menu_additem(menu, buffer, info[Store_Name], _, callback);

	return (items[StoreItem_Num] - 1);
}

public native_get_store_items()
{
	new storeid = get_param(1);
	if (!IsValidStore(storeid))
		return 0;
	
	new items[StoreItem_t];
	ArrayGetArray(g_Stores[Store_Items], storeid, items);

	set_array(2, items, StoreItem_t);
	return 1;
}

public native_get_store_item_info()
{
	new items[StoreItem_t];
	get_array(1, items, StoreItem_t);

	new itemid = get_param(2);
	if (IsValidStoreItem(items, itemid))
		return 0;

	new info[StoreItemInfo_t];
	ArrayGetArray(items[StoreItem_Info], itemid, info);
	set_array(3, info, StoreItemInfo_t);
	return 1;
}

public native_get_store_item_data()
{
	new items[StoreItem_t];
	get_array(1, items, StoreItem_t);

	new itemid = get_param(2);
	if (IsValidStoreItem(items, itemid))
		return 0;

	new data[StoreItemData_t];
	ArrayGetArray(items[StoreItem_Data], itemid, data);
	set_array(3, data, StoreItemData_t);

	return 1;
}

public native_set_store_item_data()
{
	new items[StoreItem_t];
	get_array(1, items, StoreItem_t);

	new itemid = get_param(2);
	if (IsValidStoreItem(items, itemid))
		return 0;
	
	new data[StoreItemData_t];
	get_array(3, data, StoreItemData_t);
	ArraySetArray(items[StoreItem_Data], itemid, data);

	return 1;
}

public native_display_store_menu()
{
	new player = get_param(1);
	if (!IsValidPlayer(player))
		return 0;
	
	new storeid = get_param(2);
	if (!IsValidStore(storeid))
		return 0;
	
	new menu = ArrayGetCell(g_Stores[Store_Menu], storeid);
	menu_display(player, menu);
	return 1;
}