/************************
	Original author: FrozDark
	Edited by: ire.
************************/

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>
#include <zombiereloaded>
#include <zr_lasermines>
#include <multicolors>

#pragma tabsize 0
#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION "1.4.3"

#define MDL_LASER "sprites/laser.vmt"
#define MDL_MINE "models/props_lab/tpplug.mdl"

#define SND_PUTMINE "npc/roller/blade_cut.wav"
#define SND_MINEACTIVATED "npc/roller/mine/rmine_blades_in2.wav"
#define SND_PICKUPMINE "items/itempickup.wav"

ConVar g_cvSpawnMineAmount;
ConVar g_cvMaxMineAmount;
ConVar g_cvMineDamage;
ConVar g_cvMineExplodeDamage;
ConVar g_cvMineExplodeRadius;
ConVar g_cvMineActivationTime;
ConVar g_cvAllowPickup;

int g_iAmount;
int g_iMaxAmount;
int g_iDamage;
int g_iExplodeDamage;
int g_iExplodeRadius;
int g_iClientsAmount[MAXPLAYERS+1];
int g_iClientsMyAmount[MAXPLAYERS+1];
int g_iClientsMaxLimit[MAXPLAYERS+1];
int g_iUsedByNative[MAXPLAYERS+1];

float fActivationTime;

bool g_bAllowPickup;
bool g_bLate;

public Plugin myinfo = 
{
	name = "[ZR] Lasermines",
	author = "FrozDark (HLModders.ru LLC), ire.",
	description = "Plants a laser mine",
	version = PLUGIN_VERSION,
	url = "http://www.hlmod.ru/"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	CreateNative("ZR_AddClientLasermines", Native_AddMines);
	CreateNative("ZR_SetClientLasermines", Native_SetMines);
	CreateNative("ZR_SubClientLasermines", Native_SubstractMines);
	CreateNative("ZR_GetClientLasermines", Native_GetMines);
	CreateNative("ZR_ClearMapClientLasermines", Native_ClearMapMines);
	CreateNative("ZR_IsEntityLasermine", Native_IsLasermine);
	CreateNative("ZR_GetClientByLasermine", Native_GetClientByLasermine);
	CreateNative("ZR_ResetClientMaxMines", Native_ResetClientMaxLasermines);
	CreateNative("ZR_SetClientMaxLasermines", Native_SetClientMaxLasermines);
	CreateNative("ZR_GetBeamByLasermine", Native_GetBeamByLasermine);
	CreateNative("ZR_GetLasermineByBeam", Native_GetLasermineByBeam);

	RegPluginLibrary("zr_lasermines");

	g_bLate = late;

	return APLRes_Success;
}

public void OnPluginStart()
{	
	g_cvSpawnMineAmount = CreateConVar("zr_lasermines_amount", "2", "The amount to give laser mines to a player each spawn (-1 = Infinity)", _, true, -1.0);
	g_cvMaxMineAmount = CreateConVar("zr_lasermines_maxamount", "2", "The maximum amount of laser mines a player can carry. (0-Unlimited)", _, true, 0.0);
	g_cvMineDamage = CreateConVar("zr_lasermines_damage", "1", "The damage to deal to a player by the laser", _, true, 1.0, true, 100000.0);
	g_cvMineExplodeDamage = CreateConVar("zr_lasermines_explode_damage", "100", "The damage to deal to a player when a laser mine breaks", _, true, 0.0, true, 100000.0);
	g_cvMineExplodeRadius = CreateConVar("zr_lasermines_explode_radius", "300", "The radius of the explosion", _, true, 1.0, true, 100000.0);
	g_cvMineActivationTime = CreateConVar("zr_lasermines_activatetime", "2", "The delay of laser mines' activation", _, true, 0.0, true, 10.0);
	g_cvAllowPickup = CreateConVar("zr_lasermines_allow_pickup", "1", "Allow players to pickup their planted lasermines");

	HookConVarChange(g_cvSpawnMineAmount, OnConVarChanged);
	HookConVarChange(g_cvMaxMineAmount, OnConVarChanged);
	HookConVarChange(g_cvMineDamage, OnConVarChanged);
	HookConVarChange(g_cvMineExplodeDamage, OnConVarChanged);
	HookConVarChange(g_cvMineExplodeRadius, OnConVarChanged);
	HookConVarChange(g_cvMineActivationTime, OnConVarChanged);
	HookConVarChange(g_cvAllowPickup, OnConVarChanged);

	HookEvent("player_spawn", OnPlayerSpawn);
	HookEvent("player_death", OnPlayerDeath);
	HookEvent("player_death", OnPlayerDeath_Pre, EventHookMode_Pre);
	HookEvent("player_team", OnPlayerTeam);

	RegConsoleCmd("sm_laser", Command_PlantMine, "Plant a laser mine");
	RegConsoleCmd("sm_plant", Command_PlantMine, "Plant a laser mine");
	RegConsoleCmd("sm_lm", Command_PlantMine, "Plant a laser mine");

	HookEntityOutput("env_beam", "OnTouchedByEntity", OnTouchedByEntity);

	LoadTranslations("zr_lasermines.phrases");

	AutoExecConfig(true);

	if(g_bLate)
	{
		g_bLate = false;
		OnMapStart();
	}
}

public void OnMapStart()
{
	PrecacheModel(MDL_MINE, true);
	PrecacheModel(MDL_LASER, true);

	PrecacheSound(SND_PUTMINE, true);
	PrecacheSound(SND_MINEACTIVATED, true);
	PrecacheSound(SND_PICKUPMINE, true);

	OnConfigsExecuted();
}

public void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	OnConfigsExecuted();
}

public void OnConfigsExecuted()
{
	g_iAmount = g_cvSpawnMineAmount.IntValue;
	g_iMaxAmount = g_cvMaxMineAmount.IntValue;
	g_iDamage = g_cvMineDamage.IntValue;
	g_iExplodeDamage = g_cvMineExplodeDamage.IntValue;
	g_iExplodeRadius = g_cvMineExplodeRadius.IntValue;
	fActivationTime = g_cvMineActivationTime.FloatValue;
	g_bAllowPickup = g_cvAllowPickup.BoolValue;
}

public void OnPlayerTeam(Event event, const char[] name, bool dontBroadcast)
{
	if(GetEventInt(event, "team") < 2)
	{
		OnClientDisconnect(GetClientOfUserId(GetEventInt(event, "userid")));
	}
}

public void OnClientConnected(int client)
{
	if(!g_iUsedByNative[client])
	{
		g_iClientsMaxLimit[client] = g_iMaxAmount;
		g_iClientsMyAmount[client] = g_iAmount;
	}
}

public void OnClientDisconnect(int client)
{
	int iMaxEdicts = GetMaxEntities();
	for(int i = MaxClients+1; i <= iMaxEdicts; i++)
	{
		if(ZR_GetClientByLasermine(i) == client)
		{
			SDKUnhook(i, SDKHook_OnTakeDamage, OnTakeDamage);
			AcceptEntityInput(i, "KillHierarchy");
		}
	}

	g_iClientsAmount[client] = 0;
	g_iUsedByNative[client] = false;
}

public void OnTouchedByEntity(const char[] output, int caller, int activator, float delay)
{
	if (!(1 <= activator <= MaxClients))
	{
		return;
	}

	int g_iOwner = GetEntPropEnt(caller, Prop_Data, "m_hOwnerEntity");
	int g_iLasermine = ZR_GetLasermineByBeam(caller);

	if (g_iOwner == -1 || g_iLasermine == -1  || activator == g_iOwner || ZR_IsClientHuman(activator))
	{
		return;
	}

	int g_iDummyDamage;
	int g_iDummyCaller;
	int g_iDummyOwner;

	g_iDummyDamage = g_iDamage;
	g_iDummyCaller = caller;
	g_iDummyOwner = g_iOwner;

	float fVelocity[3];
	GetEntPropVector(activator, Prop_Data, "m_vecVelocity", fVelocity);
	
	SDKHooks_TakeDamage(activator, g_iDummyCaller, g_iDummyOwner, float(g_iDummyDamage), DMG_ENERGYBEAM);
	
	TeleportEntity(activator, NULL_VECTOR, NULL_VECTOR, fVelocity);
}

public void OnPlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	g_iClientsAmount[client] = g_iClientsMyAmount[client];
}

public void OnPlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	OnClientDisconnect(client);
}

public Action OnPlayerDeath_Pre(Event event, const char[] name, bool dontBroadcast)
{
	int attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	if (1 <= attacker <= MaxClients)
	{
		char Weapon[32];
		GetEventString(event, "weapon", Weapon, sizeof(Weapon));
		if(StrEqual(Weapon, "env_beam"))
		{
			SetEventString(event, "weapon", "shieldgun");
		}
	}
	return Plugin_Continue;
}

public void ZR_OnClientInfected(int client, int attacker, bool motherInfect, bool respawnOverride, bool respawn)
{
	OnClientDisconnect(client);
}

public Action Command_PlantMine(int client, int argc)
{
	if(!IsValidClient(client))
	{
		CPrintToChat(client, "%t", "Usage");
		return Plugin_Handled;
	}

	if(!AccessToLasermines(client))
	{
		CPrintToChat(client, "%t", "NoAccess");
		return Plugin_Handled;
	}

	if(!g_iClientsAmount[client])
	{
		PrintHintText(client, "%t", "MineAmount", g_iClientsAmount[client]);
		return Plugin_Handled;
	}

	float fDelayTime;
	int g_iDummyDamage;
	int g_iDummyRadius;
	int g_iDummyColor[3];

	fDelayTime = fActivationTime;
	g_iDummyDamage = g_iExplodeDamage;
	g_iDummyRadius = g_iExplodeRadius;
	g_iDummyColor = {0, 0, 255};

	if((PlantMine(client, fDelayTime, g_iDummyDamage, g_iDummyRadius, g_iDummyColor)) == -1)
	{
		return Plugin_Handled;
	}

	switch(g_iClientsAmount[client])
	{
		case -1:
		{
			PrintHintText(client, "%t", "InfiniteMines");
		}
		default:
		{
			g_iClientsAmount[client]--;
			PrintHintText(client, "%t", "MineAmount", g_iClientsAmount[client]);
		}
	}

	return Plugin_Handled;
}

public Action OnPlayerRunCmd(int client, int& buttons, int& impulse, float vel[3], float angles[3], int& weapon, int& subtype, int& cmdnum, int& tickcount, int& seed, int mouse[2])
{
	static int g_iPrevButtons[MAXPLAYERS+1];

	if(!g_bAllowPickup || IsFakeClient(client) || !IsPlayerAlive(client) || ZR_IsClientZombie(client))
		return Plugin_Continue;
	
	if((buttons & IN_USE) && !(g_iPrevButtons[client] & IN_USE))
	{
		OnButtonPressed(client);
	}

	g_iPrevButtons[client] = buttons;

	return Plugin_Continue;
}

void OnButtonPressed(int client)
{
	Handle g_hTrace = TraceRay(client);

	int g_iEnt = -1;

	if(TR_DidHit(g_hTrace) && (g_iEnt = TR_GetEntityIndex(g_hTrace)) > MaxClients)
	{	
		CloseHandle(g_hTrace);

		int g_iOwner = ZR_GetClientByLasermine(g_iEnt);

		if(g_iOwner == -1)
		{
			return;
		}
		if(g_iOwner == client)
		{
			PickupLasermine(client, g_iEnt);
			return;
		}
	}

	else
	{
		CloseHandle(g_hTrace);
	}
}

Handle TraceRay(int client)
{
	float fStart[3];
	float fAngle[3];
	float fEnd[3];

	GetClientEyePosition(client, fStart);
	GetClientEyeAngles(client, fAngle);
	GetAngleVectors(fAngle, fEnd, NULL_VECTOR, NULL_VECTOR);
	NormalizeVector(fEnd, fEnd);

	fStart[0] = fStart[0] + fEnd[0] * 10.0;
	fStart[1] = fStart[1] + fEnd[1] * 10.0;
	fStart[2] = fStart[2] + fEnd[2] * 10.0;

	fEnd[0] = fStart[0] + fEnd[0] * 80.0;
	fEnd[1] = fStart[1] + fEnd[1] * 80.0;
	fEnd[2] = fStart[2] + fEnd[2] * 80.0;

	return TR_TraceRayFilterEx(fStart, fEnd, CONTENTS_SOLID, RayType_EndPoint, FilterPlayers);
}

public bool FilterPlayers(int entity, int contentsMask)
{
	return !(1 <= entity <= MaxClients);
}

void PickupLasermine(int client, int lasermine)
{
	if(g_iClientsAmount[client] >= 0 && g_iClientsAmount[client] == ZR_AddClientLasermines(client))
	{
		return;
	}

	AcceptEntityInput(lasermine, "KillHierarchy");

	if (g_iClientsAmount[client] >= 0)
	{
		PrintHintText(client, "%t", "MineAmount", g_iClientsAmount[client]);
	}

	else
	{
		PrintHintText(client, "%t", "Infinity mines");
	}

	EmitSoundToClient(client, SND_PICKUPMINE);
}

int PlantMine(int client, float activation_delay = 0.0, int explode_damage, int explode_radius, const int color[3] = {255, 255, 255})
{
	if(activation_delay > 10.0)
	{
		activation_delay = 10.0;
	}

	else if(activation_delay < 0.0)
	{
		activation_delay = 0.0;
	}

	Handle g_hTrace = TraceRay(client);

	float fEnd[3];
	float fNormal[3];
	float fBeamEnd[3];
	
	if(TR_DidHit(g_hTrace) && TR_GetEntityIndex(g_hTrace) < 1)
	{
		TR_GetEndPosition(fEnd, g_hTrace);
		TR_GetPlaneNormal(g_hTrace, fNormal);

		CloseHandle(g_hTrace);

		GetVectorAngles(fNormal, fNormal);

		TR_TraceRayFilter(fEnd, fNormal, CONTENTS_SOLID, RayType_Infinite, FilterAll);
		TR_GetEndPosition(fBeamEnd, INVALID_HANDLE);

		int g_iMineEnt = CreateEntityByName("prop_physics_override");
		if(g_iMineEnt == -1 || !IsValidEdict(g_iMineEnt))
		{
			LogError("Could not create entity \"prop_physics_override\"");
			return -1;
		}

		int g_iBeamEnt = CreateEntityByName("env_beam");
		if(g_iBeamEnt == -1 || !IsValidEdict(g_iBeamEnt))
		{
			LogError("Could not create entity \"env_beam\"");
			return -1;
		}

		char Start[32], Temp[256], Buffer[16];

		Format(Start, sizeof(Start), "Beam%i", g_iBeamEnt);

		SetEntityModel(g_iMineEnt, MDL_MINE);

		IntToString(explode_damage, Buffer, sizeof(Buffer));
		DispatchKeyValue(g_iMineEnt, "ExplodeDamage", Buffer);
		IntToString(explode_radius, Buffer, sizeof(Buffer));
		DispatchKeyValue(g_iMineEnt, "ExplodeRadius", Buffer);

		DispatchKeyValue(g_iMineEnt, "spawnflags", "3");
		DispatchSpawn(g_iMineEnt);

		AcceptEntityInput(g_iMineEnt, "DisableMotion");
		SetEntityMoveType(g_iMineEnt, MOVETYPE_NONE);
		TeleportEntity(g_iMineEnt, fEnd, fNormal, NULL_VECTOR);

		/*
		PrintToChat(client, "%f %f %f", fNormal[0], fNormal[1], fNormal[2]);

		if(fNormal[0] >= 270.0 || (fNormal[0] != 0.0 && fNormal[0] < 270.0))
		{
			PrintHintText(client, "%t", "InvalidLocation");
			RemoveEntity(g_iMineEnt);
			return -1;
		}
		*/

		float fTarget[3], fOrigin[3];
		int g_iTemp = -1;
		char PropModel[128];

		while((g_iTemp = FindEntityByClassname(g_iTemp, "prop_physi*")) != -1)
		{
			if(IsValidEntity(g_iTemp))
			{
				if(g_iTemp != g_iMineEnt)
				{
					GetEntPropString(g_iTemp, Prop_Data, "m_ModelName", PropModel, sizeof(PropModel));
					if(StrEqual(PropModel, "models/props/cs_militia/dryer.mdl"))
					{
						GetEntPropVector(g_iTemp, Prop_Data, "m_vecOrigin", fTarget);
						GetEntPropVector(g_iMineEnt, Prop_Data, "m_vecOrigin", fOrigin);
						if(GetVectorDistance(fTarget, fOrigin) <= 35.0)
						{
							RemoveEntity(g_iMineEnt);
							return -1;
						}
					}
				}
			}
		}

		SetEntProp(g_iMineEnt, Prop_Data, "m_nSolidType", 6);
		SetEntProp(g_iMineEnt, Prop_Data, "m_CollisionGroup", 11);

		Format(Temp, sizeof(Temp), "%s,Kill,,0,-1", Start);
		DispatchKeyValue(g_iMineEnt, "OnBreak", Temp);

		EmitSoundToAll(SND_PUTMINE, g_iMineEnt);

		DispatchKeyValue(g_iBeamEnt, "targetname", Start);
		DispatchKeyValue(g_iBeamEnt, "damage", "0");
		DispatchKeyValue(g_iBeamEnt, "framestart", "0");
		DispatchKeyValue(g_iBeamEnt, "BoltWidth", "4.0");
		DispatchKeyValue(g_iBeamEnt, "renderfx", "0");
		DispatchKeyValue(g_iBeamEnt, "TouchType", "3"); // 0 = none, 1 = player only, 2 = NPC only, 3 = player or NPC, 4 = player, NPC or physprop
		DispatchKeyValue(g_iBeamEnt, "framerate", "0");
		DispatchKeyValue(g_iBeamEnt, "decalname", "Bigshot");
		DispatchKeyValue(g_iBeamEnt, "TextureScroll", "35");
		DispatchKeyValue(g_iBeamEnt, "HDRColorScale", "1.0");
		DispatchKeyValue(g_iBeamEnt, "texture", MDL_LASER);
		DispatchKeyValue(g_iBeamEnt, "life", "0"); // 0 = infinite, beam life time in seconds
		DispatchKeyValue(g_iBeamEnt, "StrikeTime", "1"); // If beam life time not infinite, this repeat it back
		DispatchKeyValue(g_iBeamEnt, "LightningStart", Start);
		DispatchKeyValue(g_iBeamEnt, "spawnflags", "0"); // 0 disable, 1 = start on, etc etc. look from hammer editor
		DispatchKeyValue(g_iBeamEnt, "NoiseAmplitude", "0"); // straight beam = 0, other make noise beam
		DispatchKeyValue(g_iBeamEnt, "Radius", "256");
		DispatchKeyValue(g_iBeamEnt, "renderamt", "100");
		DispatchKeyValue(g_iBeamEnt, "rendercolor", "0 0 0");

		AcceptEntityInput(g_iBeamEnt, "TurnOff");

		SetEntityModel(g_iBeamEnt, MDL_LASER);

		TeleportEntity(g_iBeamEnt, fBeamEnd, NULL_VECTOR, NULL_VECTOR); // Teleport the beam

		SetEntPropVector(g_iBeamEnt, Prop_Data, "m_vecEndPos", fEnd);
		SetEntPropFloat(g_iBeamEnt, Prop_Data, "m_fWidth", 3.0);
		SetEntPropFloat(g_iBeamEnt, Prop_Data, "m_fEndWidth", 3.0);

		SetEntPropEnt(g_iBeamEnt, Prop_Data, "m_hOwnerEntity", client); // Sets the owner of the beam
		SetEntPropEnt(g_iMineEnt, Prop_Data, "m_hMoveChild", g_iBeamEnt);
		SetEntPropEnt(g_iBeamEnt, Prop_Data, "m_hEffectEntity", g_iMineEnt);

		Handle g_hDatapack = CreateDataPack();
		WritePackCell(g_hDatapack, g_iBeamEnt);
		WritePackCell(g_hDatapack, g_iMineEnt);
		WritePackCell(g_hDatapack, color[0]);
		WritePackCell(g_hDatapack, color[1]);
		WritePackCell(g_hDatapack, color[2]);
		WritePackString(g_hDatapack, Start);
		CreateTimer(activation_delay, OnActivateLaser, g_hDatapack, TIMER_FLAG_NO_MAPCHANGE|TIMER_HNDL_CLOSE);

		SetEntPropEnt(g_iMineEnt, Prop_Send, "m_PredictableID", client);

		SDKHook(g_iMineEnt, SDKHook_OnTakeDamage, OnTakeDamage);

		return g_iMineEnt;
	}
	
	else
	{
		CloseHandle(g_hTrace);
	}

	return -1;
}

public bool FilterAll(int entity, int contentsMask)
{
	return false;
}

public Action OnTakeDamage(int victim, int& attacker, int& inflictor, float& damage, int& damagetype)
{
	if(ZR_IsEntityLasermine(victim))
	{
		if(1 <= attacker <= MaxClients)
		{
			int client = ZR_GetClientByLasermine(victim);
			
			if((client != -1) && (client != attacker) && ZR_IsClientHuman(attacker))
			{
				return Plugin_Handled;
			}

			return Plugin_Continue;
		}

		else if (!ZR_IsEntityLasermine(inflictor))
		{
			return Plugin_Handled;
		}
	}

	return Plugin_Continue;
}

public Action OnActivateLaser(Handle Timer, any hDataPack)
{
	ResetPack(hDataPack);

	char Start[32], Temp[256];
	int g_iColor[3];

	int g_iBeamEnt = ReadPackCell(hDataPack);
	int g_iEnt = ReadPackCell(hDataPack);
	g_iColor[0] = ReadPackCell(hDataPack);
	g_iColor[1] = ReadPackCell(hDataPack);
	g_iColor[2] = ReadPackCell(hDataPack);
	ReadPackString(hDataPack, Start, sizeof(Start));

	if (!IsValidEdict(g_iBeamEnt) || !IsValidEdict(g_iEnt))
	{
		return Plugin_Stop;
	}

	AcceptEntityInput(g_iBeamEnt, "TurnOn");

	SetEntityRenderColor(g_iBeamEnt, g_iColor[0], g_iColor[1], g_iColor[2]);

	Format(Temp, sizeof(Temp), "%s,TurnOff,,0.001,-1", Start);
	DispatchKeyValue(g_iBeamEnt, "OnTouchedByEntity", Temp);
	Format(Temp, sizeof(Temp), "%s,TurnOn,,0.002,-1", Start);
	DispatchKeyValue(g_iBeamEnt, "OnTouchedByEntity", Temp);

	EmitSoundToAll(SND_MINEACTIVATED, g_iEnt);

	return Plugin_Stop;
}

public any Native_AddMines(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	
	if (client < 1 || client > MaxClients)
	{
		ThrowNativeError(SP_ERROR_INDEX, "Client index %i is invalid", client);
		return 0;
	}

	else if(!IsClientInGame(client))
	{
		ThrowNativeError(SP_ERROR_NOT_FOUND, "Client %i is not in game", client);
		return 0;
	}

	int g_iNativeAmount = GetNativeCell(2);
	bool g_bLimit = GetNativeCell(3);

	if(g_iNativeAmount <= 0)
	{
		return g_iClientsAmount[client];
	}

	if(g_iClientsAmount[client] < 0)
	{
		return -1;
	}

	g_iClientsAmount[client] += g_iNativeAmount;

	if(g_bLimit)
	{
		if(g_iClientsAmount[client] > g_iClientsMaxLimit[client])
		{
			g_iClientsAmount[client] = g_iClientsMaxLimit[client];
		}
	}

	return g_iClientsAmount[client];
}

public any Native_SetMines(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);

	if(client < 1 || client > MaxClients)
	{
		ThrowNativeError(SP_ERROR_INDEX, "Client index %i is invalid", client);
		return false;
	}

	else if(!IsClientInGame(client))
	{
		ThrowNativeError(SP_ERROR_NOT_FOUND, "Client %i is not in game", client);
		return false;
	}

	int g_iNativeAmount = GetNativeCell(2);
	bool g_bLimit = GetNativeCell(3);
	
	if (g_iNativeAmount < -1)
	{
		g_iNativeAmount = -1;
	}

	g_iClientsAmount[client] = g_iNativeAmount;

	if(g_bLimit)
	{
		if(g_iClientsAmount[client] > g_iClientsMaxLimit[client])
		{
			g_iClientsAmount[client] = g_iClientsMaxLimit[client];
		}
	}

	return true;
}

public any Native_SubstractMines(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);

	if(client < 1 || client > MaxClients)
	{
		ThrowNativeError(SP_ERROR_INDEX, "Client index %i is invalid", client);
		return 0;
	}

	else if(!IsClientInGame(client))
	{
		ThrowNativeError(SP_ERROR_NOT_FOUND, "Client %i is not in game", client);
		return 0;
	}

	int g_iNativeAmount = GetNativeCell(2);
	
	if(g_iClientsAmount[client] == -1)
	{
		return g_iClientsAmount[client];
	}

	if(g_iNativeAmount <= 0)
	{
		return g_iClientsAmount[client];
	}

	g_iClientsAmount[client] -= g_iNativeAmount;
	
	if(g_iClientsAmount[client] < 0)
	{
		g_iClientsAmount[client] = 0;
	}

	return g_iClientsAmount[client];
}

public any Native_GetMines(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);

	if(client < 1 || client > MaxClients)
	{
		ThrowNativeError(SP_ERROR_INDEX, "Client index %i is invalid", client);
		return 0;
	}

	else if(!IsClientInGame(client))
	{
		ThrowNativeError(SP_ERROR_NOT_FOUND, "Client %i is not in game", client);
		return 0;
	}

	return g_iClientsAmount[client];
}

public any Native_ClearMapMines(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);

	if(client < 1 || client > MaxClients)
	{
		ThrowNativeError(SP_ERROR_INDEX, "Client index %i is invalid", client);
		return 0;
	}

	else if(!IsClientInGame(client))
	{
		ThrowNativeError(SP_ERROR_NOT_FOUND, "Client %i is not in game", client);
		return 0;
	}

	OnClientDisconnect(client);

	return -1;
}

public any Native_IsLasermine(Handle plugin, int numParams)
{
	int g_iEnt = GetNativeCell(1);

	if(g_iEnt <= MaxClients || !IsValidEdict(g_iEnt))
	{
		return false;
	}

	char ModelName[PLATFORM_MAX_PATH];
	GetEntPropString(g_iEnt, Prop_Data, "m_ModelName", ModelName, sizeof(ModelName));

	return(StrEqual(ModelName, MDL_MINE, false) && GetEntPropEnt(g_iEnt, Prop_Data, "m_hMoveChild") != -1);
}

public any Native_GetClientByLasermine(Handle plugin, int numParams)
{
	int g_iEnt = GetNativeCell(1);
	int g_iBeamEnt;

	if ((g_iBeamEnt = ZR_GetBeamByLasermine(g_iEnt)) == -1)
	{
		return -1;
	}

	return GetEntPropEnt(g_iBeamEnt, Prop_Data, "m_hOwnerEntity");
}

public any Native_SetClientMaxLasermines(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);

	if(client < 1 || client > MaxClients)
	{
		ThrowNativeError(SP_ERROR_INDEX, "Client index %i is invalid", client);
		return 0;
	}

	else if(!IsClientAuthorized(client))
	{
		ThrowNativeError(SP_ERROR_NOT_FOUND, "Client %i is not authorized", client);
		return 0;
	}

	int g_iNativeAmount = GetNativeCell(2);

	if (g_iNativeAmount < -1)
	{
		g_iNativeAmount = -1;
	}

	g_iClientsMaxLimit[client] = g_iNativeAmount;
	g_iClientsMyAmount[client] = g_iNativeAmount;
	g_iUsedByNative[client] = true;

	return -1;
}

public any Native_ResetClientMaxLasermines(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);

	if(client < 1 || client > MaxClients)
	{
		ThrowNativeError(SP_ERROR_INDEX, "Client index %i is invalid", client);
	}

	else if(!IsClientConnected(client))
	{
		ThrowNativeError(SP_ERROR_NOT_FOUND, "Client %i is not connected", client);
	}

	OnClientConnected(client);

	return -1;
}

public any Native_GetBeamByLasermine(Handle plugin, int numParams)
{
	int g_iEnt = GetNativeCell(1);

	if(ZR_IsEntityLasermine(g_iEnt))
	{
		return GetEntPropEnt(g_iEnt, Prop_Data, "m_hMoveChild");
	}

	return -1;
}

public any Native_GetLasermineByBeam(Handle plugin, int numParams)
{
	int g_iMine = GetEntPropEnt(GetNativeCell(1), Prop_Data, "m_hEffectEntity");
	
	if (g_iMine != -1 && ZR_IsEntityLasermine(g_iMine))
	{
		return g_iMine;
	}

	return -1;
}

bool IsValidClient(int client)
{
	return(IsClientInGame(client) && IsPlayerAlive(client) && GetClientTeam(client) == CS_TEAM_CT);
}

bool AccessToLasermines(int client)
{
	return(CheckCommandAccess(client, "zr_lasermines_access", ADMFLAG_CUSTOM1, true) || CheckCommandAccess(client, "zr_lasermines_access", ADMFLAG_GENERIC, true));
}
