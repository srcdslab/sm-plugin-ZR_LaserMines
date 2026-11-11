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
#include <clientprefs>

#undef REQUIRE_PLUGIN
#tryinclude <DynamicChannels>
#define REQUIRE_PLUGIN

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION "1.7.1"

#define MDL_LASER "sprites/laser.vmt"
#define MDL_MINE "models/props_lab/tpplug.mdl"

#define SND_PUTMINE "npc/roller/blade_cut.wav"
#define SND_MINEACTIVATED "npc/roller/mine/rmine_blades_in2.wav"
#define SND_PICKUPMINE "items/itempickup.wav"

#define MAX_EDICTS 2048

ConVar g_cvSpawnMineAmount;
ConVar g_cvMaxMineAmount;
ConVar g_cvMineDamage;
ConVar g_cvMineActivationTime;
ConVar g_cvAllowPickup;
ConVar g_cvNadePickup;
ConVar g_cvMineHP;
ConVar g_cvHUDChannel;

int g_iMineHP[2049];
int g_iAmountLeft[MAXPLAYERS+1];
int g_iClientsMyAmount[MAXPLAYERS+1];
int g_iClientsMaxLimit[MAXPLAYERS+1];
int g_iButtonMarkerCount[MAXPLAYERS + 1] = {0, ... };

bool g_bPlugin_DynamicChannels = false;
bool g_bUsedByNative[MAXPLAYERS+1] = { false, ... };
bool g_bShorcut[MAXPLAYERS + 1];
bool g_bLate;

Handle g_hHudMsg;
Cookie g_hShortcut;

// References of the mines each client planted: removing a client's mines (death, infection,
// disconnect) only checks these instead of every edict
ArrayList g_hClientMines[MAXPLAYERS+1];

public Plugin myinfo =
{
	name = "[ZR] Lasermines",
	author = "FrozDark (HLModders.ru LLC), ire., .Rushaway",
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
	LoadTranslations("zr_lasermines.phrases");

	g_cvSpawnMineAmount = CreateConVar("zr_lasermines_amount", "2", "The amount to give lasermines to a player each spawn (-1 = Unlimited)", _, true, -1.0);
	g_cvMaxMineAmount = CreateConVar("zr_lasermines_maxamount", "2", "The maximum amount of lasermines a player can carry. (0 = Unlimited)", _, true, 0.0);
	g_cvMineDamage = CreateConVar("zr_lasermines_damage", "1", "The damage to deal to a player by the laser", _, true, 1.0, true, 100000.0);
	g_cvMineActivationTime = CreateConVar("zr_lasermines_activatetime", "2", "The delay of lasermines' activation", _, true, 0.0, true, 10.0);
	g_cvAllowPickup = CreateConVar("zr_lasermines_allow_pickup", "1", "Allow players to pickup their planted lasermines [1 = yes 0 = no]");
	g_cvNadePickup = CreateConVar("zr_lasermines_nade_pickup", "1", "Allow players to pickup their planted lasermines with grenades [1 = yes 0 = no]");
	g_cvMineHP = CreateConVar("zr_lasermines_hp", "500", "The HP of lasermines");
	g_cvHUDChannel = CreateConVar("zr_lasermines_hud_channel", "5", "The channel for the hud if using DynamicChannels", _, true, 0.0, true, 5.0);

	HookEvent("player_spawn", OnPlayerSpawn);
	HookEvent("player_death", OnPlayerDeath);
	HookEvent("player_death", OnPlayerDeath_Pre, EventHookMode_Pre);
	HookEvent("player_team", OnPlayerTeam);

	RegConsoleCmd("sm_laser", Command_PlantMine, "Plant a laser mine");
	RegConsoleCmd("sm_plant", Command_PlantMine, "Plant a laser mine");
	RegConsoleCmd("sm_lm", Command_PlantMine, "Plant a laser mine");

	/* COOKIES */
	SetCookieMenuItem(LaserMinesCookieHandler, 0, "LaserMines Settings");
	g_hShortcut = new Cookie("zr_lasermines_shortcut", "LaserMines ShortCut", CookieAccess_Protected);

	HookEntityOutput("env_beam", "OnTouchedByEntity", OnTouchedByEntity);

	g_hHudMsg = CreateHudSynchronizer();

	AutoExecConfig(true);

	if (g_bLate)
	{
		OnMapStart();
		for (int i = 1; i <= MaxClients; i++)
		{
			if (!IsClientConnected(i) || IsFakeClient(i))
				continue;

			OnClientConnected(i);
		}

		// Pick up the mines planted before a reload, once
		int iMaxEdicts = GetMaxEntities();
		for (int i = MaxClients+1; i <= iMaxEdicts; i++)
		{
			int iOwner = ZR_GetClientByLasermine(i);
			if (iOwner >= 1 && iOwner <= MaxClients)
				TrackMine(iOwner, i);
		}
	}

	g_bLate = false;
}

public void OnAllPluginsLoaded()
{
	g_bPlugin_DynamicChannels = LibraryExists("DynamicChannels");
}

public void OnLibraryAdded(const char[] name)
{
	if (strcmp(name, "DynamicChannels", false) == 0)
		g_bPlugin_DynamicChannels = true;
}

public void OnLibraryRemoved(const char[] name)
{
	if (strcmp(name, "DynamicChannels", false) == 0)
		g_bPlugin_DynamicChannels = false;
}

public void OnMapStart()
{
	PrecacheModel(MDL_MINE, true);
	PrecacheModel(MDL_LASER, true);

	PrecacheSound(SND_PUTMINE, true);
	PrecacheSound(SND_MINEACTIVATED, true);
	PrecacheSound(SND_PICKUPMINE, true);
}

public void OnPlayerTeam(Event event, const char[] name, bool dontBroadcast)
{
	if (event.GetInt("team") != 1)
		return;

	OnClientDisconnect(GetClientOfUserId(event.GetInt("userid")));
}

public void OnClientConnected(int client)
{
	if (!g_bUsedByNative[client])
	{
		g_iClientsMaxLimit[client] = g_cvMaxMineAmount.IntValue;
		g_iClientsMyAmount[client] = g_cvSpawnMineAmount.IntValue;
	}

	if (AreClientCookiesCached(client))
		ReadClientCookies(client);
}

public void OnClientCookiesCached(int client)
{
	ReadClientCookies(client);
}

public void ReadClientCookies(int client)
{
	char buffer[32];
	g_hShortcut.Get(client, buffer, sizeof(buffer));
	g_bShorcut[client] = view_as<bool>(StringToInt(buffer)) || buffer[0] == '\0';
}

public void SetClientCookies(int client)
{
	if (!AreClientCookiesCached(client) || IsFakeClient(client))
		return;

	char sValue[8];
	FormatEx(sValue, sizeof(sValue), "%i", g_bShorcut[client]);
	g_hShortcut.Set(client, sValue);
}

public void OnClientDisconnect(int client)
{
	// player_death can come after the client left
	if (client < 1)
		return;

	// Runs on every death and infection too: only check the mines this client planted.
	// A mine still counts only if it is still a lasermine owned by the client.
	ArrayList hMines = g_hClientMines[client];
	if (hMines != null)
	{
		for (int i = 0; i < hMines.Length; i++)
		{
			int iMine = EntRefToEntIndex(hMines.Get(i));
			if (iMine != INVALID_ENT_REFERENCE && ZR_GetClientByLasermine(iMine) == client)
			{
				SDKUnhook(iMine, SDKHook_OnTakeDamage, OnTakeDamage);
				AcceptEntityInput(iMine, "KillHierarchy");
			}
		}

		hMines.Clear();
	}

	g_iAmountLeft[client] = 0;
	g_bUsedByNative[client] = false;
	SetClientCookies(client);
}

void TrackMine(int client, int mine)
{
	if (g_hClientMines[client] == null)
		g_hClientMines[client] = new ArrayList();

	// Drop the mines already gone (picked up, destroyed) so the list stays short
	ArrayList hMines = g_hClientMines[client];
	for (int i = hMines.Length - 1; i >= 0; i--)
	{
		if (EntRefToEntIndex(hMines.Get(i)) == INVALID_ENT_REFERENCE)
			hMines.Erase(i);
	}

	hMines.Push(EntIndexToEntRef(mine));
}

public void LaserMinesCookieHandler(int client, CookieMenuAction action, any info, char[] buffer, int maxlen)
{
	switch (action)
	{
		case CookieMenuAction_SelectOption:
			LaserMinesSetting(client);
	}
}

public void LaserMinesSetting(int client)
{
	Menu menu = new Menu(LaserMinesSettingHandler, MENU_ACTIONS_ALL);
	menu.SetTitle("%T %T", "Menu Prefix", client, "Client Setting", client);

	char shortcut[64];
	FormatEx(shortcut, 64, "%T", "Shortcut", client);
	menu.AddItem("shortcut", shortcut);

	menu.ExitBackButton = true;
	menu.ExitButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int LaserMinesSettingHandler(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_DisplayItem:
		{
			char info[64], display[64];
			menu.GetItem(param2, info, sizeof(info));
			if (strcmp(info, "shortcut", false) == 0)
			{
				FormatEx(display, sizeof(display), "%T : %T", "Shortcut", param1, g_bShorcut[param1] ? "Enabled" : "Disabled", param1);
				return RedrawMenuItem(display);
			}
		}
		case MenuAction_Select:
		{
			char info[64];
			menu.GetItem(param2, info, sizeof(info));
			if (strcmp(info, "shortcut", false) == 0)
			{
				char status[32];
				g_bShorcut[param1] = !g_bShorcut[param1];
				FormatEx(status, 64, "%T", g_bShorcut[param1] ? "Enabled" : "Disabled", param1);
				CPrintToChat(param1, "{green}[SM] {white}%T", "You set shortcut", param1, status);
			}

			LaserMinesSetting(param1);
		}
		case MenuAction_Cancel:
			ShowCookieMenu(param1);
		case MenuAction_End:
			delete menu;
	}
	return 0;
}

public void OnTouchedByEntity(const char[] output, int caller, int activator, float delay)
{
	if (activator < 1 || activator > MaxClients)
		return;

	if (ZR_IsClientHuman(activator))
		return;

	int iOwner = GetEntPropEnt(caller, Prop_Data, "m_hOwnerEntity");
	if (iOwner == -1 || activator == iOwner)
		return;

	float fDummyDamage = g_cvMineDamage.FloatValue;
	float fVelocity[3];

	GetEntPropVector(activator, Prop_Data, "m_vecVelocity", fVelocity);
	SDKHooks_TakeDamage(activator, caller, iOwner, fDummyDamage, DMG_ENERGYBEAM);
	TeleportEntity(activator, NULL_VECTOR, NULL_VECTOR, fVelocity);
}

public void OnPlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	g_iAmountLeft[client] = g_iClientsMyAmount[client];
}

public void OnPlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	OnClientDisconnect(client);
}

public Action OnPlayerDeath_Pre(Event event, const char[] name, bool dontBroadcast)
{
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	if (attacker <= 0 || attacker > MaxClients)
		return Plugin_Continue;

	char Weapon[32];
	event.GetString("weapon", Weapon, sizeof(Weapon));
	if (strcmp(Weapon, "env_beam", false) == 0)
		event.SetString("weapon", "shieldgun");

	return Plugin_Continue;
}

public void ZR_OnClientInfected(int client, int attacker, bool motherInfect, bool respawnOverride, bool respawn)
{
	OnClientDisconnect(client);
}

public bool AttemptPlantMine(int client)
{
	if (!IsValidClient(client))
	{
		CPrintToChat(client, "%t", "Usage");
		return false;
	}

	if (g_iAmountLeft[client] != -1 && g_iAmountLeft[client] <= 0)
	{
		PrintHintText(client, "%t", "MineAmount", g_iAmountLeft[client]);
		return false;
	}

	float fDelayTime = g_cvMineActivationTime.FloatValue;
	int iDummyColor[3] = {0, 0, 255};

	if (!PlantMine(client, fDelayTime, iDummyColor))
		return false;

	switch (g_iAmountLeft[client])
	{
		case -1:
		{
			PrintHintText(client, "%t", "InfiniteMines");
		}
		default:
		{
			g_iAmountLeft[client]--;
			PrintHintText(client, "%t", "MineAmount", g_iAmountLeft[client]);
		}
	}

	return true;
}

public Action Command_PlantMine(int client, int argc)
{
	AttemptPlantMine(client);
	return Plugin_Handled;
}

void PickupLasermine(int client, int lasermine)
{
	if (!IsValidClient(client) || g_iAmountLeft[client] >= 0 && g_iAmountLeft[client] == ZR_AddClientLasermines(client))
		return;

	AcceptEntityInput(lasermine, "KillHierarchy");

	if (g_iAmountLeft[client] >= 0)
		PrintHintText(client, "%t", "MineAmount", g_iAmountLeft[client]);
	else
		PrintHintText(client, "%t", "InfiniteMines");

	EmitSoundToClient(client, SND_PICKUPMINE);
}

bool PlantMine(int client, float activation_delay = 0.0, int color[3] = {255, 255, 255})
{
	if (!IsValidClient(client))
		return false;

	Handle hTrace = TraceRay(client);

	if (!TR_DidHit(hTrace) || TR_GetEntityIndex(hTrace) >= 1)
	{
		delete hTrace;
		return false;
	}

	// Check edict count before creating any entity
	int iCount = 0;
	for (int entity = 1; entity <= MAX_EDICTS; entity++)
	{
		if (IsValidEdict(entity))
			iCount++;
	}

	if (iCount >= MAX_EDICTS - 148)
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsValidClient(i))
				OnClientDisconnect(i);
		}
		LogError("Server was about to crash, all mines has been deleted. You should investigate this issue.");
		delete hTrace;
		return false;
	}

	// Retrieve surface data before closing the trace
	float fEnd[3], fNormal[3], fBeamEnd[3];
	TR_GetEndPosition(fEnd, hTrace);
	TR_GetPlaneNormal(hTrace, fNormal);
	delete hTrace;

	GetVectorAngles(fNormal, fNormal);
	TR_TraceRayFilter(fEnd, fNormal, CONTENTS_SOLID, RayType_Infinite, TraceRay_FilterAll);
	TR_GetEndPosition(fBeamEnd, null);

	// Create entities
	int iMineEnt = CreateEntityByName("prop_dynamic_override");
	int iBeamEnt = CreateEntityByName("env_beam");

	if (iMineEnt == -1 || !IsValidEdict(iMineEnt) || iBeamEnt == -1 || !IsValidEdict(iBeamEnt))
	{
		LogError("Failed to create %s", iMineEnt == -1 ? "prop_dynamic_override" : "env_beam");
		if (iMineEnt != -1 && IsValidEdict(iMineEnt))
			AcceptEntityInput(iMineEnt, "Kill");
		if (iBeamEnt != -1 && IsValidEdict(iBeamEnt))
			AcceptEntityInput(iBeamEnt, "Kill");
		return false;
	}

	char sStart[32], sTemp[256];
	FormatEx(sStart, sizeof(sStart), "Beam%i", iBeamEnt);

	// Setup mine entity
	SetEntityModel(iMineEnt, MDL_MINE);
	DispatchKeyValue(iMineEnt, "solid", "6");
	DispatchKeyValue(iMineEnt, "CollisionGroup", "1");
	SetEntProp(iMineEnt, Prop_Send, "m_usSolidFlags", 12);
	DispatchKeyValue(iMineEnt, "rendercolor", "0 0 255");
	DispatchSpawn(iMineEnt);
	TeleportEntity(iMineEnt, fEnd, fNormal, NULL_VECTOR);

	FormatEx(sTemp, sizeof(sTemp), "%s,Kill,,0,-1", sStart);
	DispatchKeyValue(iMineEnt, "OnBreak", sTemp);

	EmitSoundToAll(SND_PUTMINE, iMineEnt);

	// Setup beam entity
	DispatchKeyValue(iBeamEnt, "targetname", sStart);
	DispatchKeyValue(iBeamEnt, "damage", "0");
	DispatchKeyValue(iBeamEnt, "framestart", "0");
	DispatchKeyValue(iBeamEnt, "BoltWidth", "4.0");
	DispatchKeyValue(iBeamEnt, "renderfx", "0");
	DispatchKeyValue(iBeamEnt, "TouchType", "3"); // 0 = none, 1 = player only, 2 = NPC only, 3 = player or NPC, 4 = player, NPC or physprop
	DispatchKeyValue(iBeamEnt, "framerate", "0");
	DispatchKeyValue(iBeamEnt, "decalname", "Bigshot");
	DispatchKeyValue(iBeamEnt, "TextureScroll", "35");
	DispatchKeyValue(iBeamEnt, "HDRColorScale", "1.0");
	DispatchKeyValue(iBeamEnt, "texture", MDL_LASER);
	DispatchKeyValue(iBeamEnt, "life", "0"); // 0 = infinite, beam life time in seconds
	DispatchKeyValue(iBeamEnt, "StrikeTime", "1"); // If beam life time not infinite, this repeats it
	DispatchKeyValue(iBeamEnt, "LightningStart", sStart);
	DispatchKeyValue(iBeamEnt, "spawnflags", "0");
	DispatchKeyValue(iBeamEnt, "NoiseAmplitude", "0"); // 0 = straight beam
	DispatchKeyValue(iBeamEnt, "Radius", "256");
	DispatchKeyValue(iBeamEnt, "renderamt", "100");
	DispatchKeyValue(iBeamEnt, "rendercolor", "0 0 0");
	AcceptEntityInput(iBeamEnt, "TurnOff");

	SetEntityModel(iBeamEnt, MDL_LASER);
	TeleportEntity(iBeamEnt, fBeamEnd, NULL_VECTOR, NULL_VECTOR);

	SetEntPropVector(iBeamEnt, Prop_Data, "m_vecEndPos", fEnd);
	SetEntPropFloat(iBeamEnt, Prop_Data, "m_fWidth", 3.0);
	SetEntPropFloat(iBeamEnt, Prop_Data, "m_fEndWidth", 3.0);

	// Link entities together
	SetEntPropEnt(iBeamEnt, Prop_Data, "m_hOwnerEntity", client);
	SetEntPropEnt(iMineEnt, Prop_Data, "m_hMoveChild", iBeamEnt);
	SetEntPropEnt(iBeamEnt, Prop_Data, "m_hEffectEntity", iMineEnt);

	// Store owner and HP on mine
	SetEntPropEnt(iMineEnt, Prop_Send, "m_PredictableID", client);
	g_iMineHP[iMineEnt] = g_cvMineHP.IntValue;

	// Schedule activation
	if (activation_delay > 10.0)
		activation_delay = 10.0;
	else if (activation_delay < 0.0)
		activation_delay = 0.0;

	DataPack hDataPack = new DataPack();
	hDataPack.WriteCell(iBeamEnt);
	hDataPack.WriteCell(iMineEnt);
	hDataPack.WriteCell(color[0]);
	hDataPack.WriteCell(color[1]);
	hDataPack.WriteCell(color[2]);
	hDataPack.WriteString(sStart);
	CreateTimer(activation_delay, OnActivateLaser, hDataPack, TIMER_FLAG_NO_MAPCHANGE|TIMER_HNDL_CLOSE);

	// Show pickup HUD hint
	SetHudTextParams(-1.0, 0.7, 4.0, 255, 0, 0, 255);

	bool bDynamicAvailable = g_bPlugin_DynamicChannels && CanTestFeatures() && GetFeatureStatus(FeatureType_Native, "GetDynamicChannel") == FeatureStatus_Available;
	int iHUDChannel = -1;

#if defined _DynamicChannels_included_
	if (bDynamicAvailable)
	{
		int iChannel = g_cvHUDChannel.IntValue;
		if (iChannel < 0 || iChannel > 5)
			iChannel = 5;
		iHUDChannel = GetDynamicChannel(iChannel);
	}
#endif

	if (bDynamicAvailable)
		ShowHudText(client, iHUDChannel, "%t", "PickUpInfo");
	else
	{
		ClearSyncHud(client, g_hHudMsg);
		ShowSyncHudText(client, g_hHudMsg, "%t", "PickUpInfo");
	}

	SDKHook(iMineEnt, SDKHook_OnTakeDamage, OnTakeDamage);

	TrackMine(client, iMineEnt);

	return true;
}

public Action OnTakeDamage(int victim, int& attacker, int& inflictor, float& damage, int& damagetype)
{
	if (!IsValidEdict(victim))
		return Plugin_Continue;

	if (attacker <= 0 || attacker > MaxClients)
		return Plugin_Continue;

	int iOwner = GetEntPropEnt(victim, Prop_Send, "m_PredictableID");
	int iAttackerTeam = GetClientTeam(attacker);
	int iOwnerTeam = (iOwner > 0 && iOwner <= MaxClients) ? GetClientTeam(iOwner) : -1;

	if (attacker != iOwner && iOwner > 0 && iAttackerTeam == 3 && iOwnerTeam == 3)
	{
		PrintCenterText(attacker, "%t", "PlayerPropHP", g_iMineHP[victim], iOwner, "Human");
		return Plugin_Continue;
	}

	int damageMultiplier = (!g_cvNadePickup.BoolValue && damagetype == DMG_BLAST && attacker == iOwner) ? 0 : (attacker == iOwner) ? 4 : 1;
	g_iMineHP[victim] -= RoundToZero(damage) * damageMultiplier;

	if (g_iMineHP[victim] > 0)
	{
		PrintCenterText(attacker, "%t", "PlayerPropHP", g_iMineHP[victim], iOwner, "Human");
		return Plugin_Continue;
	}

	if (g_cvAllowPickup.BoolValue && attacker == iOwner)
		PickupLasermine(attacker, victim);
	else
		AcceptEntityInput(victim, "KillHierarchy");

	return Plugin_Continue;
}

public Action OnActivateLaser(Handle Timer, DataPack hDataPack)
{
	hDataPack.Reset();

	char Start[32], Temp[256];
	int iColor[3];

	int iBeamEnt = hDataPack.ReadCell();
	int iEnt = hDataPack.ReadCell();
	iColor[0] = hDataPack.ReadCell();
	iColor[1] = hDataPack.ReadCell();
	iColor[2] = hDataPack.ReadCell();
	hDataPack.ReadString(Start, sizeof(Start));

	if (!IsValidEdict(iBeamEnt) || !IsValidEdict(iEnt))
		return Plugin_Stop;

	AcceptEntityInput(iBeamEnt, "TurnOn");

	SetEntityRenderColor(iBeamEnt, iColor[0], iColor[1], iColor[2]);

	FormatEx(Temp, sizeof(Temp), "%s,TurnOff,,0.001,-1", Start);
	DispatchKeyValue(iBeamEnt, "OnTouchedByEntity", Temp);
	FormatEx(Temp, sizeof(Temp), "%s,TurnOn,,0.002,-1", Start);
	DispatchKeyValue(iBeamEnt, "OnTouchedByEntity", Temp);

	EmitSoundToAll(SND_MINEACTIVATED, iEnt);

	return Plugin_Stop;
}

// Flashlight x2 : Lasermines
public Action OnPlayerRunCmd(int client, int &buttons, int &impulse)
{
	if (IsValidClient(client))
	{
		// Flashlight
		if (impulse == 0x64)
		{
			QuickMarkerCommand(client);
			return Plugin_Continue;
		}
	}

	return Plugin_Continue;
}

stock void QuickMarkerCommand(int client)
{
	if (g_bShorcut[client])
	{
		g_iButtonMarkerCount[client]++;
		CreateTimer(1.0, ResetMarkerButtonPressed, client, TIMER_FLAG_NO_MAPCHANGE);
	}

	if (g_iButtonMarkerCount[client] >= 2 && IsValidClient(client))
		AttemptPlantMine(client);
}

public Action ResetMarkerButtonPressed(Handle timer, any client)
{
	g_iButtonMarkerCount[client] = 0;
	return Plugin_Handled;
}

// NATIVES
public int Native_AddMines(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);

	if (client < 1 || client > MaxClients)
	{
		ThrowNativeError(SP_ERROR_INDEX, "Client index %i is invalid", client);
		return -1;
	}
	if (!IsClientInGame(client))
	{
		ThrowNativeError(SP_ERROR_NOT_FOUND, "Client %i is not in game", client);
		return -1;
	}

	int iNativeAmount = GetNativeCell(2);
	bool g_bLimit = GetNativeCell(3);

	if (iNativeAmount <= 0)
		return g_iAmountLeft[client];

	if (g_iAmountLeft[client] < 0)
		return -1;

	g_iAmountLeft[client] += iNativeAmount;

	if (g_bLimit && g_iAmountLeft[client] > g_iClientsMaxLimit[client])
		g_iAmountLeft[client] = g_iClientsMaxLimit[client];

	return g_iAmountLeft[client];
}

public int Native_SetMines(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);

	if (client < 1 || client > MaxClients)
	{
		ThrowNativeError(SP_ERROR_INDEX, "Client index %i is invalid", client);
		return -1;
	}
	if (!IsClientInGame(client))
	{
		ThrowNativeError(SP_ERROR_NOT_FOUND, "Client %i is not in game", client);
		return -1;
	}

	int iNativeAmount = GetNativeCell(2);
	bool bLimit = GetNativeCell(3);

	if (iNativeAmount < -1)
		iNativeAmount = -1;

	g_iAmountLeft[client] = iNativeAmount;

	if (bLimit && g_iAmountLeft[client] > g_iClientsMaxLimit[client])
		g_iAmountLeft[client] = g_iClientsMaxLimit[client];

	return 0;
}

public int Native_SubstractMines(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);

	if (client < 1 || client > MaxClients)
	{
		ThrowNativeError(SP_ERROR_INDEX, "Client index %i is invalid", client);
		return 0;
	}
	if (!IsClientInGame(client))
	{
		ThrowNativeError(SP_ERROR_NOT_FOUND, "Client %i is not in game", client);
		return 0;
	}

	int g_iNativeAmount = GetNativeCell(2);

	if (g_iAmountLeft[client] == -1 || g_iNativeAmount <= 0)
		return g_iAmountLeft[client];

	g_iAmountLeft[client] -= g_iNativeAmount;

	if (g_iAmountLeft[client] < 0)
		g_iAmountLeft[client] = 0;

	return g_iAmountLeft[client];
}

Handle TraceRay(int client)
{
	float fStart[3], fAngle[3], fEnd[3];

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
	return (entity < 1 || entity > MaxClients);
}

public int Native_GetMines(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);

	if (client < 1 || client > MaxClients)
	{
		ThrowNativeError(SP_ERROR_INDEX, "Client index %i is invalid", client);
		return 0;
	}
	if (!IsClientInGame(client))
	{
		ThrowNativeError(SP_ERROR_NOT_FOUND, "Client %i is not in game", client);
		return 0;
	}

	return g_iAmountLeft[client];
}

public int Native_ClearMapMines(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);

	if (client < 1 || client > MaxClients)
	{
		ThrowNativeError(SP_ERROR_INDEX, "Client index %i is invalid", client);
		return -1;
	}
	if (!IsClientInGame(client))
	{
		ThrowNativeError(SP_ERROR_NOT_FOUND, "Client %i is not in game", client);
		return -1;
	}

	OnClientDisconnect(client);
	return 0;
}

public int Native_IsLasermine(Handle plugin, int numParams)
{
	int iEnt = GetNativeCell(1);

	if (iEnt <= MaxClients || !IsValidEdict(iEnt))
		return false;

	char ModelName[PLATFORM_MAX_PATH];
	GetEntPropString(iEnt, Prop_Data, "m_ModelName", ModelName, sizeof(ModelName));

	return(strcmp(ModelName, MDL_MINE, false) == 0 && GetEntPropEnt(iEnt, Prop_Data, "m_hMoveChild") != -1);
}

public int Native_GetClientByLasermine(Handle plugin, int numParams)
{
	int iEnt = GetNativeCell(1);
	int iBeamEnt = ZR_GetBeamByLasermine(iEnt);

	if (iBeamEnt == -1)
		return -1;

	return GetEntPropEnt(iBeamEnt, Prop_Data, "m_hOwnerEntity");
}

public int Native_SetClientMaxLasermines(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if (client < 1 || client > MaxClients)
	{
		ThrowNativeError(SP_ERROR_INDEX, "Client index %i is invalid", client);
		return -1;
	}
	if (!IsClientAuthorized(client))
	{
		ThrowNativeError(SP_ERROR_NOT_FOUND, "Client %i is not authorized", client);
		return -1;
	}

	int iNativeAmount = GetNativeCell(2);

	if (iNativeAmount < 0)
	{
		g_iClientsMaxLimit[client] = g_cvMaxMineAmount.IntValue;
		g_iClientsMyAmount[client] = g_cvSpawnMineAmount.IntValue;
	}

	g_iClientsMaxLimit[client] = iNativeAmount;
	g_iClientsMyAmount[client] = iNativeAmount;
	g_bUsedByNative[client] = true;

	return 0;
}

public int Native_ResetClientMaxLasermines(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if (client < 1 || client > MaxClients)
	{
		ThrowNativeError(SP_ERROR_INDEX, "Client index %i is invalid", client);
		return -1;
	}
	if (!IsClientConnected(client))
	{
		ThrowNativeError(SP_ERROR_NOT_FOUND, "Client %i is not connected", client);
		return -1;
	}

	OnClientConnected(client);
	return 0;
}

public int Native_GetBeamByLasermine(Handle plugin, int numParams)
{
	int iEnt = GetNativeCell(1);
	if (!ZR_IsEntityLasermine(iEnt))
		return -1;

	return GetEntPropEnt(iEnt, Prop_Data, "m_hMoveChild");
}

public int Native_GetLasermineByBeam(Handle plugin, int numParams)
{
	return GetEntPropEnt(GetNativeCell(1), Prop_Data, "m_hEffectEntity");
}

bool IsValidClient(int client)
{
	return(IsClientInGame(client) && IsPlayerAlive(client) && GetClientTeam(client) == CS_TEAM_CT);
}

bool TraceRay_FilterAll(int entity, int mask, any data)
{
	return false;
}