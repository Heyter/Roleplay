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

public SharedPlugin __pl_core =
{
    name = "core",
    file = "core.smx",
#if defined REQUIRE_PLUGIN
    required = 1,
#else
    required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_core_SetNTVOptional()
{
    MarkNativeAsOptional("GetClientMoney");
    MarkNativeAsOptional("SetClientMoney");
    MarkNativeAsOptional("GetClientBank");
    MarkNativeAsOptional("SetClientBank");
    MarkNativeAsOptional("RP_RemoveWeapon");
}
#endif