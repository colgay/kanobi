#include <amxmodx>

#include <kanobi_zombie>
#include <kanobi_util>

#define VERSION "0.1"

enum ZOMBIE_MODEL_t
{
	ZM_Model[32],
	ZM_vModel[64]
};

new const g_ZombieInfo[][ZombieClassInfo_t] = {
	{"Normal Zombie", "Balance", "normal", 0},
	{"Fat Zombie", "High HP, Slow", "fat", 0},
	{"Light Zombie", "Low Gravity", "light", 0},
	{"Fast Zombie", "Fast, Low HP", "fast", 0}
};

new const g_ZombieAttr[][ZombieClassAttr_t] = {
	{750, 1.0, 240.0, 1.0, 1.0},
	{1500, 1.0, 215.0, 1.0, 0.5},
	{600, 0.7, 230.0, 1.0, 2.0},
	{500, 0.95, 290.0, 1.0, 1.5}
};

new const g_ZombieModel[][ZOMBIE_MODEL_t] = {
	{"vip", "models/v_knife_r.mdl"},
	{"arctic", "models/v_knife_r.mdl"},
	{"leet", "models/v_knife_r.mdl"},
	{"terror", "models/v_knife_r.mdl"},
};

public plugin_precache()
{
	for (new i = 0; i < sizeof g_ZombieInfo; i++)
	{
		kanobi_RegisterZombie(g_ZombieInfo[i], g_ZombieAttr[i], g_ZombieModel[i][ZM_Model], g_ZombieModel[i][ZM_vModel]);
	}
}

public plugin_init()
{
	register_plugin("[Kano-bi] Zombie Class", VERSION, "peter5001");
}