#include <amxmodx>
#include <amxmisc>
#include <cstrike>
#include <fakemeta>
#include <hamsandwich>
#include <xs>

new g_Forward;
new g_ForwardResult;

new Trie:g_tKnockback;
new Float:g_OldVelocity[MAX_PLAYERS + 1][3];

public plugin_precache()
{
	g_tKnockback = TrieCreate();
}

public plugin_init()
{
	register_plugin("Knockback", "0.1", "peter5001");

	RegisterHam(Ham_TakeDamage, "player", "OnTakeDamage");
	RegisterHam(Ham_TakeDamage, "player", "OnTakeDamage_Post", 1);
	RegisterHam(Ham_TraceAttack, "player", "OnTraceAttack");

	register_concmd("knockback_set", "CmdKnockback", ADMIN_CVAR, "<weapon name> <power>");

	g_Forward = CreateMultiForward("knockback_on_traceattack", ET_IGNORE, FP_CELL, FP_CELL, FP_FLOAT, );
}

public CmdKnockback(id, level, cid)
{
	if (!cmd_access(id, level, cid, 2))
		return PLUGIN_HANDLED;
	
	new wpn_name[32] = "weapon_";
	read_argv(1, wpn_name[7], charsmax(wpn_name) - 7);

	new wpnid = get_weaponid(wpn_name);
	if (!wpnid || (~CSW_ALL_GUNS & (1 << wpnid)))
	{
		console_print(id, "invalid weapon name ^"%s^".", wpn_name[7]);
		return PLUGIN_HANDLED;
	}

	if (read_argc() == 2)
	{
		new Float:value;
		if (TrieGetCell(g_tKnockback, wpn_name[7], value))
		{
			console_print(id, "^"%s^" knockback is ^"%.2f^"", wpn_name[7], value);
			return PLUGIN_HANDLED;
		}

		return PLUGIN_HANDLED;
	}

	new arg[10];
	read_argv(2, arg, charsmax(arg));

	new Float:value = str_to_float(arg);
	TrieSetCell(g_tKnockback, wpn_name[7], value);

	console_print(id, "set ^"%s^" knockback to ^"%.2f^"", wpn_name[7], value);

	return PLUGIN_HANDLED;
}

public OnTakeDamage(id, inflictor, attacker, Float:damage, damagebits)
{
	if (inflictor == attacker && is_user_connected(attacker) && (damagebits & DMG_BULLET))
	{
		new wpnid = get_user_weapon(attacker);
		if (CSW_ALL_GUNS & (1 << wpnid))
		{
			pev(id, pev_velocity, g_OldVelocity[id]);
		}
	}
}

public OnTakeDamage_Post(id, inflictor, attacker, Float:damage, damagebits)
{
	if (inflictor == attacker && is_user_connected(attacker) && (damagebits & DMG_BULLET))
	{
		new wpnid = get_user_weapon(attacker);
		if (CSW_ALL_GUNS & (1 << wpnid))
		{
			set_pev(id, pev_velocity, g_OldVelocity[id]);
		}
	}
}

public OnTraceAttack(id, attacker, Float:damage, Float:direction[3], tracehandle, damagebits)
{
	if (!is_user_connected(attacker))
		return;

	new wpnid = get_user_weapon(attacker);
	if (~CSW_ALL_GUNS & (1 << wpnid))
		return;
	
	new wpn_name[32];
	get_weaponname(wpnid, wpn_name, charsmax(wpn_name));

	new Float:power;
	if (TrieGetCell(g_tKnockback, wpn_name[7], power))
	{
		new Float:vector[3];
		vector = direction;
		xs_vec_mul_scalar(vector, power, vector);

		new Float:velocity[3];
		pev(id, pev_velocity, velocity);

		xs_vec_add(velocity, vector, velocity);
		set_pev(id, pev_velocity, velocity);
	}
}