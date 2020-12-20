#if defined _kanobi_item_manager_included
	#endinput
#endif
#define _kanobi_item_manager_included

enum _:ItemData_t
{
	Item_Name[32],
	Item_Desc[64],
	Item_Class[32],
	Item_Flags,
	Item_AmountPerSlot
};

native kanobi_RegisterItem(itemdata[ItemData_t]);
native kanobi_GetItem(itemid, itemdata[ItemData_t]);
native kanobi_FindItem(const classname[]);