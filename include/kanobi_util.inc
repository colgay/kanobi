#if defined _kanobi_util_included
	#endinput
#endif
#define _kanobi_util_included

stock PrecacheSoundArray(const array[][], size)
{
	for (new i = 0; i < size; i++)
		precache_sound(array[i]);
}

stock PrecachePlayerModel(const model[])
{
	new buffer[128];
	formatex(buffer, charsmax(buffer), "models/player/%s/%s.mdl", model, model);
	precache_model(buffer);
}