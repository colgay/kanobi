#include <amxmodx>
#include <amxmisc>
#include <fun>
#include <cstrike>
#include <fakemeta>
#include <hamsandwich>

#include <kanobi_util>

#define VERSION "0.1"

#define Invalid_ZombieClass -1
#define IsValidZombieClass(%1) (0 <= %1 < g_NumZombieClasses)
#define IsValidPlayer(%1) (1 <= %1 <= MaxClients)

#define IF_ZOMBIE_CLASS(%1,%2) \
	for (new %1 = 0; %1 < g_NumZombieClasses; %1++) \
		if (g_PlayerClass[%2] == %1)

enum _:ZombieClass_t
{
    Array:Zombi_Name,
    Array:Zombi_Desc,
    Array:Zombi_Class,
    Array:Zombi_Flags,
    Array:Zombi_Model,
    Array:Zombi_vModel,
    Array:Zombi_Health,
    Array:Zombi_Gravity,
    Array:Zombi_Speed,
    Array:Zombi_Painshock,
    Array:Zombi_Knockback,
    Trie:Zombi_Map
};

enum _:Forward_t
{
    Fwd_Zombie,
    Fwd_vModel,
    Fwd_Speed
};

new const SOUND_ZOMBIE_HIT[][] = {"zombie/claw_strike1.wav", "zombie/claw_strike2.wav", "zombie/claw_strike3.wav"};
new const SOUND_ZOMBIE_HITWALL[] = "weapons/bullet_hit1.wav";
new const SOUND_ZOMBIE_MISS[][] = {"zombie/claw_miss1.wav", "zombie/claw_miss2.wav"};
new const SOUND_ZOMBIE_HURT[][] = {"zombie/zo_pain1.wav", "zombie/zo_pain2.wav"};
new const SOUND_ZOMBIE_DIE[][] = {"zombie/zo_pain1.wav", "zombie/zo_pain2.wav"};

new g_IsZombie[MAX_PLAYERS + 1];
new g_PlayerClass[MAX_PLAYERS + 1];

new g_ZombieClasses[ZombieClass_t];
new g_NumZombieClasses;

new g_Forward[Forward_t];
new g_ForwardResult;

public plugin_precache()
{
    g_ZombieClasses[Zombi_Name] = ArrayCreate(32);
    g_ZombieClasses[Zombi_Desc] = ArrayCreate(32);
    g_ZombieClasses[Zombi_Class] = ArrayCreate(32);
    g_ZombieClasses[Zombi_Flags] = ArrayCreate(1);
    g_ZombieClasses[Zombi_Model] = ArrayCreate(32);
    g_ZombieClasses[Zombi_vModel] = ArrayCreate(64);
    g_ZombieClasses[Zombi_Health] = ArrayCreate(1);
    g_ZombieClasses[Zombi_Gravity] = ArrayCreate(1);
    g_ZombieClasses[Zombi_Speed] = ArrayCreate(1);
    g_ZombieClasses[Zombi_Painshock] = ArrayCreate(1);
    g_ZombieClasses[Zombi_Knockback] = ArrayCreate(1);
    g_ZombieClasses[Zombi_Map] = TrieCreate();

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
	register_concmd("zombieclasses", "CmdZombieClasses", ADMIN_CVAR, "");

    g_Forward[Fwd_Zombie] = CreateMultiForward("kanobi_OnMakeZombie", ET_IGNORE, FP_CELL);
    g_Forward[Fwd_Speed] = CreateMultiForward("kanobi_OnZombieSetSpeed", ET_IGNORE, FP_CELL);
    g_Forward[Fwd_vModel] = CreateMultiForward("kanobi_OnZombieSetHands", ET_IGNORE, FP_CELL);
}

public plugin_natives()
{
    register_library("kanobi_zombie");

    register_native("kanobi_RegisterZombie", "native_register_zombie");
    register_native("kanobi_GetZombieClassHandle", "native_get_zombie_class_handle");
    register_native("kanobi_GetZombieClassNum", "native_get_zombie_class_num");
    register_native("kanobi_FindZombieByClass", "native_find_zombie_by_class");
    register_native("kanobi_GetZombieClass", "native_get_zombie_class");
    register_native("kanobi_SetZombieClass", "native_set_zombie_class");
    register_native("kanobi_IsZombie", "native_is_zombie");
    register_native("kanobi_MakeZombie", "native_make_zombie");
}

public CmdZombieClassSet(id, level, cid)
{
	if (!cmd_access(id, level, cid, 2))
		return PLUGIN_HANDLED;
	
	new classname[32];
	read_argv(1, classname, charsmax(classname));

	new index;
	if (!TrieGetCell(g_ZombieClasses[Zombi_Map], classname, index))
	{
		console_print(id, "invalid zombie class ^"%s^"", classname);
		return PLUGIN_HANDLED;
	}

	new attr[32];
	read_argv(2, attr, charsmax(attr));

	new arg[16];
	read_argv(3, arg, charsmax(arg));

	if (equal(attr, "hp"))
	{
		if (read_argc() == 4)
		{
			ArraySetCell(g_ZombieClasses[Zombi_Health], index, str_to_num(arg));
		}
		else
		{
			console_print(id, "zombie_%s hp is ^"%d^"", classname, ArrayGetCell(g_ZombieClasses[Zombi_Health], index));
		}
	}
	else if (equal(attr, "gravity"))
	{
		if (read_argc() == 4)
		{
			ArraySetCell(g_ZombieClasses[Zombi_Gravity], index, str_to_float(arg));
		}
		else
		{
			console_print(id, "zombie_%s gravity is ^"%.2f^"", classname, Float:ArrayGetCell(g_ZombieClasses[Zombi_Gravity], index));
		}
	}
	else if (equal(attr, "speed"))
	{
		if (read_argc() == 4)
		{
			ArraySetCell(g_ZombieClasses[Zombi_Speed], index, str_to_float(arg));
		}
		else
		{
			console_print(id, "zombie_%s speed is ^"%.2f^"", classname, Float:ArrayGetCell(g_ZombieClasses[Zombi_Speed], index));
		}
	}
	else if (equal(attr, "knockback"))
	{
		if (read_argc() == 4)
		{
			ArraySetCell(g_ZombieClasses[Zombi_Knockback], index, str_to_float(arg));
		}
		else
		{
			console_print(id, "zombie_%s knockback is ^"%.2f^"", classname, Float:ArrayGetCell(g_ZombieClasses[Zombi_Knockback], index));
		}
	}
	else if (equal(attr, "painshock"))
	{
		if (read_argc() == 4)
		{
			ArraySetCell(g_ZombieClasses[Zombi_Painshock], index, str_to_float(arg));
		}
		else
		{
			console_print(id, "zombie_%s painshock is ^"%.2f^"", classname, Float:ArrayGetCell(g_ZombieClasses[Zombi_Painshock], index));
		}
	}

	return PLUGIN_HANDLED;
}

public CmdZombieClasses(id, level, cid)
{
	if (!cmd_access(id, level, cid, 1))
		return PLUGIN_HANDLED;
	
	server_print("----- [Zombie Classes] -----")

	for (new i = 0; i < g_NumZombieClasses; i++)
	{
		server_print("id:%d, name:%a, class:%a", i, ArrayGetStringHandle(g_ZombieClasses[Zombi_Name], i),
            ArrayGetStringHandle(g_ZombieClasses[Zombi_Class], i));

		server_print("hp:%d, gravity:%.2f, speed:%.f, painshock:%.2f, knockback:%.2f", 
			ArrayGetCell(g_ZombieClasses[Zombi_Health], i), Float:ArrayGetCell(g_ZombieClasses[Zombi_Gravity], i), 
            Float:ArrayGetCell(g_ZombieClasses[Zombi_Speed], i), Float:ArrayGetCell(g_ZombieClasses[Zombi_Painshock], i), 
            Float:ArrayGetCell(g_ZombieClasses[Zombi_Knockback], i));

		server_print("--------------------")
	}

	return PLUGIN_HANDLED;
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
			g_PlayerClass[id] = random(g_NumZombieClasses);
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
			set_user_maxspeed(id, Float:ArrayGetCell(g_ZombieClasses[Zombi_Speed], i));
		}

        ExecuteForward(g_Forward[Fwd_Speed], g_ForwardResult, id);
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
				new model[32];
				ArrayGetString(g_ZombieClasses[Zombi_vModel], i, model, charsmax(model));

				set_pev(player, pev_viewmodel2, model);
			}

			set_pev(player, pev_weaponmodel2, "");

            ExecuteForward(g_Forward[Fwd_vModel], g_ForwardResult, player);
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
	g_PlayerClass[id] = Invalid_ZombieClass;
}

MakeZombie(id)
{
	g_IsZombie[id] = true;

	strip_user_weapons(id);
	give_item(id, "weapon_knife");

    IF_ZOMBIE_CLASS(i, id)
    {
        set_user_health(id, ArrayGetCell(g_ZombieClasses[Zombi_Health], i));
        set_user_gravity(id, Float:ArrayGetCell(g_ZombieClasses[Zombi_Gravity], i));

        ExecuteHamB(Ham_CS_Player_ResetMaxSpeed, id);

        new model[32];
        ArrayGetString(g_ZombieClasses[Zombi_Model], i, model, charsmax(model));
        cs_set_user_model(id, model);
    }

    ExecuteForward(g_Forward[Fwd_Zombie], g_ForwardResult, id);
}

public native_register_zombie()
{
    new name[32], desc[32], class[32];
    get_string(1, name, charsmax(name));
    get_string(2, desc, charsmax(desc));
    get_string(3, class, charsmax(class));

    new flags = get_param(4);

    new model[32], vmodel[64];
    get_string(5, model, charsmax(model));
    get_string(6, vmodel, charsmax(vmodel));

    
    new health = get_param(7);
    new Float:gravity = get_param_f(8);
    new Float:speed = get_param_f(9);
    new Float:painshock = get_param_f(10);
    new Float:knockback = get_param_f(11);

    ArrayPushString(g_ZombieClasses[Zombi_Name], name);
    ArrayPushString(g_ZombieClasses[Zombi_Desc], desc);
    ArrayPushString(g_ZombieClasses[Zombi_Class], class);
    ArrayPushCell(g_ZombieClasses[Zombi_Flags], flags);
    ArrayPushString(g_ZombieClasses[Zombi_Model], model);
    ArrayPushString(g_ZombieClasses[Zombi_vModel], vmodel);
    ArrayPushCell(g_ZombieClasses[Zombi_Health], health);
    ArrayPushCell(g_ZombieClasses[Zombi_Gravity], gravity);
    ArrayPushCell(g_ZombieClasses[Zombi_Speed], speed);
    ArrayPushCell(g_ZombieClasses[Zombi_Painshock], painshock);
    ArrayPushCell(g_ZombieClasses[Zombi_Knockback], knockback);

    TrieSetCell(g_ZombieClasses[Zombi_Map], class, g_NumZombieClasses);

    PrecachePlayerModel(model);
    precache_model(vmodel);

    g_NumZombieClasses++;
    return (g_NumZombieClasses - 1);
}

public native_get_zombie_class_handle()
{
    set_array(1, g_ZombieClasses, ZombieClass_t);
}

public native_find_zombie_by_class()
{
    new classname[32];
    get_string(1, classname, charsmax(classname));

    new zombieid;
    if (TrieGetCell(g_ZombieClasses[Zombi_Map], classname, zombieid))
        return zombieid;

    return Invalid_ZombieClass;
}

public native_get_zombie_class()
{
    new id = get_param(1);
    if (!IsValidPlayer(id))
        return Invalid_ZombieClass;
    
    return g_PlayerClass[id];
}

public native_set_zombie_class()
{
    new id = get_param(1);
    if (!IsValidPlayer(id))
        return;

    new value = get_param(2);
    if (!IsValidZombieClass(value))
        return;
    
    g_PlayerClass[id] = value;
}

public native_is_zombie()
{
    new id = get_param(1);
    if (!IsValidPlayer(id))
        return 0;
        
    return g_IsZombie[id];
}

public native_make_zombie()
{
    new id = get_param(1);
    if (!IsValidPlayer(id))
        return;
    
    MakeZombie(id);
}

public
 native_get_zombie_class_num()
{
    return g_NumZombieClasses;
}