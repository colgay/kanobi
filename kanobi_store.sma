#include <amxmodx>

#include <cs_money>

#define VERSION "0.1"

#define NullStore -1

#define CHECK_STORE(%1,%2) \
    if (!IsValidStore(%1)) { \
        log_error(AMX_ERR_NATIVE, "Invalid store (%d)", %1); \
        return %2; \
    }

#define IsValidStore(%1) (0 <= %1 < g_NumStores)
#define FindStoreByName(%1,%2) TrieGetCell(g_Stores[Store_Map], %1, %2)
#define IsValidStoreItem(%1,%2) (0 <= %2 < ArraySize(%1))

#define GetStoreStr[%0](%1,%2) ArrayGetString(g_Stores[Store_%0], %1, %2, charsmax(%2))
#define GetStoreCell[%0](%1) ArrayGetCell(g_Stores[Store_%0], %1)

enum _:Store_t
{
    Array:Store_Name,
    Array:Store_Title,
    Array:Store_Desc,
    Array:Store_Flags,
    Array:Store_Items,
    Array:Store_Menu,
    Array:Store_MenuCallback,
    Trie:Store_Map,
};

enum _:StoreItem_t
{
    SItem_Name[32],
    SItem_Desc[64],
    SItem_Class[32],
    SItem_Price,
    SItem_Flags,
};

enum _:ForwardType
{
    FT_PRE,
    FT_POST
};

enum _:Forward_t
{
    Fwd_BuyItem[ForwardType]
};

new g_Stores[Store_t];
new g_NumStores;

new g_Forwards[Forward_t];
new g_ForwardResult;

public plugin_precache()
{
    g_Stores[Store_Name] = ArrayCreate(32);
    g_Stores[Store_Title] = ArrayCreate(32);
    g_Stores[Store_Desc] = ArrayCreate(32);
    g_Stores[Store_Flags] = ArrayCreate(1);
    g_Stores[Store_Items] = ArrayCreate(StoreItem_t);
    g_Stores[Store_Menu] = ArrayCreate(1);
    g_Stores[Store_MenuCallback] = ArrayCreate(1);
    g_Stores[Store_Map] = TrieCreate(); 
}

public plugin_init()
{
    register_plugin("[Kano-bi] Store", VERSION, "peter5001");

    register_clcmd("kanobi_store_menu", "CmdStoreMenu");

    g_Forwards[Fwd_BuyItem][FT_PRE] = CreateMultiForward("kanobi_OnStoreBuy", ET_STOP2, FP_CELL, FP_CELL, FP_CELL, FP_CELL);
    g_Forwards[Fwd_BuyItem][FT_POST] = CreateMultiForward("kanobi_OnStoreBuy_Post", ET_IGNORE, FP_CELL, FP_CELL, FP_CELL, FP_CELL);
}

public plugin_natives()
{
    register_library("kanobi_store");

    register_native("kanobi_CreateStore", "native_create_store");
    register_native("kanobi_AddStoreItem", "native_add_store_item");
    register_native("kanobi_GetStoreItemHandle", "native_get_store_item_handle");
    register_native("kanobi_GetStoreItem", "native_get_store_item");
    register_native("kanobi_GetStoreTitle", "native_get_store_title");
    register_native("kanobi_GetStoreName", "native_get_store_name");
    register_native("kanobi_GetStoreFlags", "native_get_store_flags");
    register_native("kanobi_GetStoreMenu", "native_get_store_menu");
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

	new menu = GetStoreCell[Menu](storeid);
	menu_display(id, menu);

	return PLUGIN_HANDLED;
}

public HandleStoreMenu(id, menu, item)
{
    if (item == MENU_EXIT)
        return;
    
    new info[32];
    new access, callback;
    menu_item_getinfo(menu, item, access, info, charsmax(info), _, _, callback);

    new storeid = NullStore;
    if (!FindStoreByName(info, storeid) || !IsValidStore(storeid))
        return;
    
    new Array:hItems = GetStoreCell[Items](storeid);
    if (!IsValidStoreItem(hItems, item))
        return;
    
    ExecuteForward(g_Forwards[Fwd_BuyItem][FT_PRE], g_ForwardResult, id, storeid, hItems, item);

    if (g_ForwardResult >= PLUGIN_HANDLED)
        return;

    new itemdata[StoreItem_t];
    ArrayGetArray(hItems, item, itemdata);

    new money = csm_get_money(id);
    new price = itemdata[SItem_Price];

    if (money < price)
    {
        csm_blink_acct(id);
        return;
    }

    csm_set_money(id, money - price);

    ExecuteForward(g_Forwards[Fwd_BuyItem][FT_POST], g_ForwardResult, id, storeid, hItems, item);
}

public native_create_store()
{
    new name[32], title[32], desc[32];
    get_string(1, name, charsmax(name));
    get_string(2, title, charsmax(title));
    get_string(3, desc, charsmax(desc));

    new flags = get_param(4);
    ArrayPushString(g_Stores[Store_Name], name);
    ArrayPushString(g_Stores[Store_Title], title);
    ArrayPushString(g_Stores[Store_Desc], desc);
    ArrayPushCell(g_Stores[Store_Flags], flags);

    new Array:hItems = ArrayCreate(StoreItem_t);
    ArrayPushCell(g_Stores[Store_Items], hItems);

    new menu = menu_create(title, "HandleStoreMenu");
    new callback = get_param(5);

    menu_setprop(menu, MPROP_NUMBER_COLOR, "\y");

	ArrayPushCell(g_Stores[Store_Menu], menu);
	ArrayPushCell(g_Stores[Store_MenuCallback], callback);

    TrieSetCell(g_Stores[Store_Map], name, g_NumStores);

    g_NumStores++;
    return (g_NumStores - 1);
}

public native_add_store_item()
{
    new storeid = get_param(1);
    CHECK_STORE(storeid, 0)
    
    new Array:hItems = GetStoreCell[Items](storeid);

    new itemdata[StoreItem_t];
    get_array(2, itemdata, StoreItem_t);
    ArrayPushArray(hItems, itemdata);

    new menu = GetStoreCell[Menu](storeid);
    new callback = GetStoreCell[MenuCallback](storeid);

    new storename[32];
    GetStoreStr[Name](storeid, storename);

	new buffer[96];
	formatex(buffer, charsmax(buffer), "%s \y%s \w$%d", itemdata[SItem_Name], itemdata[SItem_Desc], itemdata[SItem_Price]);
	menu_additem(menu, buffer, storename, _, callback);

    return ArraySize(hItems);
}

public Array:native_get_store_item_handle()
{
    new storeid = get_param(1);
    CHECK_STORE(storeid, Invalid_Array);

    return GetStoreCell[Items](storeid);
}

public native_get_store_item()
{
    new Array:hItems = Array:get_param(1);
    if (hItems == Invalid_Array)
    {
        log_error(AMX_ERR_NATIVE, "Invalid Store Item Handle (%d)", hItems);
        return 0;
    }

    new itemid = get_param(2);
    if (!IsValidStoreItem(hItems, itemid))
    {
        log_error(AMX_ERR_NATIVE, "Invalid Store Item (%d)", itemid);
        return 0;
    }

    static itemdata[StoreItem_t];
    ArrayGetArray(hItems, itemid, itemdata);

    set_array(3, itemdata, StoreItem_t);
    return 1;
}

public native_get_store_title()
{
    new storeid = get_param(1);
    CHECK_STORE(storeid, 0);

    new string[32];
    GetStoreStr[Title](storeid, string);
    set_string(2, string, charsmax(string));

    return 1;
}

public native_get_store_name()
{
    new storeid = get_param(1);
    CHECK_STORE(storeid, 0);

    new string[32];
    GetStoreStr[Name](storeid, string);
    set_string(2, string, charsmax(string));
    
    return 1;
}

public native_get_store_flags()
{
    new storeid = get_param(1);
    CHECK_STORE(storeid, 0);

    return GetStoreCell[Flags](storeid);
}

public native_get_store_menu()
{
    new storeid = get_param(1);
    CHECK_STORE(storeid, 0);

    return GetStoreCell[Menu](storeid);
}