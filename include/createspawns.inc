#if defined _createspawns_included
  #endinput
#endif
#define _createspawns_included

/**
 * Teleport player to cell
 *
 * @param client	Client index
 * @return			Nothing.
 */
native int RP_TeleportToCell(client);

/**
 * Teleport player to exit cell
 *
 * @param client	Client index
 * @return			Nothing.
 */
native int RP_TeleportToExitCell(client);

public SharedPlugin __pl_createspawns =
{
    name = "createspawns",
    file = "sm_createspawns.smx",
#if defined REQUIRE_PLUGIN
    required = 1,
#else
    required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_createspawns_SetNTVOptional()
{
    MarkNativeAsOptional("RP_TeleportToCell");
	MarkNativeAsOptional("RP_TeleportToExitCell");
}
#endif