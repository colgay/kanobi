#include <amxmodx>

#define VERSION "0.1"

#define NullItem -1

#define IsValidItem(%0) (0 <= %0 < g_NumItems)

#define CHECK_ITEM(%0, %1) \
	if (!IsValidItem(%0)) { \
		log_error(AMX_ERR_NATIVE, "Invalid Item (%d)", %0);
		return %1;
	}

enum _:ItemData_t
{
	Item_Name[32],
	Item_Desc[64],
	Item_Class[32],
	Item_Flags,
	Item_AmountPerSlot
};

new Array:g_Items;
new Trie:g_ItemMap;
new g_NumItems;

public plugin_precache()
{
	g_Items = ArrayCreate(ItemData_t);
	g_ItemMap = TrieCreate();
}

public plugin_init()
{
	register_plugin("[Kano-bi] Item Manager", VERSION, "peter5001");
}

public plugin_natives()
{
	register_library("kanobi_item_manager");

	register_naitve("kanobi_RegisterItem", "native_register_item");
	register_native("kanobi_GetItem", "naitve_get_item");
	register_native("kanobi_FindItem", "native_find_item_by_class");
}

public naitve_register_item()
{
	new itemdata[ItemData_t];
	get_array(1, itemdata, ItemData_t);

	ArrayPushArray(g_Items, itemdata);
	TrieSetCell(g_ItemMap, itemdata[Item_Class], g_NumItmes);

	return (g_NumItems - 1);
}

public native_get_item()
{
	new itemid = get_param(1);
	CHECK_ITEM(itemid, 0)

	new itemdata[ItemData_t];
	ArrayGetArray(g_Items, itemid, itemdata);
	set_array(2, itemdata, ItemData_t);
}

public native_find_item_by_class()
{
	new classname[32];
	get_string(1, classname, charsmax(classname));

	new itemid;
	if (TrieGetCell(g_ItemMap, classname, itemid))
		return itemid;

	return NullItem;
}