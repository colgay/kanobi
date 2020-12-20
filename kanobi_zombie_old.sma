#include <amxmodx>
#include <amxmisc>
#include <fun>
#include <cstrike>
#include <fakemeta>
#include <hamsandwich>

#include <kanobi_util>

#define VERSION "0.1"

#define DEFAULT_ZOMBIE_HP 1000
#define DEFAULT_ZOMBIE_GRAVITY 1.0
#define DEFAULT_ZOMBIE_SPEED 230.0
#define DEFAULT_ZOMBIE_MODEL "vip"
#define DEFAULT_ZOMBIE_VMODEL "models/v_knife_r.mdl"

#define IS_VALID_ZOMBIECLASS(%1) (0 <= %1 < g_NumZombieClasses)
#define IS_VALID_PLAYER(%1) (1 <= %1 <= MaxClients)

#define IF_ZOMBIE_CLASS(%1,%2) \
	for (new %1 = 0; %1 < g_NumZombieClasses; %1++) \
		if (g_ZombieClass[%2] == %1)

#define GET_ZOMBIE[%1](%2,%3) ArrayGetArray(g_ZombieClassData[ZOMBIE_%1], %2, %3)
#define SET_ZOMBIE[%1](%2,%3) ArraySetArray(g_ZombieClassData[ZOMBIE_%1], %2, %3)

#define FIND_ZOMBIE_BY_CLASS(%1,%2) TrieGetCell(g_tZombieClassName, %1, %2)

#define INVALID_ZOMBIECLASS -1

enum _:ZombieClassInfo
{
	Zombi_Name[32],
	Zombi_Desc[64],
	Zombi_Class[32],
	Zombi_Flags,
};

enum _:ZombieClassAttr
{
	Zombi_Health,
	Float:Zombi_Gravity,
	Float:Zombi_Speed,
	Float:Zombi_Painshock,
	Float:Zombi_Knockback,
}

enum _:ZombieClassModel
{
	Zombi_Model[32],
	Zombi_vModel[64]
};

enum _:ZombieClassDataType
{
	Array:ZOMBIE_INFO,
	Array:ZOMBIE_ATTR,
	Array:ZOMBIE_MODEL,
};

enum _:FakeForward
{
	FW_ZOMBIE,
	FW_SPEED,
	FW_VMODEL
};

new const SOUND_ZOMBIE_HIT[][] = {"zombie/claw_strike1.wav", "zombie/claw_strike2.wav", "zombie/claw_strike3.wav"};
new const SOUND_ZOMBIE_HITWALL[] = "weapons/bullet_hit1.wav";
new const SOUND_ZOMBIE_MISS[][] = {"zombie/claw_miss1.wav", "zombie/claw_miss2.wav"};
new const SOUND_ZOMBIE_HURT[][] = {"zombie/zo_pain1.wav", "zombie/zo_pain2.wav"};
new const SOUND_ZOMBIE_DIE[][] = {"zombie/zo_pain1.wav", "zombie/zo_pain2.wav"};

new Trie:g_tZombieClassName;
new g_ZombieClassData[ZombieClassDataType];
new g_NumZombieClasses;

new g_ZombieClass[MAX_PLAYERS+1] = {INVALID_ZOMBIECLASS, ...};

new g_IsZombie[MAX_PLAYERS+1];

new g_Forwards[FakeForward];
new g_ForwardResult;

CreateForwards()
{
	g_Forwards[FW_ZOMBIE] = CreateMultiForward("kanobi_on_zombie_spawn", ET_IGNORE, FP_CELL);
	g_Forwards[FW_SPEED] = CreateMultiForward("kanobi_on_zombie_set_speed", ET_IGNORE, FP_CELL);
	g_Forwards[FW_VMODEL] = CreateMultiForward("kanobi_on_zombie_set_vmodel", ET_IGNORE, FP_CELL);
}

public plugin_precache()
{
	g_ZombieClassData[ZOMBIE_INFO] = ArrayCreate(ZombieClassInfo);
	g_ZombieClassData[ZOMBIE_ATTR] = ArrayCreate(ZombieClassAttr);
	g_ZombieClassData[ZOMBIE_MODEL] = ArrayCreate(ZombieClassModel);
	g_tZombieClassName = TrieCreate();

	PrecachePlayerModel(DEFAULT_ZOMBIE_MODEL);
	precache_model(DEFAULT_ZOMBIE_VMODEL);

	PrecacheSoundArray(SOUND_ZOMBIE_HIT, sizeof SOUND_ZOMBIE_HIT);
	PrecacheSoundArray(SOUND_ZOMBIE_MISS, sizeof SOUND_ZOMBIE_MISS);
	PrecacheSoundArray(SOUND_ZOMBIE_HURT, sizeof SOUND_ZOMBIE_HURT);
	precache_sound(SOUND_ZOMBIE_HITWALL);
}

public plugin_init()
{
	register_plugin("[Kano-bi] Zombie", VERSION, "peter5001");

	register_forward(FM_EmitSound, "OnEmitSound");

	RegisterHam(Ham_Spawn, "player", "OnPlayerSpawn_Post", 1);

	RegisterHam(Ham_CS_Player_ResetMaxSpeed, "player", "OnPlayerResetMaxspeed_Post", 1);
	RegisterHam(Ham_Item_Deploy, "weapon_knife", "OnKnifeDeploy_Post", 1);

	RegisterHam(Ham_Touch, "weaponbox", "OnWeaponTouch");
	RegisterHam(Ham_Touch, "weapon_shield", "OnWeaponTouch");
	RegisterHam(Ham_Touch, "armoury_entity", "OnWeaponTouch");

	register_concmd("zombieclass_set", "CmdZombieClassSet", ADMIN_CVAR, "");
	register_concmd("zombieclass_data", "CmdZombieClassData", ADMIN_CVAR, "");

	CreateForwards();
}

public plugin_natives()
{
	register_library("kanobi_zombie");

	register_native("kanobi_zombie_register", "native_zombie_register");
	register_native("kanobi_zombie_get_info", "native_zombie_get_info");
	register_native("kanobi_zombie_get_attr", "native_zombie_get_attr");
	register_native("kanobi_zombie_get_model", "native_zombie_get_model");
	register_native("kanobi_find_zombie_by_class", "native_find_zombie_by_class");
	register_native("kanobi_get_zombie_class", "native_get_zombie_class");
	register_native("kanobi_set_zombie_class", "native_set_zombie_class");
	register_native("kanobi_is_zombie", "native_is_zombie");
}

public OnEmitSound(id, channel, const sample[], Float:volume, Float:attn, flags, pitch)
{
	if (is_user_connected(id) && g_IsZombie[id])
	{
		// player/...
		if (sample[0] == 'p' && sample[1] == 'l' && sample[5] == 'r')
		{
			// player/headshot or player/bhit_flesh
			if ((sample[7] == 'h' && sample[11] == 's') || (sample[7] == 'b' && sample[12] == 'f'))
			{
				emit_sound(id, channel, SOUND_ZOMBIE_HURT[random(sizeof SOUND_ZOMBIE_HURT)], volume, attn, flags, pitch);
				return FMRES_SUPERCEDE;
			}
			// player/die
			else if (sample[7] == 'd' && sample[8] == 'i' && sample[9] == 'e')
			{
				emit_sound(id, channel, SOUND_ZOMBIE_DIE[random(sizeof SOUND_ZOMBIE_DIE)], volume, attn, flags, pitch);
				return FMRES_SUPERCEDE;
			}
		}
		// weapons/knife_
		else if (sample[0] == 'w' && sample[3] == 'p' && sample[5] == 'n' && sample[8] == 'k' && sample[11] == 'f')
		{
			// weapons/knife_hit or weapons/knife_stab
			if (sample[14] == 'h' || (sample[14] == 's' && sample[17] == 'b'))
			{
				// weapons/knife_hitwall
				if (sample[17] == 'w')
					emit_sound(id, channel, SOUND_ZOMBIE_HITWALL, volume, attn, flags, pitch);
				else
					emit_sound(id, channel, SOUND_ZOMBIE_HIT[random(sizeof SOUND_ZOMBIE_HIT)], volume, attn, flags, pitch);
				
				return FMRES_SUPERCEDE;
			}
			// weapons/knife_slash
			else if (sample[14] == 's')
			{
				emit_sound(id, channel, SOUND_ZOMBIE_MISS[random(sizeof SOUND_ZOMBIE_MISS)], volume, attn, flags, pitch);
				return FMRES_SUPERCEDE;
			}
		}
	}

	return FMRES_IGNORED;
}

public OnPlayerSpawn_Post(id)
{
	if (is_user_alive(id))
	{
		if (cs_get_user_team(id) == CS_TEAM_T)
		{
			g_ZombieClass[id] = random(g_NumZombieClasses);
			MakeZombie(id);
		}
	}
}

public OnPlayerResetMaxspeed_Post(id)
{
	if (is_user_alive(id) && g_IsZombie[id])
	{
		IF_ZOMBIE_CLASS(i, id)
		{
			static attr[ZombieClassAttr];
			GET_ZOMBIE[ATTR](i, attr);
			
			set_user_maxspeed(id, attr[Zombi_Speed]);
		}

		ExecuteForward(g_Forwards[FW_SPEED], g_ForwardResult, id);
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
				static model[ZombieClassModel];
				GET_ZOMBIE[MODEL](i, model);

				set_pev(player, pev_viewmodel2, model[Zombi_vModel]);
			}

			set_pev(player, pev_weaponmodel2, "");

			ExecuteForward(g_Forwards[FW_VMODEL], g_ForwardResult, player);
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
	g_ZombieClass[id] = INVALID_ZOMBIECLASS;
}

public CmdZombieClassSet(id, level, cid)
{
	if (!cmd_access(id, level, cid, 2))
		return PLUGIN_HANDLED;
	
	new classname[32];
	read_argv(1, classname, charsmax(classname));

	new index;
	if (!FIND_ZOMBIE_BY_CLASS(classname, index))
	{
		console_print(id, "invalid zombie class ^"%s^"", classname);
		return PLUGIN_HANDLED;
	}

	new attrname[32];
	read_argv(2, attrname, charsmax(attrname));

	new arg[16];
	read_argv(3, arg, charsmax(arg));

	static attr[ZombieClassAttr];
	GET_ZOMBIE[ATTR](index, attr);

	if (equal(attrname, "hp"))
	{
		if (read_argc() == 4)
		{
			attr[Zombi_Health] = str_to_num(arg);
			SET_ZOMBIE[ATTR](index, attr);
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
			SET_ZOMBIE[ATTR](index, attr);
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
			SET_ZOMBIE[ATTR](index, attr);
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
			SET_ZOMBIE[ATTR](index, attr);
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
			SET_ZOMBIE[ATTR](index, attr);
		}
		else
		{
			console_print(id, "zombie_%s painshock is ^"%.2f^"", classname, attr[Zombi_Painshock]);
		}
	}

	return PLUGIN_HANDLED;
}

public CmdZombieClassData(id, level, cid)
{
	if (!cmd_access(id, level, cid, 1))
		return PLUGIN_HANDLED;
	
	server_print("----- [Zombie Class Data] -----")

	static info[ZombieClassInfo], attr[ZombieClassAttr];
	
	for (new i = 0; i < g_NumZombieClasses; i++)
	{
		GET_ZOMBIE[INFO](i, info);
		GET_ZOMBIE[ATTR](i, attr);

		server_print("id:%d, name:%s, class:%s", i, info[Zombi_Name], info[Zombi_Class]);
		server_print("hp:%d, gravity:%.2f, speed:%.f, painshock:%.2f, knockback:%.2f", 
			attr[Zombi_Health], attr[Zombi_Gravity], attr[Zombi_Speed], attr[Zombi_Painshock], attr[Zombi_Knockback]);
		server_print("--------------------")
	}

	return PLUGIN_HANDLED;
}

public native_zombie_register()
{
	new info[ZombieClassInfo];
	new attr[ZombieClassAttr];
	new model[ZombieClassModel];

	get_array(1, info, ZombieClassInfo);
	get_array(2, attr, ZombieClassAttr);
	get_array(3, model, ZombieClassModel);

	ArrayPushArray(g_ZombieClassData[ZOMBIE_INFO], info);
	ArrayPushArray(g_ZombieClassData[ZOMBIE_ATTR], attr);
	ArrayPushArray(g_ZombieClassData[ZOMBIE_MODEL], model);

	TrieSetCell(g_tZombieClassName, info[Zombi_Class], g_NumZombieClasses);

	PrecachePlayerModel(model[Zombi_Model]);
	precache_model(model[Zombi_vModel]);

	g_NumZombieClasses++;
	return (g_NumZombieClasses - 1);
}

public native_zombie_get_info()
{
	new index = get_param(1);
	if (!IS_VALID_ZOMBIECLASS(index))
		return 0;

	new info[ZombieClassInfo];
	GET_ZOMBIE[INFO](index, info);

	set_array(2, info, ZombieClassInfo);
	return 1;
}

public native_zombie_get_attr()
{
	new index = get_param(1);
	if (!IS_VALID_ZOMBIECLASS(index))
		return 0;

	new attr[ZombieClassAttr];
	GET_ZOMBIE[ATTR](index, attr);

	set_array(2, attr, ZombieClassAttr);
	return 1;
}

public native_zombie_get_model()
{
	new index = get_param(1);
	if (!IS_VALID_ZOMBIECLASS(index))
		return 0;

	new model[ZombieClassModel];
	GET_ZOMBIE[MODEL](index, model);

	set_array(2, model, ZombieClassModel);
	return 1;
}

public native_get_zombie_class()
{
	new id = get_param(1)
	if (!IS_VALID_PLAYER(id))
		return INVALID_ZOMBIECLASS;
	
	return g_ZombieClass[id];
}

public native_set_zombie_class()
{
	new id = get_param(1)
	if (!IS_VALID_PLAYER(id))
		return;
	
	new class = get_param(2);
	if (!IS_VALID_ZOMBIECLASS(class))
		return;
	
	g_ZombieClass[id] = class;
}

public native_is_zombie()
{
	new id = get_param(1)
	if (!IS_VALID_PLAYER(id))
		return 0;
	
	return g_IsZombie[id];
}

public native_find_zombie_by_class()
{
	new classname[32];
	get_string(1, classname, charsmax(classname));

	new index;
	if (FIND_ZOMBIE_BY_CLASS(classname, index))
		return index;
	
	return INVALID_ZOMBIECLASS;
}

MakeZombie(id)
{
	g_IsZombie[id] = true;

	strip_user_weapons(id);
	give_item(id, "weapon_knife");

	IF_ZOMBIE_CLASS(i, id)
	{
		static attr[ZombieClassAttr], model[ZombieClassModel];
		GET_ZOMBIE[ATTR](i, attr);
		GET_ZOMBIE[MODEL](i, model)

		set_user_health(id, attr[Zombi_Health]);
		set_user_gravity(id, attr[Zombi_Gravity]);
		ExecuteHamB(Ham_CS_Player_ResetMaxSpeed, id);

		cs_set_user_model(id, model[Zombi_Model]);
	}

	ExecuteForward(g_Forwards[FW_ZOMBIE], g_ForwardResult, id);
}