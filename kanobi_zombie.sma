#include <amxmodx>
#include <amxmisc>
#include <fun>
#include <cstrike>
#include <fakemeta>
#include <hamsandwich>

#include <kanobi_util>

#define VERSION "0.1"

#define NullZombieClass -1

#define IsValidZombieClass(%0) (0 <= %0 < g_NumZombieClasses)
#define IsValidPlayer(%0) (1 <= %0 <= MaxClients)

#define GetZombieInfo(%1,%2) ArrayGetArray(g_ZombieClassData[ZData_Info], %1, %2)
#define GetZombieAttr(%1,%2) ArrayGetArray(g_ZombieClassData[ZData_Attr], %1, %2)
#define SetZombieAttr(%1,%2) ArraySetArray(g_ZombieClassData[ZData_Attr], %1, %2)
#define GetZombieModel(%1,%2) ArrayGetString(g_ZombieClassData[ZData_Model], %1, %2, charsmax(%2))
#define GetZombieViewModel(%1,%2) ArrayGetString(g_ZombieClassData[ZData_vModel], %1, %2, charsmax(%2))
#define FindZombieByClass(%1,%2) TrieGetCell(g_ZombieClassData[ZData_Trie], %1, %2)

#define CHECK_ZOMBIE_CLASS(%1,%2) \
	if (!IsValidZombieClass(%1)) { \
		log_error(AMX_ERR_NATIVE, "Invalid Zombie Class (%d)", %1); \
		return %2; \
	}

#define CHECK_PLAYER(%1,%2) \
	if (!IsValidPlayer(%1)) { \
		log_error(AMX_ERR_NATIVE, "Invalid Player (%d)", %1); \
		return %2; \
	}

#define IF_ZOMBIE_CLASS(%1,%2) \
	for (new %1 = 0; %1 < g_NumZombieClasses; %1++) \
		if (g_PlayerClass[%2] == %1)

enum _:ZombieClassInfo_t
{
	Zombi_Name[32],
	Zombi_Desc[32],
	Zombi_Class[32],
	Zombi_Flags
};

enum _:ZombieClassAttr_t
{
	Zombi_Health,
	Float:Zombi_Gravity,
	Float:Zombi_Speed,
	Float:Zombi_Painshock,
	Float:Zombi_Knockback,
};

enum _:ZombieClassData_t
{
	Array:ZData_Info,
	Array:ZData_Attr,
	Array:ZData_Model,
	Array:ZData_vModel,
	Trie:ZData_Trie,
};

enum _:Forward_t
{
	Fwd_Zombie,
	Fwd_Speed,
	Fwd_vModel,
};

new g_IsZombie[MAX_PLAYERS + 1];
new g_PlayerClass[MAX_PLAYERS + 1];

new g_ZombieClassData[ZombieClassData_t];
new g_NumZombieClasses;

new g_Forward[Forward_t];
new g_ForwardRet;

public plugin_precache()
{
	g_ZombieClassData[ZData_Info] = ArrayCreate(ZombieClassInfo_t);
	g_ZombieClassData[ZData_Attr] = ArrayCreate(ZombieClassAttr_t);
	g_ZombieClassData[ZData_Model] = ArrayCreate(32);
	g_ZombieClassData[ZData_vModel] = ArrayCreate(64);
	g_ZombieClassData[ZData_Trie] = TrieCreate();
}

public plugin_init()
{
	register_plugin("[Kano-bi] Zombie", VERSION, "peter5001");

	//register_forward(FM_EmitSound, "OnEmitSound");

	RegisterHam(Ham_Spawn, "player", "OnPlayerSpawn_Post", 1);

	RegisterHam(Ham_CS_Player_ResetMaxSpeed, "player", "OnPlayerResetMaxspeed_Post", 1);
	RegisterHam(Ham_Item_Deploy, "weapon_knife", "OnKnifeDeploy_Post", 1);

	RegisterHam(Ham_Touch, "weaponbox", "OnWeaponTouch");
	RegisterHam(Ham_Touch, "weapon_shield", "OnWeaponTouch");
	RegisterHam(Ham_Touch, "armoury_entity", "OnWeaponTouch");

	register_concmd("zombieclass_set", "CmdZombieClassSet", ADMIN_CVAR, "");
	register_concmd("zombieclasses", "CmdZombieClasses", ADMIN_CVAR, "");

	g_Forward[Fwd_Zombie] = CreateMultiForward("kanobi_OnMakeZombie", ET_IGNORE, FP_CELL);
	g_Forward[Fwd_Speed] = CreateMultiForward("kanobi_OnZombieSetSpeed", ET_IGNORE, FP_CELL);
	g_Forward[Fwd_vModel] = CreateMultiForward("kanobi_OnZombieSetViewModel", ET_IGNORE, FP_CELL);
}

public plugin_natives()
{
	register_library("kanobi_zombie");

	register_native("kanobi_RegisterZombie", "native_register_zombie");
	register_native("kanobi_RegisterZombie2", "native_register_zombie2");
	register_native("kanobi_GetZombieInfo", "native_get_zombie_info");
	register_native("kanobi_GetZombieAttr", "native_get_zombie_attr");
	register_native("kanobi_FindZombieByClass", "native_find_zombie_by_class");
	register_native("kanobi_GetZombieClass", "native_get_zombie_class");
	register_native("kanobi_SetZombieClass", "native_set_zombie_class");
	register_native("kanobi_IsZombie", "native_is_zombie");
}

public OnPlayerSpawn_Post(id)
{
	if (!is_user_alive(id))
		return;
	
	if (cs_get_user_team(id) == CS_TEAM_T)
	{
		g_PlayerClass[id] = random(g_NumZombieClasses);
		MakeZombie(id);
	}
}

public OnPlayerResetMaxspeed_Post(id)
{
	if (is_user_alive(id) && g_IsZombie[id])
	{
		IF_ZOMBIE_CLASS(i, id)
		{
			static attr[ZombieClassAttr_t];
			GetZombieAttr(i, attr);
			
			set_user_maxspeed(id, attr[Zombi_Speed]);
		}

		ExecuteForward(g_Forward[Fwd_Speed], g_ForwardRet, id);
	}
}

public OnKnifeDeploy_Post(ent)
{
	if (!pev_valid(ent))
		return;
	
	new player = get_ent_data_entity(ent, "CBasePlayerItem", "m_pPlayer");
	if (player)
	{
		if (g_IsZombie[player])
		{
			IF_ZOMBIE_CLASS(i, player)
			{
				static model[64];
				GetZombieViewModel(i, model);

				set_pev(player, pev_viewmodel2, model);
			}

			set_pev(player, pev_weaponmodel2, "");

			ExecuteForward(g_Forward[Fwd_vModel], g_ForwardRet, player);
		}
	}
}

public OnWeaponTouch(ent, player)
{
	if (pev_valid(ent) && is_user_alive(player) && g_IsZombie[player])
	{
		return HAM_SUPERCEDE;
	}

	return HAM_IGNORED;
}

public client_disconnected(id)
{
	g_IsZombie[id] = false;
	g_PlayerClass[id] = NullZombieClass;
}

public CmdZombieClassSet(id, level, cid)
{
	if (!cmd_access(id, level, cid, 2))
		return PLUGIN_HANDLED;
	
	new classname[32];
	read_argv(1, classname, charsmax(classname));

	new index;
	if (!FindZombieByClass(classname, index))
	{
		console_print(id, "invalid zombie class ^"%s^"", classname);
		return PLUGIN_HANDLED;
	}

	new attrname[32];
	read_argv(2, attrname, charsmax(attrname));

	new arg[16];
	read_argv(3, arg, charsmax(arg));

	static attr[ZombieClassAttr_t];
	GetZombieAttr(index, attr);

	if (equal(attrname, "hp"))
	{
		if (read_argc() == 4)
		{
			attr[Zombi_Health] = str_to_num(arg);
			SetZombieAttr(index, attr);
		}
		else
		{
			console_print(id, "zombie_%s hp is ^"%d^"", classname, attr[Zombi_Health]);
		}
	}
	else if (equal(attrname, "gravity"))
	{
		if (read_argc() == 4)
		{
			attr[Zombi_Gravity] = str_to_float(arg);
			SetZombieAttr(index, attr);
		}
		else
		{
			console_print(id, "zombie_%s gravity is ^"%.2f^"", classname, attr[Zombi_Gravity]);
		}
	}
	else if (equal(attrname, "speed"))
	{
		if (read_argc() == 4)
		{
			attr[Zombi_Speed] = str_to_float(arg);
			SetZombieAttr(index, attr);
		}
		else
		{
			console_print(id, "zombie_%s speed is ^"%.2f^"", classname, attr[Zombi_Speed]);
		}
	}
	else if (equal(attrname, "knockback"))
	{
		if (read_argc() == 4)
		{
			attr[Zombi_Knockback] = str_to_float(arg);
			SetZombieAttr(index, attr);
		}
		else
		{
			console_print(id, "zombie_%s knockback is ^"%.2f^"", classname, attr[Zombi_Knockback]);
		}
	}
	else if (equal(attrname, "painshock"))
	{
		if (read_argc() == 4)
		{
			attr[Zombi_Painshock] = str_to_float(arg);
			SetZombieAttr(index, attr);
		}
		else
		{
			console_print(id, "zombie_%s painshock is ^"%.2f^"", classname, attr[Zombi_Painshock]);
		}
	}

	return PLUGIN_HANDLED;
}

public CmdZombieClasses(id, level, cid)
{
	if (!cmd_access(id, level, cid, 1))
		return PLUGIN_HANDLED;
	
	server_print("----- [Zombie Classes] -----")

	static info[ZombieClassInfo_t], attr[ZombieClassAttr_t];
	
	for (new i = 0; i < g_NumZombieClasses; i++)
	{
		GetZombieInfo(i, info);
		GetZombieAttr(i, attr);

		server_print("id:%d, name:%s, class:%s", i, info[Zombi_Name], info[Zombi_Class]);
		server_print("hp:%d, gravity:%.2f, speed:%.f, painshock:%.2f, knockback:%.2f", 
			attr[Zombi_Health], attr[Zombi_Gravity], attr[Zombi_Speed], attr[Zombi_Painshock], attr[Zombi_Knockback]);
		server_print("----------------------------");
	}

	return PLUGIN_HANDLED;
}

public native_register_zombie()
{
	new info[ZombieClassInfo_t], attr[ZombieClassAttr_t];
	get_array(1, info, ZombieClassInfo_t);
	get_array(2, attr, ZombieClassAttr_t);

	new model[32], vmodel[64];
	get_string(3, model, charsmax(model));
	get_string(4, vmodel, charsmax(vmodel));

	ArrayPushArray(g_ZombieClassData[ZData_Info], info);
	ArrayPushArray(g_ZombieClassData[ZData_Attr], attr);
	ArrayPushArray(g_ZombieClassData[ZData_Model], model);
	ArrayPushArray(g_ZombieClassData[ZData_vModel], vmodel);

	TrieSetCell(g_ZombieClassData[ZData_Trie], info[Zombi_Class], g_NumZombieClasses);

	PrecachePlayerModel(model);
	precache_model(vmodel);

	g_NumZombieClasses++;
	return (g_NumZombieClasses - 1);
}

public native_register_zombie2()
{
	new info[ZombieClassInfo_t];
	get_string(1, info[Zombi_Name], charsmax(info[Zombi_Name]));
	get_string(2, info[Zombi_Desc], charsmax(info[Zombi_Desc]));
	get_string(3, info[Zombi_Class], charsmax(info[Zombi_Class]));
	info[Zombi_Flags] = get_param(4);

	new attr[ZombieClassAttr_t];
	attr[Zombi_Health] = get_param(5);
	attr[Zombi_Gravity] = get_param_f(6);
	attr[Zombi_Speed] = get_param_f(7);
	attr[Zombi_Painshock] = get_param_f(8);
	attr[Zombi_Knockback] = get_param_f(9);

	new model[32], vmodel[64];
	get_string(10, model, charsmax(model));
	get_string(11, vmodel, charsmax(vmodel));

	ArrayPushArray(g_ZombieClassData[ZData_Info], info);
	ArrayPushArray(g_ZombieClassData[ZData_Attr], attr);
	ArrayPushArray(g_ZombieClassData[ZData_Model], model);
	ArrayPushArray(g_ZombieClassData[ZData_vModel], vmodel);

	TrieSetCell(g_ZombieClassData[ZData_Trie], info[Zombi_Class], g_NumZombieClasses);

	PrecachePlayerModel(model);
	precache_model(vmodel);

	g_NumZombieClasses++;
	return (g_NumZombieClasses - 1);
}

public native_get_zombie_info()
{
	new zombieid = get_param(1);
	CHECK_ZOMBIE_CLASS(zombieid, 0)
	
	new info[ZombieClassInfo_t];
	GetZombieInfo(zombieid, info);

	set_array(2, info, ZombieClassInfo_t);
	return 1;
}

public native_get_zombie_attr()
{
	new zombieid = get_param(1);
	CHECK_ZOMBIE_CLASS(zombieid, 0)
	
	new attr[ZombieClassAttr_t];
	GetZombieAttr(zombieid, attr);

	set_array(2, attr, ZombieClassAttr_t);
	return 1;
}

public native_find_zombie_by_class()
{
	new classname[32];
	get_string(1, classname, charsmax(classname));

	new zombieid;
	if (FindZombieByClass(classname, zombieid))
		return zombieid;
	
	return NullZombieClass;
}

public native_get_zombie_class()
{
	new id = get_param(1);
	CHECK_PLAYER(id, NullZombieClass)
	
	return g_PlayerClass[id];
}

public native_set_zombie_class()
{
	new id = get_param(1);
	CHECK_PLAYER(id, 0)
	
	new value = get_param(2);
	CHECK_ZOMBIE_CLASS(value, 0)

	g_PlayerClass[id] = value;
	return 1;
}

public native_is_zombie()
{
	new id = get_param(1);
	CHECK_PLAYER(id, 0)

	return g_IsZombie[id];
}

MakeZombie(id)
{
	g_IsZombie[id] = true;

	strip_user_weapons(id);
	give_item(id, "weapon_knife");

	IF_ZOMBIE_CLASS(i, id)
	{
		static model[32], attr[ZombieClassAttr_t];
		GetZombieAttr(i, attr);
		GetZombieModel(i, model);

		set_user_health(id, attr[Zombi_Health]);
		set_user_gravity(id, attr[Zombi_Gravity]);
		ExecuteHamB(Ham_CS_Player_ResetMaxSpeed, id);

		cs_set_user_model(id, model);
	}

	ExecuteForward(g_Forward[Fwd_Zombie], g_ForwardRet, id);
}