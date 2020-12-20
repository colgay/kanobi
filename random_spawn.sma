#include <amxmodx>
#include <amxmisc>
#include <engine>
#include <fakemeta>
#include <hamsandwich>

#define VERSION "0.1"

enum _:SpawnPoint
{
	Float:sp_origin[3],
	Float:sp_angles[3],
	Float:sp_v_angle[3],
};

new Array:g_SpawnPoints;
new g_SpawnPointCount;

public plugin_precache()
{
	g_SpawnPoints = ArrayCreate(SpawnPoint);
}

public plugin_init()
{
	register_plugin("Random Spawn", VERSION, "holla");

	RegisterHam(Ham_Spawn, "player", "OnPlayerSpawn_Post", 1);

	LoadSpawns();
}

public OnPlayerSpawn_Post(id)
{
	if (is_user_alive(id))
	{
		DoRandomSpawn(id);
	}
}

stock LoadSpawns()
{
	new cfgdir[32], mapname[32], filepath[100], buffer[64];
	get_configsdir(cfgdir, charsmax(cfgdir));
	get_mapname(mapname, charsmax(mapname));
	formatex(filepath, charsmax(filepath), "%s/csdm/%s.spawns.cfg", cfgdir, mapname);

	if (file_exists(filepath))
	{
		new i;
		new str[10][6], file = fopen(filepath,"rt");
		new data[SpawnPoint];
		
		while (file && !feof(file))
		{
			fgets(file, buffer, charsmax(buffer))
			
			// invalid spawn
			if(!buffer[0] || str_count(buffer,' ') < 2) continue;
			
			// get spawn point data
			parse(buffer,str[0],5,str[1],5,str[2],5,str[3],5,str[4],5,str[5],5,str[6],5,str[7],5,str[8],5,str[9],5);
			
			for (i = 0; i < 3; i++)
			{
				data[sp_origin][i] = str_to_float(str[i]);
				data[sp_angles][i] = str_to_float(str[i+3]);
				data[sp_v_angle][i] = str_to_float(str[i+6]);
			}
			
			ArrayPushArray(g_SpawnPoints, data);

			// increase spawn count
			g_SpawnPointCount++;
		}
		if (file) fclose(file);
	}
	else
	{
		// Collect regular spawns
		CollectSpawnsEnt("info_player_start");
		CollectSpawnsEnt("info_player_deathmatch");
	}
}

stock DoRandomSpawn(id)
{
	new spawn_index, current_index;
	new hull = (pev(id, pev_flags) & FL_DUCKING) ? HULL_HEAD : HULL_HUMAN;

	if (g_SpawnPointCount)
	{
		new data[SpawnPoint];
		spawn_index = random(g_SpawnPointCount);

		// Try to find a clear spawn
		for (current_index = spawn_index + 1; /*no condition*/; current_index++)
		{
			// Start over when we reach the end
			if (current_index >= g_SpawnPointCount) current_index = 0
			
			ArrayGetArray(g_SpawnPoints, current_index, data);

			// Free spawn space?
			if (IsHullVacant(data[sp_origin], hull))
			{
				// Engfunc_SetOrigin is used so ent's mins and maxs get updated instantly
				engfunc(EngFunc_SetOrigin, id, data[sp_origin]);

				set_pev(id, pev_angles, data[sp_angles]);
				set_pev(id, pev_v_angle, data[sp_v_angle]);

				break;
			}
			
			// Loop completed, no free space found
			if (current_index == spawn_index) break;
		}
	}
}

stock CollectSpawnsEnt(const classname[])
{
	new data[SpawnPoint];
	new Float:vector[3];

	new ent = -1;
	while ((ent = find_ent_by_class(ent, classname)) != 0)
	{
		// get origin
		pev(ent, pev_origin, vector)
		data[sp_origin][0] = vector[0];
		data[sp_origin][1] = vector[1];
		data[sp_origin][2] = vector[2];
		
		// angles
		pev(ent, pev_angles, vector)
		data[sp_angles][0] = vector[0];
		data[sp_angles][1] = vector[1];
		data[sp_angles][2] = vector[2];
		
		// view angles
		pev(ent, pev_v_angle, vector)
		data[sp_v_angle][0] = vector[0];
		data[sp_v_angle][1] = vector[1];
		data[sp_v_angle][2] = vector[2];
		
		ArrayPushArray(g_SpawnPoints, data);

		// increase spawn count
		g_SpawnPointCount++;
	}
}

// Checks if a space is vacant (credits to VEN)
stock IsHullVacant(Float:origin[], hull)
{
	engfunc(EngFunc_TraceHull, origin, origin, 0, hull, 0, 0)
	
	if (!get_tr2(0, TR_StartSolid) && !get_tr2(0, TR_AllSolid) && get_tr2(0, TR_InOpen))
		return true;
	
	return false;
}

// Stock by (probably) Twilight Suzuka -counts number of chars in a string
stock str_count(const str[], searchchar)
{
	new count, i, len = strlen(str)
	
	for (i = 0; i <= len; i++)
	{
		if(str[i] == searchchar)
			count++
	}
	
	return count;
}