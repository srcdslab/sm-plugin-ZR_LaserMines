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
native ZR_AddClientLasermines(client, amount = 1, bool:uselimit = true);

/**
 * Sets the player's amount of the remaining laser mines
 *
 * @param client 	Client index to set to
 * @param amount    Amount of laser mines to set. Negative numbers to set to infinity, 0 - to remove all and positive number to set to the amount
 * @param uselimit  Set to true to use the plugin limitation, false to ignore
 * @return			true on success, false otherwise
 */
native bool:ZR_SetClientLasermines(client, amount, bool:uselimit = true);

/**
 * Subtracts one or more remaining lasermines from the player
 *
 * @param client 	Client index to substract from
 * @param amount    Amount of laser mines to substract.
 * @return			new amount of laser mines
 */
native ZR_SubClientLasermines(client, amount = 1);

/**
 * Returns number of remaining laser mines a player has.
 *
 * @param client 	Client index to get from
 * @return			number of remaining laser mines.
 */
native ZR_GetClientLasermines(client);

/**
 * Foces a player to plant laser mine without substracting his amount. Does not call ZR_OnPlantLasermine
 *
 * @param client 			Client index to force to
 * @param activation_delay	The activation time
 * @param explosion_damage	Explosion damage
 * @param explosion_radius 	Explosion radius
 * @param health 			The laser mine's health. 0 = Unbreakable
 * @param color 			The laser mine's color.
 * @return			true on success, false otherwise
 */
native bool:ZR_PlantClientLasermine(client, Float:activation_delay = 2.0, explosion_damage = 100, explosion_radius = 300, health = 0, color[3] = {255, 255, 255});

/**
 * Clears the map from the player's laser mines
 *
 * @param client 	Client index to clear
 * @noreturn
 */
native ZR_ClearMapClientLasermines(client);

/**
 * Checks whether the entity is a lasermine
 *
 * @param entity 	Entity index to check
 * @return			True if the entity is a lasermine, false otherwise
 */
native bool:ZR_IsEntityLasermine(entity);

/**
 * Gets client index by the lasermine
 *
 * @param client 	Entity index to get the owner for
 * @return			Client index or -1 if no client found
 */
native ZR_GetClientByLasermine(entity);

/**
 * Sets client max amount of lasermines
 *
 * @param client 	Client index to set for
 * @param amount 	The max amount to set
 * @noreturn
 */
native ZR_SetClientMaxLasermines(client, amount);

/**
 * Gets beam index by the lasermine
 *
 * @param client 	The lasermine index to get the beam for
 * @return			Beam index or -1 if no beam found
 */
native ZR_GetBeamByLasermine(entity);

/**
 * Gets lasermine index by the beam
 *
 * @param client 	The beam index to get the lasermine for
 * @return			Lasermine index or -1 if no lasermine found
 */
native ZR_GetLasermineByBeam(entity);

/**
 * Called when the player is about to buy a laser mine
 *
 * @param client 	Client index of the player who is buying a laser mine
 * @param amount 	The amount of laser mines a player is going to buy. Set by reference
 * @param price 	The laser mine price. Set by reference
 * @return 		Plugin_Changed to apply new values, Plugin_Contninue to allow buy as is and >= Plugin_Handled to block the operation
 */
forward Action:ZR_OnPreBuyLasermine(client, &amount, &price);


/**
 * Called when a player has bought a laser mine
 *
 * @param victim 	Client index of the player who has bought
 * @param amount 	The amount of laser mines have been bought
 * @param amount 	The sum of money the player cost
 * @noreturn
 */
forward ZR_OnPostBuyLasermine(client, amount, sum);

/**
 * Called when the player is about to plant a laser mine
 *
 * @param client 			Client index of the player
 * @param act_delay 		Activation time. Set by reference
 * @param explosion_damage	Explosion damage. Set by reference
 * @param explosion_radius 	Explosion radius. Set by reference
 * @param health			The laser mine's health. Set by reference
 * @param color[3]			The laser mine's color. Set by reference
 * @return 		Plugin_Changed to apply new values, Plugin_Contninue to allow the planting as is and >= Plugin_Handled to block the planting
 */
forward Action:ZR_OnPlantLasermine(client, &Float:act_delay, &exp_damage, &exp_radius, &health, color[3]);

/**
 * Called when the player planted a laser mine
 *
 * @param act_delay 		Activation time
 * @param lasermine 		The lasermine index
 * @param explosion_damage	Explosion damage
 * @param explosion_radius 	Explosion radius
 * @param health			The laser mine's health
 * @param color[3]			The laser mine's color
 * @noreturn
 */
forward ZR_OnLaserminePlanted(client, lasermine, Float:act_delay, exp_damage, exp_radius, health, color[3]);

/**
 * Called when the player is about to be hitted by a laser mine
 *
 * @param victim 		Client index of the player who is being hitted
 * @param attacker 		The owner index of the laser mine. Set by reference
 * @param beam 			The beam index which is going to inflict the victim. Set by reference
 * @param lasermine 	The lasermine index which is going to inflict the victim. Set by reference
 * @param damage 		Damage of the hit. Set by reference
 * @return 		Plugin_Changed to apply new values, Plugin_Contninue to allow the hit as is and >= Plugin_Handled to block the hit
 */
forward Action:ZR_OnPreHitByLasermine(victim, &attacker, &beam, &lasermine, &damage);


/**
 * Called when the player has been hitted by a laser mine
 *
 * @param victim 		Client index of the player who has been hitted
 * @param attacker 		The owner index of the laser mine
 * @param beam 			The beam index which has inflicted the victim
 * @param lasermine 	The lasermine index which has inflicted the victim
 * @param damage 		Damage of the hit
 * @noreturn
 */
forward ZR_OnPostHitByLasermine(victim, attacker, beam, lasermine, damage);

/**
 * Called when the player is about to pickup a lasermine
 *
 * @param client 		Client index of the player who is going to pickup
 * @param lasermine 	Lasermine index which is being picked up
 * @param owner 		The lasermine's owner index.
 * @return 		 Plugin_Contninue or Plugin_Changed to allow the pickup and Plugin_Handled or Plugin_Stop to block the pickup
 */
forward Action:ZR_OnPrePickupLasermine(client, lasermine, owner);


/**
 * Called when the player has picked up a lasermine
 *
 * @param client 		Client index of the player who has picked up a lasermine
 * @param lasermine 	Lasermine index which was picked up
 * @param owner 		The lasermine's owner index
 * @noeturn
 */
forward ZR_OnPostPickupLasermine(client, lasermine, owner);


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
