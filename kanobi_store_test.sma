#include <amxmodx>
#include <kanobi_store>

enum _:STORE_DATA
{
	STORE_NAME[32],
	STORE_TITLE[64],
	STORE_DESC[64],
	STORE_FLAGS,
};

#define STORE_PARAMS{%0} %0[STORE_NAME], %0[STORE_TITLE], %0[STORE_DESC], %0[STORE_FLAGS]

#define ADD_STORE_ITEMS(%1,%2,%3) \
	for (new %1 = 0; %1 < sizeof %3; %1++) \
		kanobi_AddStoreItem(%2, %3[%1]);

new const g_StoreData[][STORE_DATA] = {
	{"7-eleven", "7-eleven", "24/7", 0},
	{"759", "759 Store", "Blu..blu..blu", 0},
	{"test", "Test Store", "For test only", 0}
};

new const g_StoreItems1[][StoreItem_t] = {
	{"薯片", "致肥", "chips", 14, 0},
	{"百力滋", "高血壓", "pretz", 10, 0},
	{"Pocky", "糖尿", "pocky", 11, 0},
	{"可樂", "咖啡因中毒", "coke", 9, 0},
	{"杯麵", "腎虧", "noodles", 12, 0},
	{"炸雞髀", "心臟病", "chicken", 20, 0}
};

new const g_StoreItems2[][StoreItem_t] = {
	{"法式羊架", "騷", "ovation", 658, 0},
	{"冷凍蠔", "重金屬中毒", "seawell", 149, 0},
	{"洗衣液", "死人", "bioscience", 59, 0},
	{"牛油磚", "塞血管", "jersey", 46, 0},
	{"燕麥", "健康", "oats", 26, 0}
};

new const g_StoreItems3[][StoreItem_t] = {
	{"Test A", "", "a", 100, 0},
	{"Test B", "", "b", 200, 0},
	{"Test C", "", "c", 300, 0},
	{"Test D", "", "d", 400, 0},
	{"Test E", "", "e", 500, 0},
	{"Test F", "", "f", 600, 0},
	{"Test G", "", "g", 700, 0}
};

new g_StoreId[3];

public plugin_init()
{
	register_plugin("[Kano-bi] Store: Test", "0.1", "peter5001");

	for (new i = 0; i < sizeof g_StoreData; i++)
	{
		g_StoreId[i] = kanobi_CreateStore(STORE_PARAMS{g_StoreData[i]});
	}

	ADD_STORE_ITEMS(i, g_StoreId[0], g_StoreItems1)
	ADD_STORE_ITEMS(i, g_StoreId[1], g_StoreItems2)
	ADD_STORE_ITEMS(i, g_StoreId[2], g_StoreItems3)
}

public kanobi_OnStoreBuyItem_Post(id, storeid, item_handle, itemid)
{
	static itemdata[StoreItem_t];
	kanobi_GetStoreItem(item_handle, itemid, itemdata);

	client_print(id, print_chat, "[Store**] Buy '%a' for $%d.", itemdata[SItem_Name], itemdata[SItem_Price]);
}