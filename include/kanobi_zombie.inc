#if defined _kanobi_zombie_included
	#endinput
#endif
#define _kanobi_zombie_included

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

native kanobi_RegisterZombie(info[ZombieClassInfo_t], attr[ZombieClassAttr_t], const model[], const vmodel[]);

native kanobi_RegisterZombie2(const name[], const desc[], const classname[], flags, health, Float:gravity, Float:speed,
	Float:painshock, Float:knockback, const model[], const vmodel[]);


native kanobi_GetZombieInfo(zombieid, info[ZombieClassInfo_t]);
native kanobi_GetZombieAttr(zombieid, attr[ZombieClassInfo_t]);

native kanobi_FindZombieByClass(const classname[]);

native kanobi_GetZombieClass(id);
native kanobi_SetZombieClass(id, value);

native kanobi_IsZombie(id);