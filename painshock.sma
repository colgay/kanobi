#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>

#include <orpheu>

#define IS_VALID_PLAYER(%1) (1 <= %1 <= MaxClients)

const Float:MAX_PAINSHOCK_TIME = 3.5;

new OrpheuStruct:g_ppmove;

new Float:g_PainShock[MAX_PLAYERS + 1];
new Float:g_PainShockTime[MAX_PLAYERS + 1];
new Float:g_PainShockCheckTime[MAX_PLAYERS + 1];

public plugin_init()
{
    register_plugin("Pain Shock", "0.1", "peter5001");

    register_forward(FM_PlayerPreThink, "OnPlayerPreThink");

    //RegisterHam(Ham_TraceAttack, "player", "OnTraceAttack");
    RegisterHam(Ham_TakeDamage, "player", "OnTakeDamage_Post", 1);

    OrpheuRegisterHook(OrpheuGetFunction("PM_Move"), "OnPM_Move");
    OrpheuRegisterHook(OrpheuGetFunction("PM_ReduceTimers"), "OnPM_ReduceTimers");
}

public plugin_natives()
{
	register_library("painshock");

	register_native("painshock_set", "native_set");
	register_native("painshock_get", "native_get");
}

public client_disconnected(id)
{
    g_PainShock[id] = 1.0;
    g_PainShockTime[id] = 0.0;
    g_PainShockCheckTime[id] = 0.0;
}

public OnPlayerPreThink(id)
{
	if (is_user_alive(id))
	{
		new Float:currentTime = get_gametime();
		
		if (g_PainShock[id] < 0.0)
			g_PainShock[id] = 0.0;

		if (g_PainShock[id] < 1.0)
			g_PainShock[id] += ((currentTime - g_PainShockCheckTime[id]) / MAX_PAINSHOCK_TIME);

		if (g_PainShock[id] > 1.0)
			g_PainShock[id] = 1.0

		g_PainShockCheckTime[id] = currentTime;
	}
}

public OnTakeDamage_Post(id, inflictor, attacker, Float:damage, damagebits)
{
    if (pev_valid(id))
    {
		g_PainShock[id] = get_ent_data_float(id, "CBasePlayer", "m_flVelocityModifier") * 0.75;
		g_PainShockTime[id] = get_gametime();

        set_ent_data_float(id, "CBasePlayer", "m_flVelocityModifier", 1.0);
    }
}

public OnPM_Move(OrpheuStruct:ppmove, server)
{
	g_ppmove = ppmove;
}

public OnPM_ReduceTimers()
{
	new id = OrpheuGetStructMember(g_ppmove, "player_index") + 1;
	
	if (is_user_alive(id) && g_PainShock[id] < 1.0)
	{
		new Float:maxspeed = Float:OrpheuGetStructMember(g_ppmove, "maxspeed");
		OrpheuSetStructMember(g_ppmove, "maxspeed", maxspeed * g_PainShock[id]);
	}
}

public Float:native_get()
{
	new id = get_param(1);
	if (!IS_VALID_PLAYER(id))
		return 0.0;
	
	return g_PainShock[id];
}

public native_set()
{
	new id = get_param(1);
	if (!IS_VALID_PLAYER(id))
		return;
	
	new Float:value = get_param_f(2);
	new bypass = get_param(3);

	if (!bypass && value >= g_PainShock[id])
		return;
	
	g_PainShock[id] = floatclamp(value, 0.0, 1.0);
	g_PainShockTime[id] = get_gametime();
}