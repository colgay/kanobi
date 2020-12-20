#include <amxmodx>
#include <fun>
#include <cstrike>
#include <engine>
#include <fakemeta>
#include <hamsandwich>

#include <weapon_ammo>
#include <cs_money>

#define VERSION "0.1"

#define Menu_ChooseAppearance 3
#define PlayerHasPistol(%1) (get_ent_data_entity(%1, "CBasePlayer", "m_rgpPlayerItems", 2))

const PRIM_GUN_END_IDX = 18;
const SEC_GUN_END_IDX = 24;

const WEAPON_SUIT = 31;
const WEAPON_SUIT_BIT = 1 << WEAPON_SUIT;

enum (+=100)
{
	TASK_RESPAWN = 0,
};

new const OBJECTIVE_CLASSNAME[][] = {
	"func_bomb_target",
	"info_bomb_target",
	"info_vip_start",
	"func_vip_safetyzone",
	"func_escapezone",
	"hostage_entity",
	"monster_scientist",
	"func_hostage_rescue",
	"info_hostage_rescue",
	"func_buyzone"
};

new const g_WeaponIndex[] = {
	CSW_SCOUT, CSW_XM1014, CSW_MAC10, CSW_AUG, CSW_UMP45, CSW_SG550, CSW_GALIL, CSW_FAMAS, CSW_AWP, 
	CSW_MP5NAVY, CSW_M249, CSW_M3, CSW_M4A1, CSW_TMP, CSW_G3SG1, CSW_SG552, CSW_AK47, CSW_P90, 
	CSW_P228, CSW_ELITE, CSW_FIVESEVEN, CSW_USP, CSW_GLOCK18, CSW_DEAGLE
};

new const g_WeaponName[][] = {
	"", "P228", "", "Scout", "HE Grenade", "XM1014", "C4", "MAC10", "AUG", "Smoke Grenade", "Dual Elite", "Fiveseven", "UMP45",
	"SG550", "Galil", "Famas", "USP", "Glock 18", "AWP", "MP5 navy", "M249", "M3", "M4A1", "TMP", "G3SG1", "Flashbang", "Deagle",
	"SG552", "AK47", "Knife", "P90"
};

new g_fwdEntSpawn;

new g_CvarWeapons[32];
new g_CvarLight[32];
new Float:g_CvarRespawnTime[2];

new g_PrimaryGun[MAX_PLAYERS + 1];
new g_SecondaryGun[MAX_PLAYERS + 1];

new gmsgBlinkAcct;

public plugin_precache()
{
	g_fwdEntSpawn = register_forward(FM_Spawn, "OnEntSpawn");

	BlockBuying();

	wammo_init();
}

public plugin_init()
{
	register_plugin("Kano-bi", VERSION, "peter5001");

	register_logevent("EventJoinTeam", 3, "1=joined team");
	register_event("HLTV", "EventNewRound", "a", "1=0", "2=0");

	register_forward(FM_EmitSound, "OnEmitSound");
	unregister_forward(FM_Spawn, g_fwdEntSpawn);

	RegisterHam(Ham_TakeDamage, "player", "OnTakeDamage");
	//RegisterHam(Ham_TakeDamage, "player", "OnTakeDamage_Post", 1);

	RegisterHam(Ham_Spawn, "player", "OnPlayerSpawn");
	RegisterHam(Ham_Spawn, "player", "OnPlayerSpawn_Post", 1);
	RegisterHam(Ham_Killed, "player", "OnPlayerKilled");
	//RegisterHam(Ham_CS_Player_ResetMaxSpeed, "player", "OnPlayerResetMaxspeed_Post", 1);
	//RegisterHam(Ham_Item_Deploy, "weapon_knife", "OnKnifeDeploy_Post", 1);

	register_menucmd(register_menuid("Weapon Menu"), 1023, "HandleWeaponMenu");

	register_clcmd("buyammo1", "ClCmd_buyammo1");
	register_clcmd("buyammo2", "ClCmd_buyammo2");
	register_clcmd("primammo", "ClCmd_primammo");
	register_clcmd("secammo", "ClCmd_secammo");

	register_clcmd("joinclass", "ClCmd_joinclass");

	set_cvar_num("mp_autoteambalance", 0);
	set_cvar_num("mp_limitteams", 0);

	RegisterCvars();
	CreateForwards();

	gmsgBlinkAcct = get_user_msgid("BlinkAcct");

	set_lights(g_CvarLight);
}

public EventJoinTeam()
{
	// copying code
	new loguser[80], name[32];
	read_logargv(0, loguser, charsmax(loguser));
	parse_loguser(loguser, name, charsmax(name));

	new id = get_user_index(name);

	if (!is_user_connected(id))
	{
		return;
	}

	new team[2];
	read_logargv(2, team, charsmax(team));

	if (is_user_bot(id))
	{
		if (team[0] == 'C') // bot trying to join CT
		{
			cs_set_user_team(id, CS_TEAM_T);
		}
	}
	else
	{
		if (team[0] == 'T') // player trying to join T
		{
			cs_set_user_team(id, CS_TEAM_CT);
		}

		csm_set_money(id, 16000, 0);
	}
}

public EventNewRound()
{
	for (new i = 1; i <= MaxClients; i++)
	{
		if (is_user_connected(i) && cs_get_user_team(i) == CS_TEAM_CT)
		{
			csm_set_money(i, csm_get_money(i) + 1000, 0);
		}
	}
}

public ClCmd_buyammo1(id)
{
	if (cs_get_user_hasprim(id))
	{
		BuyAmmo(id, 0);
	}

	return PLUGIN_HANDLED_MAIN;
}

public ClCmd_primammo(id)
{
	if (cs_get_user_hasprim(id))
	{
		while (BuyAmmo(id, 0)) { }
	}

	return PLUGIN_HANDLED_MAIN;
}

public ClCmd_buyammo2(id)
{
	if (PlayerHasPistol(id))
	{
		BuyAmmo(id, 1);
	}

	return PLUGIN_HANDLED_MAIN;
}

public ClCmd_secammo(id)
{
	if (PlayerHasPistol(id))
	{
		while (BuyAmmo(id, 1)) { }
	}

	return PLUGIN_HANDLED_MAIN;
}

public ClCmd_joinclass(id)
{
	if (get_ent_data(id, "CBasePlayer", "m_iMenu") == Menu_ChooseAppearance)
	{
		remove_task(id + TASK_RESPAWN);
		set_task(g_CvarRespawnTime[1], "RespawnPlayer", id + TASK_RESPAWN);
	}
}

public OnEntSpawn(ent)
{
	if (!pev_valid(ent))
		return FMRES_IGNORED;
	
	new classname[32];
	pev(ent, pev_classname, classname, charsmax(classname));

	for (new i = 0; i < sizeof(OBJECTIVE_CLASSNAME); i++)
	{
		if (equal(classname, OBJECTIVE_CLASSNAME[i]))
		{
			remove_entity(ent);
			return FMRES_SUPERCEDE;
		}
	}

	return FMRES_IGNORED;
}

public OnTakeDamage(id, inflictor, attacker)
{
	if (!is_user_bot(id))
	{
		set_user_health(id, get_user_health(id) + 100);
	}
	
	return HAM_IGNORED;
}

public OnPlayerSpawn(id)
{
	if (!is_user_connected(id))
		return;
	
	if (pev_valid(id) == 2 && (1 <= get_ent_data(id, "CBasePlayer", "m_iTeam") <= 2))
	{
		set_ent_data(id, "CBasePlayer", "m_bNotKilled", true);

		new weapons = pev(id, pev_weapons);
		
		if (~weapons & WEAPON_SUIT_BIT)
			set_pev(id, pev_weapons, weapons | WEAPON_SUIT_BIT);
	}
}

public OnPlayerSpawn_Post(id)
{
	if (!is_user_alive(id))
		return;

	remove_task(id + TASK_RESPAWN);
	
	switch (cs_get_user_team(id))
	{
		case CS_TEAM_T:
		{
			// do nothing
		}
		case CS_TEAM_CT:
		{
			Human(id);
		}
	}
}

public OnPlayerKilled(id, killer)
{
	remove_task(id + TASK_RESPAWN);

	switch (cs_get_user_team(id))
	{
		case CS_TEAM_T:
		{
			if (is_user_connected(killer) && !is_user_bot(killer))
				csm_set_money(killer, csm_get_money(killer) + 500, 1);

			set_task(g_CvarRespawnTime[0], "RespawnPlayer", id + TASK_RESPAWN);
		}
		case CS_TEAM_CT:
			set_task(g_CvarRespawnTime[1], "RespawnPlayer", id + TASK_RESPAWN);
	}
}

public client_disconnected(id)
{
	g_PrimaryGun[id] = 0;
	g_SecondaryGun[id] = 0;

	remove_task(id + TASK_RESPAWN);
}

public RespawnPlayer(taskid)
{
	new id = taskid - TASK_RESPAWN;

	if (is_user_alive(id) || !(CS_TEAM_T <= cs_get_user_team(id) <= CS_TEAM_CT))
		return;
	
	ExecuteHam(Ham_CS_RoundRespawn, id);
}

public ShowWeaponMenu(id)
{
	static menu[512], len;
	len = formatex(menu, charsmax(menu), "\yWeapon Menu^n^n");

	len += formatex(menu[len], 511-len, "1.\w Primary: ");

	if (!g_PrimaryGun[id])
		len += formatex(menu[len], 511-len, "\d---^n");
	else
		len += formatex(menu[len], 511-len, "\y%s^n", g_WeaponName[g_PrimaryGun[id]]);

	len += formatex(menu[len], 511-len, "\y2.\w Secondary: ");

	if (!g_SecondaryGun[id])
		len += formatex(menu[len], 511-len, "\d---^n");
	else
		len += formatex(menu[len], 511-len, "\y%s^n", g_WeaponName[g_SecondaryGun[id]]);
	
	len += formatex(menu[len], 511-len, "\y5.\w Confirm^n^n\y0.\w Exit");

	show_menu(id, MENU_KEY_1|MENU_KEY_2|MENU_KEY_5|MENU_KEY_0, menu, -1, "Weapon Menu");
}

public HandleWeaponMenu(id, key)
{
	if (!is_user_alive(id))
		return;
	
	switch (key + 1)
	{
		case 1: ChoosePrimaryGunMenu(id);
		case 2: ChooseSecondaryGunMenu(id);
		case 5:
		{
			GivePlayerWeapon(id, g_PrimaryGun[id], true);
			GivePlayerWeapon(id, g_SecondaryGun[id], true);
		}
	}
}

public ChoosePrimaryGunMenu(id)
{
	new flags = read_flags(g_CvarWeapons);
	server_print("flags is %s", g_CvarWeapons);

	new menu = menu_create("Choose a Primary Weapon:", "HandlePrimaryGunMenu");
	new weaponid, weaponname[32];

	static buffer[64];

	for (new i = 0; i < PRIM_GUN_END_IDX; i++)
	{
		if (flags & (1 << i))
		{
			weaponid = g_WeaponIndex[i];
			get_weaponname(weaponid, weaponname, charsmax(weaponname));

			formatex(buffer, charsmax(buffer), "%s", g_WeaponName[weaponid]);
			menu_additem(menu, buffer, weaponname);
		}
	}

	menu_additem(menu, "None", "none");

	menu_display(id, menu);
}

public HandlePrimaryGunMenu(id, menu, item)
{
	if (item == MENU_EXIT)
	{
		menu_destroy(menu);
		ShowWeaponMenu(id);
		return;
	}

	new weaponname[32], dummy;
	menu_item_getinfo(menu, item, dummy, weaponname, charsmax(weaponname), _, _, dummy);
	menu_destroy(menu);

	if (equal(weaponname, "none"))
	{
		g_PrimaryGun[id] = 0;
		ShowWeaponMenu(id);
	}
	else
	{
		new weaponid = get_weaponid(weaponname);
		g_PrimaryGun[id] = weaponid;

		client_print(id, print_chat, "You have selected ^"%s^" as your primary weapon.", g_WeaponName[weaponid]);

		ShowWeaponMenu(id);
	}
}

public ChooseSecondaryGunMenu(id)
{
	new flags = read_flags(g_CvarWeapons);

	new menu = menu_create("Choose a Secondary Weapon:", "HandleSecondaryGunMenu");
	new weaponid, weaponname[32];

	static buffer[64];

	for (new i = PRIM_GUN_END_IDX; i < SEC_GUN_END_IDX; i++)
	{
		if (flags & (1 << i))
		{
			weaponid = g_WeaponIndex[i];
			get_weaponname(weaponid, weaponname, charsmax(weaponname));

			formatex(buffer, charsmax(buffer), "%s", g_WeaponName[weaponid]);
			menu_additem(menu, buffer, weaponname);
		}
	}

	menu_additem(menu, "None", "none");

	menu_display(id, menu);
}

public HandleSecondaryGunMenu(id, menu, item)
{
	if (item == MENU_EXIT)
	{
		menu_destroy(menu);
		ShowWeaponMenu(id);
		return;
	}

	new weaponname[32], dummy;
	menu_item_getinfo(menu, item, dummy, weaponname, charsmax(weaponname), _, _, dummy);
	menu_destroy(menu);

	if (equal(weaponname, "none"))
	{
		g_SecondaryGun[id] = 0;
		ShowWeaponMenu(id);
	}
	else
	{
		new weaponid = get_weaponid(weaponname);
		g_SecondaryGun[id] = weaponid;

		client_print(id, print_chat, "You have selected ^"%s^" as your secondary weapon.", g_WeaponName[weaponid]);

		ShowWeaponMenu(id);
	}
}

public HookCvarLight(pcvar, const old_value[], const new_value[])
{
	set_lights(new_value);
}

RegisterCvars()
{
	new pcvar = create_cvar("kano_weapons", "acejnrsuvw");
	bind_pcvar_string(pcvar, g_CvarWeapons, charsmax(g_CvarWeapons));

	pcvar = create_cvar("kano_zombie_respawn_time", "3");
	bind_pcvar_float(pcvar, g_CvarRespawnTime[0]);

	pcvar = create_cvar("kano_human_respawn_time", "10");
	bind_pcvar_float(pcvar, g_CvarRespawnTime[1]);

	pcvar = create_cvar("kano_light", "d");
	bind_pcvar_string(pcvar, g_CvarLight, charsmax(g_CvarLight));
	hook_cvar_change(pcvar, "HookCvarLight");

	register_cvar("zh_zombie_maxslots", "14");
}

CreateForwards()
{
	// no forward yet
}

stock bool:BuyAmmo(id, mode)
{
	new weapons = pev(id, pev_weapons);
	new bool:hasweapon, bool:canbuy, bool:bought;

	new maxammo, cost;
	new money = csm_get_money(id);

	for (new i = 1; i < AmmoIds; i++)
	{
		maxammo = AMMO_DATAS[i][AmmoMax];
		
		if (get_ent_data(id, "CBasePlayer", "m_rgAmmo", i) < maxammo)
		{
			cost = AMMO_DATAS[i][AmmoCost];

			if (weapons & AMMO_WEAPON_SHARED_BITS[i][mode])
			{
				hasweapon = true;

				if (money >= cost)
				{
					canbuy = true;

					if (ExecuteHamB(Ham_GiveAmmo, id, AMMO_DATAS[i][AmmoAmt], AMMO_NAMES[i], maxammo) != -1)
					{
						bought = true;
						money -= cost;
					}
				}
			}
		}
	}

	if (!hasweapon)
	{
		return false;
	}

	if (!canbuy)
	{
		NotEnoughMoney(id)
		return false;
	}

	if (!bought)
	{
		return false;
	}

	// make player emit the sound as we don't create any ammo entity
	emit_sound(id, CHAN_ITEM, _SOUND_PICK_AMMO, VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
	csm_set_money(id, money, 1);
	return true;
}

stock Human(id)
{
	if (!user_has_weapon(id, CSW_KNIFE))
		give_item(id, "weapon_knife");

	ShowWeaponMenu(id);
}

stock BlockBuying()
{
    new ent = create_entity("info_map_parameters");
    DispatchKeyValue(ent, "buying", "3");
    DispatchSpawn(ent);

    server_cmd("sv_restart 1");
}

stock GivePlayerWeapon(id, weaponid, bool:ammo=true)
{
	if (!weaponid)
		return;

	new weaponname[32];
	get_weaponname(weaponid, weaponname, charsmax(weaponname));

	if (weaponname[0])
	{
		give_item(id, weaponname);

		if (ammo)
			wammo_give_weapon_full(id, weaponid);
	}
}

stock NotEnoughMoney(id)
{
	client_print(id, print_center, "#Cstrike_TitlesTXT_Not_Enough_Money");

	message_begin(MSG_ONE, gmsgBlinkAcct, .player=id);
	write_byte(2);
	message_end();
}