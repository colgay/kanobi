#if !defined _fakemeta_included
	#include <fakemeta>
#endif

#if !defined _hamsandwich_included
	#include <hamsandwich>
#endif

#if defined _weapon_ammo_included
  #endinput
#endif
#define _weapon_ammo_included

enum _:AmmoIds
{
	ammo_none,
	ammo_338magnum = 1,
	ammo_762nato,
	ammo_556natobox,
	ammo_556nato,
	ammo_buckshot,
	ammo_45acp,
	ammo_57mm,
	ammo_50ae,
	ammo_357sig,
	ammo_9mm
};

enum _:AmmoDatas
{
	AmmoAmt,
	AmmoCost,
	AmmoMax
};

new const AMMO_NAMES[AmmoIds][] = {
	"",
	"338magnum",
	"762nato",
	"556natobox",
	"556nato",
	"buckshot",
	"45acp",
	"57mm",
	"50ae",
	"357sig",
	"9mm"
};

new AMMO_DATAS[AmmoIds][AmmoDatas] = {
	{-1,  -1,  -1},
	{10, 125,  30}, // 338magnum
	{30,  80,  90}, // 762nato
	{30,  60, 200}, // 556natobox
	{30,  60,  90}, // 556nato
	{ 8,  65,  32}, // buckshot
	{12,  25, 100}, // 45acp
	{50,  50, 100}, // 57mm
	{ 7,  40,  35}, // 50ae
	{13,  50,  52}, // 357sig
	{30,  20, 120}  // 9mm
};

new const WEAPON_AMMO_TYPES[] = 
{
	0,
	9, //p228
	0,
	2, //scout
	12, //hegrenade
	5, //xm1014
	14, //c4
	6, //mac10
	4, //aug
	13, //smoke
	10, //elite
	7, //fiveseven
	6, //ump45
	4, //sg550
	4, //galil
	4, //famas
	6, //usp
	10, //glock
	1, //awp
	10, //mp5
	3, //m249
	5, //m3
	4, //m4a1
	10, //tmp
	2, //g3sg1
	11, //flash
	8, //deagle
	4, //sg552
	2, //ak47
	0,
	7 //p90
};

new const AMMO_WEAPON_SHARED_BITS[AmmoIds][2] = {
	{0, 0},
	{(1<<CSW_AWP), 0},
	{(1<<CSW_SCOUT)|(1<<CSW_G3SG1)|(1<<CSW_AK47), 0},
	{(1<<CSW_M249), 0},
	{(1<<CSW_AUG)|(1<<CSW_SG550)|(1<<CSW_GALIL)|(1<<CSW_FAMAS)|(1<<CSW_M4A1)|(1<<CSW_SG552), 0},
	{(1<<CSW_XM1014)|(1<<CSW_M3), 0},
	{(1<<CSW_MAC10)|(1<<CSW_UMP45), (1<<CSW_USP)},
	{(1<<CSW_P90), (1<<CSW_FIVESEVEN)},
	{0, (1<<CSW_DEAGLE)},
	{0, (1<<CSW_P228)},
	{(1<<CSW_MP5NAVY)|(1<<CSW_TMP), (1<<CSW_ELITE)|(1<<CSW_GLOCK18)}
};

new const _SOUND_PICK_AMMO[] = "items/9mmclip1.wav";

stock wammo_init()
{
	precache_sound(_SOUND_PICK_AMMO);
}

stock wammo_get_ent_type(ent)
{
	if (pev_valid(ent))
		return get_ent_data(ent, "CBasePlayerWeapon", "m_iPrimaryAmmoType");
	
	return 0;
}

stock wammo_give(player, type, amount=0, max=0)
{
	if (!amount)
		amount = AMMO_DATAS[type][AmmoAmt];

	if (!max)
		max = AMMO_DATAS[type][AmmoMax];
	
	new ammo = get_ent_data(player, "CBasePlayer", "m_rgAmmo", type);

	ExecuteHamB(Ham_GiveAmmo, player, amount, AMMO_NAMES[type], max);
	
	if (ammo >= max)
		return false;
	
	emit_sound(player, CHAN_ITEM, _SOUND_PICK_AMMO, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
	return true;
}

stock wammo_give_full(player, type)
{
	wammo_give(player, type, AMMO_DATAS[type][AmmoMax], AMMO_DATAS[type][AmmoMax]);
}

stock wammo_give_weapon(player, weapon, amount=0, max=0)
{
	new type = WEAPON_AMMO_TYPES[weapon];
	return wammo_give(player, type, amount, max);
}

stock wammo_give_weapon_full(player, weapon)
{
	new type = WEAPON_AMMO_TYPES[weapon];
	wammo_give_full(player, type);
}