#if defined _roleplay_included
  #endinput
#endif
#define _roleplay_included

/**
 * Money account amount.
 *
 * @param client     Client index.
 * @return           Amount of money in their money account.
 */
native GetClientMoney(client);

/**
 * Set Money.
 *
 * @param client     Client index.
 * @param amount	 Amount of money to put in their money account.
 * @return           Nothing.
 */
native SetClientMoney(client, amount);

/**
 * Bank account amount.
 *
 * @param client     Client index.
 * @return           Amount of money in their bank account.
 */
native GetClientBank(client);

/**
 * Set Bank money.
 *
 * @param client     Client index.
 * @param amount	 Amount of money to put in their bank account.
 * @return           Nothing.
 */
native SetClientBank(client, amount);

/**
 * Remove all weapons
 *
 * @param client	Client index
 * @return			true/false
 */
native bool RP_RemoveWeapon(client);

/**
 * Trace Ray Filter prop
 *
 * @param client	Client index
 * @return			Nothing.
 */
native int AimTargetProp(client);

/**
 * Trace Ray Filter player
 *
 * @param client	Client index
 * @return			Nothing.
 */
native int AimTargetPlayer(client);

/**
 * Started DB roleplay
 *
 * @return			false/true
 */
native bool RP_IsStartedDB();

/**
 * Is client handcuffed.
 *
 * @param client     Client index.
 * @return           True if handcuffed, false otherwise.
 */
native bool RP_IsHandcuffed();

/**
 * Global start timer
 *
 * @noreturn
 */
forward Action RP_StartGlobalTimer();

public SharedPlugin __pl_roleplay =
{
    name = "roleplay",
    file = "sm_roleplay.smx",
#if defined REQUIRE_PLUGIN
    required = 1,
#else
    required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_roleplay_SetNTVOptional()
{
    MarkNativeAsOptional("GetClientMoney");
    MarkNativeAsOptional("SetClientMoney");
    MarkNativeAsOptional("GetClientBank");
    MarkNativeAsOptional("SetClientBank");
    MarkNativeAsOptional("RP_RemoveWeapon");
	MarkNativeAsOptional("AimTargetProp");
	MarkNativeAsOptional("AimTargetPlayer");
	MarkNativeAsOptional("RP_IsStartedDB");
	MarkNativeAsOptional("RP_IsHandcuffed");
}
#endif