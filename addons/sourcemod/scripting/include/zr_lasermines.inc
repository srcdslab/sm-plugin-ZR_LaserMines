#if defined _zrlasermines_included
 #endinput
#endif
#define _zrlasermines_included

/**
 * Adds one or more remaining laser mines to the player
 *
 * @param client 	Client index to add to
 * @param amount    Amount of laser mines to add.
 * @param uselimit  Set to true to use the plugin limitation, false to ignore
 * @return			New amount of laser mines. 0 if no lasermines added and -1 if the player has unlimited lasermines
 */
native int ZR_AddClientLasermines(int client, int amount = 1, bool uselimit = true);

/**
 * Sets the player's amount of the remaining laser mines
 *
 * @param client 	Client index to set to
 * @param amount    Amount of laser mines to set. Negative numbers to set to infinity, 0 - to remove all and positive number to set to the amount
 * @param uselimit  Set to true to use the plugin limitation, false to ignore
 * @return			true on success, false otherwise
 */
native bool ZR_SetClientLasermines(int client, int amount, bool uselimit = true);

/**
 * Subtracts one or more remaining lasermines from the player
 *
 * @param client 	Client index to substract from
 * @param amount    Amount of laser mines to substract.
 * @return			new amount of laser mines
 */
native int ZR_SubClientLasermines(int client, int amount = 1);

/**
 * Returns number of remaining laser mines a player has.
 *
 * @param client 	Client index to get from
 * @return			number of remaining laser mines.
 */
native int ZR_GetClientLasermines(int client);

/**
 * Clears the map from the player's laser mines
 *
 * @param client 	Client index to clear
 * @noreturn
 */
native void ZR_ClearMapClientLasermines(int client);

/**
 * Checks whether the entity is a lasermine
 *
 * @param entity 	Entity index to check
 * @return			True if the entity is a lasermine, false otherwise
 */
native bool ZR_IsEntityLasermine(int entity);

/**
 * Gets client index by the lasermine
 *
 * @param client 	Entity index to get the owner for
 * @return			Client index or -1 if no client found
 */
native int ZR_GetClientByLasermine(int entity);

/**
 * Sets client max amount of lasermines
 *
 * @param client 	Client index to set for
 * @param amount 	The max amount to set
 * @noreturn
 */
native void ZR_SetClientMaxLasermines(int client, int amount);

/**
 * Gets beam index by the lasermine
 *
 * @param client 	The lasermine index to get the beam for
 * @return			Beam index or -1 if no beam found
 */
native int ZR_GetBeamByLasermine(int entity);

/**
 * Gets lasermine index by the beam
 *
 * @param client 	The beam index to get the lasermine for
 * @return			Lasermine index or -1 if no lasermine found
 */
native int ZR_GetLasermineByBeam(int entity);


/* --------------------------------------------
	Don't edit below this line
-------------------------------------------- */

public SharedPlugin:__pl_zrlasermines = 
{
	name = "zr_lasermines",
	file = "zr_lasermines.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public __pl_zrlasermines_SetNTVOptional()
{
	MarkNativeAsOptional("ZR_AddClientLasermines");
	MarkNativeAsOptional("ZR_SetClientLasermines");
	MarkNativeAsOptional("ZR_SubClientLasermines");
	MarkNativeAsOptional("ZR_GetClientLasermines");
	MarkNativeAsOptional("ZR_PlantClientLasermine");
	MarkNativeAsOptional("ZR_ClearMapClientLasermines");
	MarkNativeAsOptional("ZR_IsEntityLasermine");
	MarkNativeAsOptional("ZR_GetClientByLasermine");
	MarkNativeAsOptional("ZR_SetClientMaxLasermines");
	MarkNativeAsOptional("ZR_GetBeamByLasermine");
	MarkNativeAsOptional("ZR_GetLasermineByBeam");
}
#endif
