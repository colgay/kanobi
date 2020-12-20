#if defined _kanobi_store_included
	#endinput
#endif
#define _kanobi_store_included

enum _:StoreItem_t
{
    SItem_Name[32],
    SItem_Desc[64],
    SItem_Class[32],
    SItem_Price,
    SItem_Flags,
};

native kanobi_CreateStore(const name[], const title[], const desc[], flags, callback=-1);
native kanobi_AddStoreItem(storeid, itemdata[StoreItem_t]);
native kanobi_GetStoreItemHandle(storeid);
native kanobi_GetStoreItem(handle, index, itemdata[StoreItem_t]);

forward kanobi_OnStoreBuyItem(id, storeid, item_handle, itemid);