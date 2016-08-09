#pragma semicolon 1
#include <sdktools>
#include <sdkhooks>
#include <colors_csgo>
#include <cstrike>
#pragma newdecls required

// * Fade Defines * //
#define FFADE_IN               0x0001
#define FFADE_OUT              0x0002
#define FFADE_MODULATE         0x0004
#define FFADE_STAYOUT          0x0008
#define FFADE_PURGE            0x0010

#define DEATH_COLOR           {0,0,0,255}

#define MIN_DISTANCE_USE 100
#define IDSIZE 64

// macross
//#define RemoveJob(%1) SetClientJob(%1, "", ""), CS_SwitchTeam(%1, CS_TEAM_T)
//#define IsHaveJob(%1) (g_jobid[%1][0] != '\0')

Database g_db;
bool db_mysql, started;
char db_prefix[15] = "rp_",
	Logs[256] = "addons/sourcemod/logs/rp_logs.log";

ConVar Database_prefix;
// * Player Global * //
int RP_ID[MAXPLAYERS + 1], RP_Money[MAXPLAYERS + 1], RP_Bank[MAXPLAYERS + 1],
	g_jobTarget[MAXPLAYERS + 1], RP_RespawnTime[MAXPLAYERS + 1], RP_Salary[MAXPLAYERS + 1];
char g_jobid[MAXPLAYERS + 1][IDSIZE], g_rankid[MAXPLAYERS + 1][IDSIZE], g_sBuffer[MAX_NAME_LENGTH];
float RP_LastMsg[MAXPLAYERS + 1];
bool RP_Hud[MAXPLAYERS + 1];

// * KeyValues - jobs.txt * //
KeyValues g_kv;
Menu g_jobsmenu;

// * KeyValues - settings.txt * //
float fChatDistance;
bool iFog;
KeyValues g_settingsKV;
int iSalaryTimer, iSalaryEnd;

// * Global string - keyvalues * //
char model[PLATFORM_MAX_PATH], atm_model[PLATFORM_MAX_PATH], money_model[PLATFORM_MAX_PATH];

// * OnPlayerRunCmd * //
bool g_bPressedUse[MAXPLAYERS + 1];
float g_flPressUse[MAXPLAYERS + 1], g_fATMorigin[MAXPLAYERS + 1][3];

// * AddCommandListener * //
char Forbidden_Commands[][] = {
    "explode",		"kill",			"coverme",		"takepoint",
    "holdpos",		"regroup",		"followme",		"takingfire",
    "go",			"fallback",		"sticktog",		"getinpos",
    "stormfront",	"report",		"roger",		"enemyspot",
    "needbackup",	"sectorclear",	"inposition",	"reportingin",
    "getout",		"negative",		"enemydown",	"spectate",
    "jointeam",		"suicide",
};

// * Plugin info * //
public Plugin info = {
	author = "Hikka, Kailo, Exle",
	name = "[SM] Roleplay mod",
	version = "alpha 0.08",
	url = "https://github.com/Heyter/Roleplay",
};

public void OnPluginStart(){
	// * Database * //
	DB_PreConnect();
	
	RegCvars();
	
	for (int i = 0; i < sizeof(Forbidden_Commands); i++){
		AddCommandListener(ForbiddenCommands, Forbidden_Commands[i]);
	}
	AddCommandListener(Chat_Say, "say");
	AddCommandListener(Chat_Say, "say_team");
	
	// * KeyValues - jobs.txt * //
	LoadKVJobs();
	BuildJobsMenu();
	// * KeyValues - settings.txt * //
	LoadKVSettings();
	
	RegConsoleCmd("sm_dropmoney", sm_dropmoney, "sm_dropmoney <amount>");
	RegConsoleCmd("sm_hud", sm_hud, "Open RP hud menu");
	RegConsoleCmd("sm_invitejob", sm_invitejob, "Invite to work, only boss");
	RegConsoleCmd("sm_leavejob", sm_leavejob, "Leave job");

	RegAdminCmd("sm_jobs", Cmd_Jobs, ADMFLAG_ROOT, "Set job for player");
	RegAdminCmd("sm_reloadsettings", sm_ReloadSettings, ADMFLAG_ROOT, "Reload config settings.txt");
	RegAdminCmd("sm_reloadjobs", Cmd_ReloadJobs, ADMFLAG_ROOT, "Reload config jobs.txt");
	RegAdminCmd("sm_unemployed", sm_unemployed, ADMFLAG_ROOT, "Set unemployed for player");				// Experimental
	RegAdminCmd("sm_givemoney", sm_givemoney, ADMFLAG_ROOT, "Give money");
	RegAdminCmd("sm_setmoney", sm_setmoney, ADMFLAG_ROOT, "Set money");
	RegAdminCmd("sm_givebank", sm_givebank, ADMFLAG_ROOT, "Give money in bank");
	RegAdminCmd("sm_setbank", sm_setbank, ADMFLAG_ROOT, "Set money in bank");
	RegAdminCmd("sm_dbsave", sm_dbsave, ADMFLAG_ROOT, "Force Server DB Save");
	RegAdminCmd("sm_dbsavemoney", sm_dbsavemoney, ADMFLAG_ROOT, "Force Server DB Save Money");
	RegAdminCmd("sm_dbsavejobs", sm_dbsavejobs, ADMFLAG_ROOT, "Force Server DB Save Jobs");
	RegAdminCmd("sm_adminmenu", sm_adminmenu, ADMFLAG_ROOT, "Admin menu - RP");
	RegAdminCmd("sm_userlist", sm_userlist, ADMFLAG_ROOT, "User list");
	
	HookEvent("round_start", Event_RoundStart);
	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_Pre);
	
	CreateTimer(1.0, OnEverySecond, _, TIMER_REPEAT);
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max){
	RegPluginLibrary("roleplay");
	
	CreateNative("GetClientMoney", NativeGetClientMoney);
	CreateNative("SetClientMoney", NativeSetClientMoney);
	CreateNative("GetClientBank", NativeGetClientBank);
	CreateNative("SetClientBank", NativeSetClientBank);
	CreateNative("RP_RemoveWeapon", Native_RP_RemoveWeapon);
	
	PrintToServer("[RP] Natives Loaded");
	return APLRes_Success;
}

public int NativeGetClientMoney(Handle plugin, int numParams){
	int client = GetNativeCell(1);
	return RP_Money[client];
}

public int NativeSetClientMoney(Handle plugin, int numParams){
	int client = GetNativeCell(1),
		amount = GetNativeCell(2);
	RP_Money[client] = amount;
	return;
}

public int NativeGetClientBank(Handle plugin, int numParams){
	return RP_Bank[GetNativeCell(1)];
}

public int NativeSetClientBank(Handle plugin, int numParams){
	int client = GetNativeCell(1),
		amount = GetNativeCell(2);
	RP_Bank[client] = amount;
	return;
}

public int Native_RP_RemoveWeapon(Handle plugin, int numParams){
    return RemoveWeapon(GetNativeCell(1));
}

public void OnClientPutInServer(int client) {
	if (!RP_IsStarted()) return;
	
	CreateTimer(1.0, Timer_1, client);
	
	ResetVariables(client);
	SDKHookEx(client, SDKHook_OnTakeDamage, OnTakeDamage);
	DB_OnClientPutInServer(client);
}


public Action Timer_1(Handle timer, any client)
{
	if (client && IsClientInGame(client)){
		ChangeClientTeam(client, 1);
	}
	CreateTimer(5.0, Timer_2, client);
}

public Action Timer_2(Handle timer, any client)
{
	if (client && IsClientInGame(client)) 
	{
		ChangeClientTeam(client, 2);
	}
}

public void OnClientDisconnect(int client){
	if (!RP_IsStarted()) {
		return;
	}
	DB_SaveClient(client);
	SDKUnhook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

public void OnMapStart(){
	ServerCommand("mp_startmoney 0");
	ServerCommand("sv_disable_show_team_select_menu 1");
	ServerCommand("mp_teammates_are_enemies 1");
	ServerCommand("mp_ignore_round_win_conditions 1");
	ServerCommand("mp_warmuptime 0");
	ServerCommand("mp_do_warmup_period 0");
	ServerCommand("mp_forcecamera 1");
	
	PrecacheModels();
	
	GetSalaryTimer();
	iSalaryEnd = iSalaryTimer;
}

public void CvarChange(ConVar convar, const char[] oldValue, const char[] newValue) {
	if (convar == Database_prefix) {
		if (StrContains(newValue, "_") != -1) {
			Database_prefix.GetString(db_prefix, sizeof(db_prefix));
		}
		else {
			strcopy(db_prefix, sizeof(db_prefix), "rp_");
		}
	}
}

//////////////////
// * DATABASE * //
//////////////////

void DB_PreConnect() {
	if (g_db != null) {
		return;
	}

	if (SQL_CheckConfig("roleplay")) {
		Database.Connect(DB_Connect, "roleplay", 1);
	}
	else {
		char error[256];

		g_db = SQLite_UseDatabase("roleplay", error, sizeof(error));

		DB_Connect(g_db, error, 2);
	}
}

public Action DB_ReconnectTimer(Handle timer) {
	if (g_db == null) {
		DB_PreConnect();
	}
}

public void DB_Connect(Database db, const char[] error, any data) {
	g_db = db;

	if (g_db == null) {
		LogToFile(Logs, "[RP - Errors] DB_Connect: %s", error);
		LogError("DB_Connect: %s", error);
		CreateTimer(10.0, DB_ReconnectTimer);
		return;
	}

	if (error[0]) {
		LogToFile(Logs, "[RP - Errors] (data %d) DB_Connect: %s", data, error);
		LogError("DB_Connect %d: %s", data, error);
	}

	char ident[16];
	g_db.Driver.GetIdentifier(ident, sizeof(ident));
	
	if (StrEqual(ident, "mysql", false)) {
		db_mysql = true;
	}
	else if (StrEqual(ident, "sqlite", false)) {
		db_mysql = false;
	}
	else {
		LogToFile(Logs, "[RP - Errors] DB_Connect: Driver \"%s\" is not supported!", ident);
		SetFailState("DB_Connect: Driver \"%s\" is not supported!", ident);
	}

	g_db.SetCharset("utf8");

	DB_CreateTables(g_db);
}

void DB_CreateTables(Database db) {
	char query[512];
	if (db_mysql) {
		FormatEx(query, sizeof(query), "CREATE TABLE IF NOT EXISTS `%splayers` (\
							  `id` int(5) NOT NULL AUTO_INCREMENT,\
							  `name` varchar(32) NOT NULL DEFAULT 'unknown',\
							  `auth` varchar(22) NOT NULL,\
							  `position` varchar(32) NOT NULL DEFAULT 'unknown',\
							  PRIMARY KEY (`id`), \
								UNIQUE KEY `auth` (`auth`) \
							) ENGINE=MyISAM DEFAULT CHARSET=utf8 AUTO_INCREMENT=1;", db_prefix);

		db.Query(DB_PlayersTable, query, 1, DBPrio_High);

		FormatEx(query, sizeof(query), "CREATE TABLE IF NOT EXISTS `%splayers_info` (\
							  `id` int(5) NOT NULL,\
							  `auth` varchar(22) NOT NULL,\
							  `jobid` varchar(32) NOT NULL DEFAULT 'idlejob',\
							  `rankid` varchar(32) NOT NULL DEFAULT 'idlerank',\
							  `money` int(12) NOT NULL,\
							  `bank_money` int(12) NOT NULL,\
							  PRIMARY KEY (`id`), \
								UNIQUE KEY `auth` (`auth`) \
							) ENGINE=MyISAM DEFAULT CHARSET=utf8 AUTO_INCREMENT=1;", db_prefix);
		db.Query(DB_PlayersTable, query, 2, DBPrio_High);
	} else {
		FormatEx(query, sizeof(query), "CREATE TABLE IF NOT EXISTS `%splayers` (\
							  `id` INTEGER PRIMARY KEY AUTOINCREMENT,\
							  `name` VARCHAR DEFAULT 'unknown',\
							  `auth` VARCHAR UNIQUE ON CONFLICT IGNORE,\
							  `position` VARCHAR DEFAULT 'unknown');", db_prefix);

		db.Query(DB_PlayersTable, query, 1, DBPrio_High);
		
		FormatEx(query, sizeof(query), "CREATE TABLE IF NOT EXISTS `%splayers_info` (\
							  `id` INTEGER PRIMARY KEY,\
							  `auth` VARCHAR UNIQUE ON CONFLICT IGNORE,\
							  `jobid` VARCHAR DEFAULT 'idlejob',\
							  `rankid` VARCHAR DEFAULT 'idlerank',\
							  `money` NUMERIC DEFAULT '0',\
							  `bank_money` NUMERIC DEFAULT '0');", db_prefix);

		db.Query(DB_PlayersTable, query, 2, DBPrio_High);
	}
}

public void DB_PlayersTable(Database db, DBResultSet results, const char[] error, any data) {
	if (error[0]) {
		LogToFile(Logs, "[RP - Errors] (data %d) DB_PlayersTable: %s", data, error);
		LogError("DB_PlayersTable %d: %s", data, error);
		delete g_db;
		g_db = null;
		CreateTimer(10.0, DB_ReconnectTimer);
		return;
	}

	if (data == 2) {
		RP_Start();
	}
}

void DB_OnClientPutInServer(int client, DBPriority prio = DBPrio_Normal) {
	if (g_db == null || !RP_IsStarted()) {
		LogToFile(Logs, "[RP - Warnings] DB_OnClientPutInServer: g_db = (%d) or rp %s", g_db, RP_IsStarted() ? "started" : "not started");
		return;
	}

	char auth[32], query[512];
	Client_SteamID(client, auth, sizeof(auth));

	FormatEx(query, sizeof(query), "SELECT `id`, `position` FROM `%splayers` WHERE auth = '%s';", db_prefix, auth);

	g_db.Query(DB_OnClientPutInServerCallback, query, client, prio);
}

public void DB_OnClientPutInServerCallback(Database db, DBResultSet results, const char[] error, any data) {
	if (!IsClientInGame(data)) return;

	if (results.HasResults && results.FetchRow()) {
		RP_ID[data] = results.FetchInt(0);
	
		char position[64];

		results.FetchString(1, position, sizeof(position));
		if (StrContains(position, "unknown") == -1) {
			float pos[3];
			char buffer[3][15];

			ExplodeString(position, " ", buffer, 3, 15);

			TrimString(buffer[0]); pos[0] = StringToFloat(buffer[0]);
			TrimString(buffer[1]); pos[1] = StringToFloat(buffer[1]);
			TrimString(buffer[2]); pos[2] = StringToFloat(buffer[2]);

			Client_Teleport(data, pos);
		}

		DB_LoadClientInfo(data);
	}
	else {
		char query[512],
			 name[MAX_NAME_LENGTH],
			 buffer[65];

		Client_GetName(data, name, sizeof(name));
		EscapeString(db, name, buffer, sizeof(buffer));

		char auth[32];
		Client_SteamID(data, auth, sizeof(auth));

		FormatEx(query, sizeof(query), "INSERT INTO `%splayers` (`name`, `auth`) VALUES ('%s', '%s');", db_prefix, buffer, auth);
		DB_TQueryEx(query, _, 0);

		DB_OnClientPutInServer(data);
	}
}

void DB_LoadClientInfo(int client, DBPriority prio = DBPrio_Normal) {
	if (g_db == null) {
		LogToFile(Logs, "[RP - Warnings] DB_LoadClientInfo: g_db = (%d) or rp %s", g_db, RP_IsStarted() ? "started" : "not started");
		return;
	}

	char query[512], auth[32];
	
	Client_SteamID(client, auth, sizeof(auth));

	FormatEx(query, sizeof(query), "SELECT `jobid`, `rankid`, `money`, `bank_money` FROM `%splayers_info` WHERE auth = '%s';", db_prefix, auth);

	g_db.Query(DB_LoadClientInfo_Select, query, client, prio);
}

public void DB_LoadClientInfo_Select(Database db, DBResultSet results, const char[] error, any data) {
	if (!IsClientInGame(data)) return;

	char buffer[MAX_NAME_LENGTH], buffer2[MAX_NAME_LENGTH];
	if (results.HasResults && results.FetchRow()) {
		//results.FetchString(0, buffer, sizeof(buffer));
		//results.FetchString(1, buffer2, sizeof(buffer2));
		results.FetchString(0, g_jobid[data], sizeof(g_jobid[]));
		results.FetchString(1, g_rankid[data], sizeof(g_rankid[]));
		GetName(data, buffer, sizeof(buffer), buffer2, sizeof(buffer2));
		//SetClientJobDB(data, buffer, buffer2);
		g_jobid[data] = buffer;
		g_rankid[data] = buffer2;
		//g_jobid[data] = g_jobid[data];			// <======== если работа вновь не показывается, использовать этот вариант <========
		//g_rankid[data] = g_rankid[data];

		RP_Money[data] = results.FetchInt(2);
		RP_Bank[data] = results.FetchInt(3);
	}
	else {
		char query[512],
			auth[32],
			buff[MAX_NAME_LENGTH], buff2[MAX_NAME_LENGTH];
			
		Client_SteamID(data, auth, sizeof(auth));

		g_kv.GetString("idlejob", buff, sizeof(buff), g_jobid[data]);
		g_kv.GetString("idlerank", buff2, sizeof(buff2), g_rankid[data]);
		int start_money = view_as<int>(g_settingsKV.GetNum("start_money", 0)),
			start_bank = view_as<int>(g_settingsKV.GetNum("start_bank", 0));
		
		FormatEx(query, sizeof(query), "INSERT INTO `%splayers_info` (`auth`, `jobid`, `rankid`, `money`, `bank_money`) VALUES ('%s', '%s', '%s', '%d', '%d');", db_prefix, auth, buff, buff2, RP_Money[data] = start_money, RP_Bank[data] = start_bank);

		DB_TQueryEx(query, _, 1);

		DB_LoadClientInfo(data);
	}
}

// save all info client
void DB_SaveClient(int client, DBPriority prio = DBPrio_Normal) {
	if (!client || !IsClientInGame(client)) return;

	char query[512],
		 name[MAX_NAME_LENGTH],
		 position[45],
		 auth[32];

	float pos[3];

	Client_GetName(client, name, sizeof(name));
	EscapeString(g_db, name, name, sizeof(name));

	GetClientAbsOrigin(client, pos);
	FormatEx(position, sizeof(position), "%f %f %f", pos[0], pos[1], pos[2]);
	
	Client_SteamID(client, auth, sizeof(auth));

	FormatEx(query, sizeof(query), "UPDATE `%splayers` SET `id` = %d, `name` = '%s', `position` = '%s' WHERE `auth` = '%s';", db_prefix, RP_ID[client], name, position, auth);

	DB_TQueryEx(query, prio, 2);

	DB_SaveClientInfo(g_db, client, prio);
}

void DB_SaveClientInfo(Database db, int client, DBPriority prio = DBPrio_Normal) {
	char query[512],
		 jobname[MAX_NAME_LENGTH],
		 rankname[MAX_NAME_LENGTH],
		 auth[32];

	GetJobSQL(client, jobname, sizeof(jobname));
	EscapeString(db, jobname, jobname, sizeof(jobname));

	GetRankSQL(client, rankname, sizeof(rankname));
	EscapeString(db, rankname, rankname, sizeof(rankname));
	
	Client_SteamID(client, auth, sizeof(auth));

	FormatEx(query, sizeof(query), "UPDATE `%splayers_info` SET `jobid` = '%s', `rankid` = '%s', `money` = %d, `bank_money` = %d WHERE `auth` = '%s';", db_prefix, jobname, rankname, RP_Money[client], RP_Bank[client], auth);

	DB_TQueryEx(query, prio, 3);
}

// save only money client
void DB_SaveClientMoney(int client, DBPriority prio = DBPrio_Normal) {
	if (!client || !IsClientInGame(client)) return;
	
	char query[512],
		 auth[32];
	
	Client_SteamID(client, auth, sizeof(auth));

	FormatEx(query, sizeof(query), "UPDATE `%splayers_info` SET `money` = %d, `bank_money` = %d WHERE `auth` = '%s';", db_prefix, RP_Money[client], RP_Bank[client], auth);

	DB_TQueryEx(query, prio, 3);
}

// save only job client
void DB_SaveClientJob(Database db, int client, DBPriority prio = DBPrio_Normal) {
	if (!client || !IsClientInGame(client)) return;
	
	char query[512],
		 jobname[MAX_NAME_LENGTH],
		 rankname[MAX_NAME_LENGTH],
		 auth[32];

	GetJobSQL(client, jobname, sizeof(jobname));
	EscapeString(db, jobname, jobname, sizeof(jobname));

	GetRankSQL(client, rankname, sizeof(rankname));
	EscapeString(db, rankname, rankname, sizeof(rankname));
	
	Client_SteamID(client, auth, sizeof(auth));

	FormatEx(query, sizeof(query), "UPDATE `%splayers_info` SET `jobid` = '%s', `rankid` = '%s' WHERE `auth` = '%s';", db_prefix, jobname, rankname, auth);

	DB_TQueryEx(query, prio, 3);
}

stock void DB_TQueryEx(const char[] query, DBPriority prio = DBPrio_Normal, any data = 0) {
	if (g_db == null || !RP_IsStarted()) {
		LogToFile(Logs, "[RP - Warnings] (data %d) DB_TQueryEx: g_db = (%d) or rp %s", data, g_db, RP_IsStarted() ? "started" : "not started");
		return;
	}
	g_db.Query(DB_ErrorCheck, query, data, prio);
}

public void DB_ErrorCheck(Database db, DBResultSet results, const char[] error, any data) {
	if (error[0]) {
		LogToFile(Logs, "[RP - Errors] (data %d) DB_ErrorCheck: %s", data, error);
		LogError("DB_ErrorCheck (data %d): %s", data, error);
	}
}

stock void EscapeString(Database db, const char[] string, char[] buffer, int maxlength, int written = 0) {
	if (db == null) {
		LogToFile(Logs, "[RP - Warnings] EscapeString: g_db = (%d) or rp %s", g_db, RP_IsStarted() ? "started" : "not started");
		return;
	}
	db.Escape(string, buffer, maxlength, written);
}

void RP_Start() {
	if (!RP_IsStarted()) {
		started = true;

		for (int i = 1; i <= MaxClients; i++) {
			if (IsClientInGame(i)) {
				OnClientPutInServer(i);
			}
		}
	}
}

stock bool RP_IsStarted() {
	return started;
}

public bool Client_SteamID(int client, char[] steam, int maxlen) {
	if (IsClientInGame(client)) {
		return view_as<bool>(GetClientAuthId(client, AuthId_Steam2, steam, maxlen));
	}
	return false;
}

public void Client_Teleport(int client, float position[3]) {
	if (IsClientInGame(client) && IsPlayerAlive(client)) {
		TeleportEntity(client, position, NULL_VECTOR, NULL_VECTOR);
	}
}

public bool Client_GetName(int client, char[] name, int maxlen) {
	if (IsClientInGame(client)) {
		return view_as<bool>(GetClientName(client, name, maxlen));
	}
	return false;
}

void GetJobSQL(int client, char[] job, int jobMaxlength)
{
	g_kv.JumpToKey(g_jobid[client]);
	g_kv.GetString("name", job, jobMaxlength, g_jobid[client]);
	g_kv.Rewind();
}

void GetRankSQL(int client, char[] rank, int rankMaxlength)
{
	g_kv.JumpToKey(g_rankid[client]);
	g_kv.GetString("name", rank, rankMaxlength, g_rankid[client]);
	g_kv.Rewind();
}

//////////////
// * JOBS * //
//////////////

public void ResetVariables(int client){
	SetRespawnTimeKV(client);
	SetSalaryMoneyKV(client);
	RP_LastMsg[client] = 0.0;
	
	RP_Hud[client] = true;
	
	// * OnPlayerRunCmd * //
	g_bPressedUse[client] = false;
	g_flPressUse[client] = -1.0;
}

// RP_IsUnemployed - unemployed player or no.
stock bool RP_IsUnemployed(int client){
	g_kv.GetString("idlejob", g_sBuffer, sizeof(g_sBuffer));
	if(StrContains(g_jobid[client], g_sBuffer, false) != -1){
		return true;
	}
	return false;
}

// RP_RemoveJob - set unemployed job for player.
stock void RP_RemoveJob(int client){
	g_kv.GetString("idlejob", g_jobid[client], sizeof(g_jobid[]));
	g_kv.GetString("idlerank", g_rankid[client], sizeof(g_rankid[]));
}   

stock int Client_FindBySteamId(const char[] auth)
{
	char clientAuth[40];
	for (int client = 1; client <= MaxClients; client++){
		if (!IsClientAuthorized(client)){
			continue;
		}
		
		GetClientAuthId(client, AuthId_Steam2, clientAuth, sizeof(clientAuth));

		if (StrEqual(auth, clientAuth)) {
			return client;
		}
	}
	
	return -1;
}

void LoadKVJobs()
{
	g_kv = new KeyValues("jobs");
	char path[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, path, sizeof(path), "data/roleplay/jobs.txt");
	if (!g_kv.ImportFromFile(path))
		SetFailState("Can't read %s", path);
}

void BuildJobsMenu()
{
	if (g_jobsmenu)
		delete g_jobsmenu;

	g_jobsmenu = new Menu(Menu_Jobs);
	g_jobsmenu.SetTitle("Jobs");
	if (g_kv.GotoFirstSubKey()) {
		char id[IDSIZE], name[64];
		do {
			g_kv.GetSectionName(id, sizeof(id));
			g_kv.GetString("name", name, sizeof(name), id);
			g_jobsmenu.AddItem(id, name);
		} while (g_kv.GotoNextKey());
		g_kv.Rewind();
	}
	else SetFailState("File don't contain jobs");
}

void ShowJobTargetMenu(int client)
{
	static Menu menu = null;
	if (menu == null) {
		menu = new Menu(Menu_JobTarget);
		menu.SetTitle("Choose Player");
	}

	menu.RemoveAllItems();
	char userid[12], name[32];
	for (int i = 1; i <= MaxClients; i++)
		if (IsClientInGame(i)) {
			IntToString(GetClientUserId(i), userid, sizeof(userid));
			GetClientName(i, name, sizeof(name));
			menu.AddItem(userid, name);
		}
	if (menu.ItemCount == 0) {
		PrintToChat(client, "No available clients.");
		return;
	}

	menu.Display(client, MENU_TIME_FOREVER);
}

public int Menu_JobTarget(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action) {
		case MenuAction_Select: {
			char userid[12];
			menu.GetItem(param2, userid, sizeof(userid));
			g_jobTarget[param1] = StringToInt(userid);
			g_jobsmenu.Display(param1, MENU_TIME_FOREVER);
		}
	}
}

public int Menu_Jobs(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action) {
		case MenuAction_Select: {
			char id[IDSIZE];
			menu.GetItem(param2, id, sizeof(id));
			ShowRanksMenu(param1, id);
		}
	}
}

void ShowRanksMenu(int client, const char[] id_)
{
	static Menu menu = null;
	if (menu == null) {
		menu = new Menu(Menu_Ranks);
		menu.SetTitle("Ranks");
	}

	menu.RemoveAllItems();
	menu.AddItem(id_, "", ITEMDRAW_RAWLINE);
	g_kv.JumpToKey(id_);
	if (g_kv.GotoFirstSubKey()) {
		char id[IDSIZE], name[64];
		do {
			g_kv.GetSectionName(id, sizeof(id));
			g_kv.GetString("name", name, sizeof(name), id);
			menu.AddItem(id, name);
		} while (g_kv.GotoNextKey());
		g_kv.Rewind();
	}
	else {
		g_kv.Rewind();
		ThrowError("Job \"%s\" don't contain ranks", id_);
	}

	menu.Display(client, MENU_TIME_FOREVER);
}

public int Menu_Ranks(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action) {
		case MenuAction_Select: {
			int client = GetClientOfUserId(g_jobTarget[param1]);		// target
			if (client == 0) {
				PrintToChat(param1, "Client (userid: %i) is no longer available.", client);
				return;
			}
			char job[IDSIZE], id[IDSIZE];
			menu.GetItem(0, job, sizeof(job));
			menu.GetItem(param2, id, sizeof(id));
			PrintToChat(param1, "Your choose: job %s, rank %s", job, id);
			
			SetClientJob(client, job, id);
			
			char JobName[64], RankName[64];
			GetName(client, JobName, sizeof(JobName), RankName, sizeof(RankName));
			PrintToChat(client, "Admin change your job. New job %s, rank %s", JobName, RankName);
		}
	}
}

void SetClientJob(int client, const char[] job, const char[] rank)
{
	strcopy(g_jobid[client], sizeof(g_jobid[]), job);
	strcopy(g_rankid[client], sizeof(g_rankid[]), rank);
	
	SetJobKV(client);			// set kv variables
	DB_SaveClientInfo(g_db, client);		// save player_info		[job,rank,money,bank]
}

void GetName(int client, char[] job, int jobMaxlength, char[] rank, int rankMaxlength)
{
	g_kv.JumpToKey(g_jobid[client]);
	g_kv.GetString("name", job, jobMaxlength, g_jobid[client]);
	g_kv.JumpToKey(g_rankid[client]);
	g_kv.GetString("name", rank, rankMaxlength, g_rankid[client]);
	g_kv.Rewind();
}

//////////////////
// * SETTINGS * //
//////////////////

void LoadKVSettings(){
	g_settingsKV = new KeyValues("Settings");
	char path[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, path, sizeof(path), "data/roleplay/settings.txt");
	if (!g_settingsKV.ImportFromFile(path))
		SetFailState("Can't read %s", path);
	
	if (g_settingsKV.GotoFirstSubKey()){
		do 
		{
			GetStringATM();
			GetStringMONEY();
			GetFloatChatDistance();
			GetNumFog();
			GetSalaryTimer();
			PrecacheModels();
		} while (g_settingsKV.GotoNextKey());
	}
}

///////////////
// * OTHER * //
///////////////

public Action ForbiddenCommands(int client, const char[] command, int args){
	return Plugin_Handled;
}

public Action Chat_Say(int client, const char[] command, int args){
	if (!IsPlayerAlive(client)){
		PrintToChat(client, "Мертвые не разговаривают");
		return Plugin_Handled;
	}
	
	char text[256];

	GetCmdArgString(text, sizeof(text));
	StripQuotes(text); TrimString(text);

	if (StrEqual(text, " ")
	||	StrEqual(text, "")
	||	strlen(text) == 0) {
		return Plugin_Handled;
	}
	else if (StrContains(text, "@") == 0
	||		 StrContains(text, "/") == 0){
		return Plugin_Continue;
	}
	if (strcmp(command, "say") == 0){
		if ((GetEngineTime() - RP_LastMsg[client]) < 3.00){
			return Plugin_Handled;
		}
		
		RP_LastMsg[client] = GetEngineTime();
		CPrintToChatAllEx(client, "(\x01GLOBAL) \x03%N: \x01%s", client, text);
		
		return Plugin_Handled;
	}
	
	else if (strcmp(command, "say_team") == 0){
		for (int i = 1; i <= MaxClients; i++){
			GetFloatChatDistance();
			if (Entity_Distance(client, i) <= fChatDistance){
				if ((GetEngineTime() - RP_LastMsg[client]) < 0.75){
					return Plugin_Handled;
				}
				
				RP_LastMsg[client] = GetEngineTime();
				CPrintToChatEx(i, client, "(\x01LOCAL) \x03%N: \x01%s", client, text);
			}
			return Plugin_Handled;
		}
	}
	
	return Plugin_Continue;
}

stock bool RemoveWeapon(int client){
	if (IsClientInGame(client) && IsPlayerAlive(client)){
		int entity = CreateEntityByName("player_weaponstrip");
		if (AcceptEntityInput(entity, "strip", client) && AcceptEntityInput(entity, "kill")){
			return true;
		}
		return false;
	}
	return false;
}

stock float Entity_Distance(int ent1, int ent2) {
	float orig1[3], orig2[3];
	
	GetEntPropVector(ent1, Prop_Send, "m_vecOrigin", orig1);
	GetEntPropVector(ent2, Prop_Send, "m_vecOrigin", orig2);
	
	return GetVectorDistance(orig1, orig2);
}

stock bool Drop_Money(int client, int amount){
	int ent;
	if((ent = CreateEntityByName("prop_physics")) != -1){
		float origin[3];
		GetClientEyePosition(client, origin);
		
		TeleportEntity(ent, origin, NULL_VECTOR, NULL_VECTOR);
		
		char TargetName[32];
		Format(TargetName, sizeof(TargetName), "%i", amount);
		
		GetStringMONEY();
		DispatchKeyValue(ent, "model", money_model);
		DispatchKeyValue(ent, "physicsmode", "2");
		DispatchKeyValue(ent, "massScale", "8.0");
		DispatchKeyValue(ent, "targetname", TargetName);
		DispatchSpawn(ent);
		
		SetEntityMoveType(ent, MOVETYPE_VPHYSICS);
		
		SetEntProp(ent, Prop_Send, "m_usSolidFlags", 8);
		SetEntProp(ent, Prop_Send, "m_CollisionGroup", 11);
		return true;
	}
	return false;
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast){
	if (iFog){
		int ent;
		if ((ent = FindEntityByClassname(-1, "env_fog_controller")) != -1) {
			AcceptEntityInput(ent, "TurnOff");
		}
	}
}

public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast){
	int client = GetClientOfUserId(event.GetInt("userid"));
	RemoveWeapon(client);				// Disarm Player
	SetTeamKV(client);					// Set the player team
	SetEntityArmorKV(client);			// Set player armor
	SetEntityHealthKV(client);			// Set player health
	GiveWeaponKV(client);				// Give the player weapons
	SetModelKV(client);					// Set the player model
	SetSalaryMoneyKV(client);			// if reset salary
	ScreenFade(client);					// Fade creen if player spawn
}

public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast) {
	int client = GetClientOfUserId(event.GetInt("userid"));
	SetRespawnTimeKV(client);			// Set respawn time
	ScreenFade(client, FFADE_OUT, DEATH_COLOR, 4, RoundToFloor(RP_RespawnTime[client] - 0.5));				// Fade screen if player dead
	
	int iDropMoney = view_as<bool>(g_settingsKV.GetNum("dropmoney", 1));
	if (iDropMoney){						// Enable/Disable dropmoney
		if (RP_Money[client] != 0){			// If a player is dead then dropmoney
			int iMinDrop = view_as<int>(g_settingsKV.GetNum("min_dropmoney", 1)),
				iMaxDrop = view_as<int>(g_settingsKV.GetNum("max_dropmoney", 500));
			
			int random = GetRandomInt(iMinDrop, iMaxDrop),			// amount
				dropmoney = 0;
			
			if (RP_Money[client] - random < 1){
				PrintToChat(client, "You lost all the money");
				dropmoney = RP_Money[client];
				RP_Money[client] = 0;
			} else {
				PrintToChat(client, "You lost $%i", random);
				RP_Money[client] -= random;
				dropmoney = random;
			}
			Drop_Money(client, dropmoney);
		}
	}
}

void RegCvars(){
	Database_prefix = CreateConVar("sm_rp_dbprefix", db_prefix, "Prefix database");
	Database_prefix.GetString(db_prefix, sizeof(db_prefix));
	Database_prefix.AddChangeHook(CvarChange);
}

public Action Cmd_ReloadJobs(int client, int args)
{
	delete g_kv;
	LoadKVJobs();
	BuildJobsMenu();

	return Plugin_Handled;
}

public Action Cmd_Jobs(int client, int args)
{
	if (client)
		ShowJobTargetMenu(client);

	return Plugin_Handled;
}

public Action sm_unemployed(int client, int args){
	if (client && IsClientInGame(client)){
		if (args != 1){
			ReplyToCommand(client, "Usage: sm_unemployed <steamid>");
			return Plugin_Handled;
		}
		
		char arg[64];
		GetCmdArg(1, arg, sizeof(arg));
		int target = Client_FindBySteamId(arg);
		
		if (target != -1 && IsClientInGame(target)){
			if (!RP_IsUnemployed(target)){
				RP_RemoveJob(target);
				PrintToChat(target, "ADMIN: Вы теперь безработный");
				PrintToChat(client, "%N теперь безработный", target);
			} else PrintToChat(client, "%N уже безработный", target);
		} else PrintToChat(client, "%N не в игре", target);
	}
	return Plugin_Handled;
}

public Action sm_ReloadSettings(int client, int args){
	delete g_settingsKV;
	LoadKVSettings();
	return Plugin_Handled;
}

public Action sm_dropmoney(int client, int args){
	if (client && IsClientInGame(client) && IsPlayerAlive(client)){
		if (args != 1){
			ReplyToCommand(client, "Usage: sm_dropmoney <amount>");
			return Plugin_Handled;
		}

		char arg[64];
		GetCmdArg(1, arg, sizeof(arg));
		int amount = StringToInt(arg);
			//getmoney = GetClientMoney(client),
			//setmoney = SetClientMoney(client, getmoney);
		
		if (RP_Money[client] > 0){
			if (amount > 0){
				//if (amount > getmoney) amount = getmoney;
				//setmoney -= amount;
				if (amount > RP_Money[client]) amount = RP_Money[client];
				RP_Money[client] -= amount;
				Drop_Money(client, amount);
				PrintHintText(client, "Drop $%i", amount);
			}
			//else if (amount < 1 || amount > getmoney) PrintHintText(client, "Некорректная сумма, на счету $%d", getmoney);
			else if (amount < 1 || amount > RP_Money[client]) PrintHintText(client, "Некорректная сумма, на счету $%d", RP_Money[client]);
			
		} else PrintHintText(client, "У вас нет такой суммы!");
	}
	return Plugin_Handled;
}

public Action sm_givemoney(int client, int args){
	if (client && IsClientInGame(client)){
		if (args != 2){
			ReplyToCommand(client, "Usage: sm_givemoney <steamid> <amount>"); 
			return Plugin_Handled;
		}
		char arg1[64], arg2[64];
		
		GetCmdArg(1, arg1, sizeof(arg1));
		GetCmdArg(2, arg2, sizeof(arg2));
		
		int target = Client_FindBySteamId(arg1),
			amount = StringToInt(arg2);
			
		if (target != -1 && IsClientInGame(client)){
			if (amount > 0){
				RP_Money[target] += amount;
				PrintToChat(target, "Admin give your $%i", amount);
				//DB_SaveClient(target);				// save DB target
				DB_SaveClientMoney(target);
			}
			else if (amount < 1 || !amount) PrintHintText(client, "Incorrect amount");
		}
	}
	return Plugin_Handled;
}

public Action sm_setmoney(int client, int args){
	if (client && IsClientInGame(client)){
		if (args != 2){
			ReplyToCommand(client, "Usage: sm_setmoney <steamid> <amount>"); 
			return Plugin_Handled;
		}
		char arg1[64], arg2[64];
		
		GetCmdArg(1, arg1, sizeof(arg1));
		GetCmdArg(2, arg2, sizeof(arg2));
		
		int target = Client_FindBySteamId(arg1),
			amount = StringToInt(arg2);
			
		if (target != -1 && IsClientInGame(client)){
			if (amount > 0){
				RP_Money[target] = amount;
				PrintToChat(target, "Admin set your $%i", amount);
				//DB_SaveClient(target);				// save DB target
				DB_SaveClientMoney(target);
			}
			else if (amount < 1 || !amount) PrintHintText(client, "Incorrect amount");
		}
	}
	return Plugin_Handled;
}

public Action sm_givebank(int client, int args){
	if (client && IsClientInGame(client)){
		if (args != 2){
			ReplyToCommand(client, "Usage: sm_givebank <steamid> <amount>"); 
			return Plugin_Handled;
		}
		
		char arg1[64], arg2[64];
		
		GetCmdArg(1, arg1, sizeof(arg1));
		GetCmdArg(2, arg2, sizeof(arg2));
		
		int target = Client_FindBySteamId(arg1),
			amount = StringToInt(arg2);
			
		if (target != -1 && IsClientInGame(client)){
			if (amount > 0){
				RP_Bank[target] += amount;
				PrintToChat(target, "Admin give your in bank $%i", amount);
				//DB_SaveClient(target);				// save DB target
				DB_SaveClientMoney(target);
			}
			else if (amount < 1 || !amount) PrintHintText(client, "Incorrect amount");
		}
	}
	return Plugin_Handled;
}

public Action sm_setbank(int client, int args){
	if (client && IsClientInGame(client)){
		if (args != 2){
			ReplyToCommand(client, "Usage: sm_setbank <steamid> <amount>"); 
			return Plugin_Handled;
		}
		
		char arg1[64], arg2[64];
		
		GetCmdArg(1, arg1, sizeof(arg1));
		GetCmdArg(2, arg2, sizeof(arg2));
		
		int target = Client_FindBySteamId(arg1),
			amount = StringToInt(arg2);
			
		if (target != -1 && IsClientInGame(client)){
			if (amount > 0){
				RP_Bank[target] = amount;
				PrintToChat(target, "Admin set your in bank $%i", amount);
				//DB_SaveClient(target);				// save DB target
				DB_SaveClientMoney(target);
			}
			else if (amount < 1 || !amount) PrintHintText(client, "Incorrect amount");
		}
	}
	return Plugin_Handled;
}

public Action sm_dbsave(int client, int args){
	for (int player = 1; player <= MaxClients; player++){
		if (IsClientInGame(player)){
			DB_SaveClient(player);
			PrintToChat(client, "DB save!");
		}
	}
	return Plugin_Handled;
}

public Action sm_dbsavemoney(int client, int args){
	for (int player = 1; player <= MaxClients; player++){
		if (IsClientInGame(player)){
			DB_SaveClientMoney(player);
			PrintToChat(client, "DB save money!");
		}
	}
	return Plugin_Handled;
}

public Action sm_dbsavejobs(int client, int args){
	for (int player = 1; player <= MaxClients; player++){
		if (IsClientInGame(player)){
			DB_SaveClientJob(g_db, player);
			PrintToChat(client, "DB save jobs!");
		}
	}
	return Plugin_Handled;
}

public Action sm_hud(int client, int args){
	if (client && IsClientInGame(client)){
		RP_Hud[client] = true;
	}
	return Plugin_Handled;
}

public Action sm_userlist(int client, int args){
	if (client && IsClientInGame(client)){
		RP_Userlist(client);
	}
	return Plugin_Handled;
}

void RP_Userlist(int client){
	Menu menu = new Menu(select_joblist); 
	menu.SetTitle("[RP] User list");

	AddTargToMenu(menu);

	menu.Display(client, MENU_TIME_FOREVER);
}

void AddTargToMenu(Menu menu) {
	char userid[12], name[32];

	for (int i = 1; i <= MaxClients; i++){
		if (IsClientInGame(i)) {
			IntToString(GetClientUserId(i), userid, sizeof(userid));
			GetClientName(i, name, sizeof(name));

			menu.AddItem(userid, name);
		}
	}
}

public int select_joblist(Menu menu, MenuAction action, int client, int option) {
    switch (action){
        case MenuAction_End: delete menu;
        case MenuAction_Select: {
			char userid[12];
			menu.GetItem(option, userid, sizeof(userid));
			int target = StringToInt(userid);
			if ((target = GetClientOfUserId(target)) == 0){
				PrintToChat(client, "Client (userid: %i) is no longer available.", target);
				return;
			}
			
			char JobName[64], RankName[64], auth[32];
			GetName(client, JobName, sizeof(JobName), RankName, sizeof(RankName));
			GetClientAuthId(client, AuthId_Steam2, auth, sizeof(auth));
			
			PrintToChat(client, "Name: %N", target);
			PrintToChat(client, "SteamID: %s", auth);
			PrintToChat(client, "Job: %s", JobName);
			PrintToChat(client, "Post: %s", RankName);
			PrintToChat(client, "Cash: %i", RP_Money[target]);
			PrintToChat(client, "Bank: %i", RP_Bank[target]);
			PrintToChat(client, "Salary: %i", RP_Salary[target]);			// experimental
        }
    }
}

public Action sm_adminmenu(int client, int args){
	if (client && IsClientInGame(client)){
		RP_AdminMenu(client);
	}
	return Plugin_Handled;
}

void RP_AdminMenu(int client){
	Menu menu = new Menu(select_adminmenu);
	menu.SetTitle("[RP] Admin Menu");
	
	menu.AddItem("jobs", "Jobs menu");
	menu.AddItem("db_menu", "Database menu");
	menu.AddItem("userlist", "User list");
	menu.AddItem("configs", "Reload configs");
	
	menu.Display(client, MENU_TIME_FOREVER);
}

public int select_adminmenu(Menu menu, MenuAction action, int client, int option) {
    switch (action){
        case MenuAction_End: delete menu;
        case MenuAction_Select: {
        	switch (option){
        		case 0: FakeClientCommand(client, "sm_jobs");
        		case 1: RP_dbmenu(client);
        		case 2: FakeClientCommand(client, "sm_userlist");
        		case 3: RP_configsmenu(client);
        	}
        }
    }
}

void RP_dbmenu(int client){
    Menu menu = new Menu(select_dbmenu);
    menu.SetTitle("[RP] Database Menu");
   
    menu.AddItem("force", "Force DB save");
    menu.AddItem("savemoney", "Save money");
    menu.AddItem("savejobs", "Save jobs");
   
    menu.Display(client, MENU_TIME_FOREVER);
}

public int select_dbmenu(Menu menu, MenuAction action, int client, int option) {
    switch (action){
        case MenuAction_End: delete menu;
        case MenuAction_Select: {
        	switch (option){
				case 0: FakeClientCommand(client, "sm_dbsave");
				case 1: FakeClientCommand(client, "sm_dbsavemoney");
				case 2: FakeClientCommand(client, "sm_dbsavejobs");
        	}
        }
    }
}

void RP_configsmenu(int client){
    Menu menu = new Menu(select_configs);
    menu.SetTitle("[RP] Configs menu");
   
    menu.AddItem("rjobs", "Reload jobs.txt");
    menu.AddItem("rsettings", "Reload settings.txt");
   
    menu.Display(client, MENU_TIME_FOREVER);
}

public int select_configs(Menu menu, MenuAction action, int client, int option) {
    switch (action){
        case MenuAction_End: delete menu;
        case MenuAction_Select: {
        	switch (option){
				case 0: FakeClientCommand(client, "sm_reloadjobs");
				case 1: FakeClientCommand(client, "sm_reloadsettings");
        	}
        }
    }
}
		
//////////////////////
// * GLOBAL TIMER * //
//////////////////////

public Action OnEverySecond(Handle timer) {
	if (RP_IsStarted()) {
		for (int i = 1; i <= MaxClients; i++) {
			if (IsValidPlayer(i) && GetClientTeam(i) > 1) {
				if (!IsPlayerAlive(i)) {
					RespawnClient(i);
				}
				else if (RP_Hud[i] != false) ShowPanel(i);				// hud menu
				Timer_Salary(i);
				GetInfoEntity(i);			// Print Hint player id
			}
		}
	}
}

stock bool RespawnClient(int client){
	if (RP_RespawnTime[client] > 0){
		RP_RespawnTime[client]--;
		PrintHintText(client, "<font color='#ff0000'>Wasted</font> \nRespawn: %d", RP_RespawnTime[client]);
	}
	else if (RP_RespawnTime[client] == 0){
		RP_RespawnTime[client] = -1;
		if (IsValidPlayer(client) && !IsPlayerAlive(client)) CS_RespawnPlayer(client);
	}
}

stock bool Timer_Salary(int client){
	if (iSalaryEnd > 0) {
		iSalaryEnd--;
	}
	else if (iSalaryEnd == 0) {
		GetSalaryMoneyKV(client);
		DB_SaveClientMoney(client);			// DB save money
		PrintToChat(client, "You got salary");
		GetSalaryTimer();
		iSalaryEnd = iSalaryTimer;
	}
}

stock bool IsValidPlayer(int client){
	if (0 < client <= MaxClients && IsClientInGame(client))
	{
		return true;
	}
	else return false;
}

//////////////////////////
// * JOBS - KEYVALUES * //
//////////////////////////

void SetModelKV(int client){
	if (client && IsClientInGame(client)){
		char branch_model[64];
		FormatEx(branch_model, sizeof(branch_model), "%s/%s/model", g_jobid[client], g_rankid[client]);
		g_kv.GetString(branch_model, model, sizeof(model));
		if (!IsModelPrecached(model)) PrecacheModel(model, true);
		if (model[0] != '\0') 
			SetEntityModel(client, model);
	}
}
	
void SetTeamKV(int client){
	if (client && IsClientInGame(client)){
		char branch_team[64]; int team;
		FormatEx(branch_team, sizeof(branch_team), "%s/%s/team", g_jobid[client], g_rankid[client]);
		team = g_kv.GetNum(branch_team);
		if (team != 0){
			if (GetClientTeam(client) != team){
				CS_SwitchTeam(client, team);
			}
		}
	}
}

void SetRespawnTimeKV(int client){
	char sRespawn[64]; int tRespawn;
	FormatEx(sRespawn, sizeof(sRespawn), "%s/%s/respawn_time", g_jobid[client], g_rankid[client]);
	tRespawn = g_kv.GetNum(sRespawn);
	RP_RespawnTime[client] = tRespawn;
}

void SetSalaryMoneyKV(int client){
	char sSalary[64]; int tSalary;
	FormatEx(sSalary, sizeof(sSalary), "%s/%s/salary", g_jobid[client], g_rankid[client]);
	tSalary = g_kv.GetNum(sSalary);
	RP_Salary[client] = tSalary;
}

void GetSalaryMoneyKV(int client){
	char sSalary[64]; int tSalary;
	FormatEx(sSalary, sizeof(sSalary), "%s/%s/salary", g_jobid[client], g_rankid[client]);
	tSalary = g_kv.GetNum(sSalary);
	RP_Money[client] += tSalary;
}

void SetEntityHealthKV(int client){
	char sHealth[64]; int health;
	FormatEx(sHealth, sizeof(sHealth), "%s/%s/health", g_jobid[client], g_rankid[client]);
	health = g_kv.GetNum(sHealth);
	if (health != 0){
		SetEntityHealth(client, health);
	} else SetEntityHealth(client, 100);
}

void SetEntityArmorKV(int client){
	char sArmor[64]; int armor;
	FormatEx(sArmor, sizeof(sArmor), "%s/%s/armor", g_jobid[client], g_rankid[client]);
	armor = g_kv.GetNum(sArmor);
	if (armor != 0){
		SetEntProp(client, Prop_Send, "m_ArmorValue", armor);
	} else SetEntProp(client, Prop_Send, "m_ArmorValue", 0);
}

// Thanks Kailo
void GiveWeaponKV(int client){
    if (client && IsClientInGame(client)){
        g_kv.JumpToKey(g_jobid[client]);
        g_kv.JumpToKey(g_rankid[client]);
        if (g_kv.JumpToKey("tools") && g_kv.GotoFirstSubKey(false)) {
            char tool[32];
            do {
                g_kv.GetString(NULL_STRING, tool, sizeof(tool));
                GivePlayerItem(client, tool);
            } while (g_kv.GotoNextKey(false));
        }
        g_kv.Rewind();
    }
}

//////////////////////////////
// * SETTINGS - KEYVALUES * //
//////////////////////////////

void GetStringMONEY(){
	g_settingsKV.GetString("money_model", money_model, sizeof(money_model));
}

void GetStringATM(){
	g_settingsKV.GetString("atm_model", atm_model, sizeof(atm_model));
}

void GetFloatChatDistance(){
	fChatDistance = view_as<float>(g_settingsKV.GetFloat("localchat_distance", 500.0));
}

void GetNumFog(){
	iFog = view_as<bool>(g_settingsKV.GetNum("turn_fog", 0));
}

void GetSalaryTimer(){
	iSalaryTimer = view_as<int>(g_settingsKV.GetNum("salary_timer", 500));
}

stock void PrecacheModels(){
	g_settingsKV.GetString("money_model", money_model, sizeof(money_model));
	if (!IsModelPrecached(money_model)) PrecacheModel(money_model, true);
	
	g_settingsKV.GetString("atm_model", atm_model, sizeof(atm_model));
	if (!IsModelPrecached(atm_model)) PrecacheModel(atm_model, true);
}

////////////////////////
// * OnPlayerRunCmd * //
////////////////////////

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3]){
    if (!IsClientInGame(client))return Plugin_Handled;
   
    if (IsPlayerAlive(client)){
       
        // kossolax thanks for this
        if( buttons & IN_USE && g_bPressedUse[client] == false ) {
            g_bPressedUse[client] = true;
            g_flPressUse[client] = GetGameTime();
        }
        else if (!(buttons & IN_USE) && g_bPressedUse[client] == true) {
            g_bPressedUse[client] = false;
            if ((GetGameTime() - g_flPressUse[client]) < 0.2){
                int ent = AimTargetProp(client);
               
                if (ent != -1 && IsValidEntity(ent)){
                    char modelname[128];
                    GetEntPropString(ent, Prop_Data, "m_ModelName", modelname, sizeof(modelname));
                    
                    GetStringATM();				// atm_model
                    GetStringMONEY();			// money_model
                    if (strcmp(modelname, atm_model) == 0) {
 
						float origin[3];
						GetEntPropVector(ent, Prop_Send, "m_vecOrigin", g_fATMorigin[client]);
						GetClientAbsOrigin(client, origin);
						float distance = GetVectorDistance(origin, g_fATMorigin[client]);
						if (distance < MIN_DISTANCE_USE) RP_BankMenu(client);			// Open bank menu
					}
					
					else if (strcmp(modelname, money_model) == 0) {
						float origin[3], clientent[3];
						GetEntPropVector(ent, Prop_Send, "m_vecOrigin", origin);
						GetClientAbsOrigin(client, clientent);
						float distance = GetVectorDistance(origin, clientent);
						if (distance < MIN_DISTANCE_USE){
							char amount[32];
							GetTargetName(ent, amount, sizeof(amount));
							
							if (0 < StringToInt(amount)){
								RemoveEdict(ent);
								RP_Money[client] += StringToInt(amount);
								PrintToChat(client, "You pick up $%i", StringToInt(amount));
							}
						}
					}
                }
            }
        }
    }
    return Plugin_Continue;
}

//////////////////
// * ATM Menu * //
//////////////////
 
void RP_BankMenu(int client) {
    Menu menu = new Menu(Select_bankmenu);
    char buffer[32];
    FormatEx(buffer, sizeof(buffer), "ATM [Bank: %i / Cash: %i]", RP_Bank[client], RP_Money[client]);
    menu.SetTitle(buffer);
   
    menu.AddItem("deposit", "Deposit");
    menu.AddItem("withdraw", "Withdraw");
   
    menu.Display(client, MENU_TIME_FOREVER);
}
 
public int Select_bankmenu(Menu menu, MenuAction action, int client, int option) {
    switch (action){
        case MenuAction_End: delete menu;
        case MenuAction_Select: {
            float clientent[3];
            GetClientAbsOrigin(client, clientent);
            float distance = GetVectorDistance(g_fATMorigin[client], clientent);
            if (distance > MIN_DISTANCE_USE) {
                PrintToChat(client, "You have departed from the ATM");
                return;
            }
            
            char buffer[32];
            GetMenuItem(menu, option, buffer, sizeof(buffer));
            switch (option) {
                case 0: RP_DepositAmount(client);
                case 1: RP_WithdrawAmount(client);
            }
        }
    }
}

void RP_DepositAmount(int client){
    Menu menu = new Menu(Select_depositamount);
    menu.SetTitle("Deposit amount");
   
    menu.AddItem("all", "All");
    if (RP_Money[client] >= 10) menu.AddItem("10", "$10");
    if (RP_Money[client] >= 50) menu.AddItem("50", "$50");
    if (RP_Money[client] >= 100) menu.AddItem("100", "$100");
    if (RP_Money[client] >= 200) menu.AddItem("200", "$200");
    if (RP_Money[client] >= 500) menu.AddItem("500", "$500");
    if (RP_Money[client] >= 1000) menu.AddItem("1000", "$1000");
    if (RP_Money[client] >= 2000) menu.AddItem("2000", "$2000");
    if (RP_Money[client] >= 5000) menu.AddItem("5000", "$5000");
    if (RP_Money[client] >= 10000) menu.AddItem("10000", "$10000");
   
    menu.Display(client, MENU_TIME_FOREVER);
}

void RP_WithdrawAmount(int client){
    Menu menu = new Menu(Select_withdrawtamount);
    menu.SetTitle("Withdraw amount");
   
    menu.AddItem("all", "All");
    if (RP_Bank[client] >= 10) menu.AddItem("10", "$10");
    if (RP_Bank[client] >= 50) menu.AddItem("50", "$50");
    if (RP_Bank[client] >= 100) menu.AddItem("100", "$100");
    if (RP_Bank[client] >= 200) menu.AddItem("200", "$200");
    if (RP_Bank[client] >= 500) menu.AddItem("500", "$500");
    if (RP_Bank[client] >= 1000) menu.AddItem("1000", "$1000");
    if (RP_Bank[client] >= 2000) menu.AddItem("2000", "$2000");
    if (RP_Bank[client] >= 5000) menu.AddItem("5000", "$5000");
    if (RP_Bank[client] >= 10000) menu.AddItem("10000", "$10000");
   
    menu.Display(client, MENU_TIME_FOREVER);
}

public int Select_depositamount(Menu menu, MenuAction action, int client, int option) {
    switch (action){
        case MenuAction_End: delete menu;
        case MenuAction_Select: {
            float clientent[3];
            GetClientAbsOrigin(client, clientent);
            float distance = GetVectorDistance(g_fATMorigin[client], clientent);
            if (distance > MIN_DISTANCE_USE) {
                PrintToChat(client, "You have departed from the ATM");
                return;
            }
            
            else if (RP_Money[client] < 1){
            	PrintToChat(client, "You don't have money");
            	return;
            }
            
            char buffer[32];
            GetMenuItem(menu, option, buffer, sizeof(buffer));
            int amount = StringToInt(buffer);
            if (strcmp(buffer, "all") == 0){
				RP_Bank[client] = RP_Money[client] + RP_Bank[client];
				RP_Money[client] = 0;
				PrintToChat(client, "You deposit all money");
			}
			
			else if (RP_Money[client] >= amount){
				RP_Bank[client] += amount;
				RP_Money[client] -= amount;
				PrintToChat(client, "You deposit $%i money", amount);
			}
        }
    }
}

public int Select_withdrawtamount(Menu menu, MenuAction action, int client, int option) {
    switch (action){
        case MenuAction_End: delete menu;
        case MenuAction_Select: {
            float clientent[3];
            GetClientAbsOrigin(client, clientent);
            float distance = GetVectorDistance(g_fATMorigin[client], clientent);
            if (distance > MIN_DISTANCE_USE) {
                PrintToChat(client, "You have departed from the ATM");
                return;
            }
            
            else if (RP_Bank[client] < 1){
            	PrintToChat(client, "You don't have money");
            	return;
            }
            
            char buffer[32];
            GetMenuItem(menu, option, buffer, sizeof(buffer));
            int amount = StringToInt(buffer);
            if (strcmp(buffer, "all") == 0){
				RP_Money[client] = RP_Bank[client] + RP_Money[client];
				RP_Bank[client] = 0;
				PrintToChat(client, "You withdraw all money");
			}
			
			else if (RP_Bank[client] >= amount){
				RP_Bank[client] -= amount;
				RP_Money[client] += amount;
				PrintToChat(client, "You withdraw $%i money", amount);
			}
        }
    }
}

// Thanks exle
stock int AimTargetProp(int client) {
    float m_vecOrigin[3],
          m_angRotation[3];
 
    GetClientEyePosition(client, m_vecOrigin);
    GetClientEyeAngles(client, m_angRotation);
 
    Handle tr = TR_TraceRayFilterEx(m_vecOrigin, m_angRotation, MASK_VISIBLE, RayType_Infinite, TRDontHitSelf, client);
    if (TR_DidHit(tr)) {
        int pEntity = TR_GetEntityIndex(tr);
        if (MaxClients < pEntity) {
            delete tr;
            return pEntity;
        }
    }
 
    delete tr;
    return -1;
}
 
public bool TRDontHitSelf(int entity, int mask, any data) {
    return !(entity == data);
}

public bool TRDontHitTarget(int entity, int mask, any data)
{
	if (entity == data) return false;
	return true;
}

stock int AimTargetPlayer(int client) {
	float m_vecOrigin[3],
		m_angRotation[3];

	GetClientEyePosition(client, m_vecOrigin);
	GetClientEyeAngles(client, m_angRotation);

	Handle tr = TR_TraceRayFilterEx(m_vecOrigin, m_angRotation, MASK_VISIBLE, RayType_Infinite, TRDontHitTarget, client);
	if (TR_DidHit(tr)) {
		int pEntity = TR_GetEntityIndex(tr);
		if (0 < pEntity < MaxClients)
		{
			delete tr;
			return pEntity;
		}
	}

	delete tr;
	return -1;
}

stock void GetTargetName(int entity, char[] buf, int len){
	GetEntPropString(entity, Prop_Data, "m_iName", buf, len);
}

//////////////////
// * Hud menu * //
//////////////////

stock void ShowPanel(int client) {
	char text[100];

	Panel panel = new Panel();
	Format(text, sizeof(text), "[RP] HUD");
	panel.SetTitle(text);

	panel.DrawItem("\n ", ITEMDRAW_RAWLINE);

	Format(text, sizeof(text), "Cash: %d", RP_Money[client]);
	panel.DrawText(text);
	
	Format(text, sizeof(text), "Bank: %d", RP_Bank[client]);
	panel.DrawText(text);
	
	char JobName[64], RankName[64];
	GetName(client, JobName, sizeof(JobName), RankName, sizeof(RankName));
	
	Format(text, sizeof(text), "Job: %s", JobName);
	panel.DrawText(text);
	
	Format(text, sizeof(text), "Post: %s", RankName);
	panel.DrawText(text);
	
	Format(text, sizeof(text), "Salary: %d", RP_Salary[client]);
	panel.DrawText(text);
	
	GetSalaryTimer();
	Format(text, sizeof(text), "Salary timer: %d", iSalaryEnd);
	panel.DrawText(text);

	panel.CurrentKey = 9;
	panel.DrawItem("Close");

	panel.Send(client, inf, 30);
	delete panel;
}
public int inf(Menu panel, MenuAction action, int param1, int param2) {
	switch (action)
	{
		case MenuAction_End: panel.Close();
		case MenuAction_Select: {
			RP_Hud[param1] = false;
			PrintToChat(param1, "\x01Open \x03!hud \x01menu");
			PrintToChat(param1, "\x01Open \x03!hud \x01menu");
			PrintToChat(param1, "\x01Open \x03!hud \x01menu");
		}
	}
}

public Action CS_OnTerminateRound(float &delay, CSRoundEndReason &reason){
	switch (reason){
		case CSRoundEnd_CTWin, CSRoundEnd_TerroristWin, CSRoundEnd_Draw, CSRoundEnd_HostagesRescued, 
		CSRoundEnd_TargetBombed, CSRoundEnd_BombDefused: return Plugin_Handled;
	}
	return Plugin_Continue;
}

public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	if (!attacker || !victim || attacker == victim || attacker >= MaxClients || victim >= MaxClients || damagetype & DMG_FALL) return Plugin_Continue;

	if (!IsValidPlayer(attacker) || !IsValidPlayer(victim)) return Plugin_Continue;

	char weapon[32];
	GetClientWeapon(attacker, weapon, sizeof(weapon));

	if (StrContains(weapon, "knife") != -1)
	{
		//ArrayJob job = new ArrayJob(file_job);

		//bool arresta = view_as<bool>(job.GetById(ParamData_Int, "arrest", attacker.JobId,	attacker.PostId)	== -1 ? job.GetById(ParamData_Int, "arrest", attacker.JobId)	: job.GetById(ParamData_Int, "arrest", attacker.JobId,	attacker.PostId)),
		//	 arrestv = view_as<bool>(job.GetById(ParamData_Int, "arrest", victim.JobId,		victim.PostId)		== -1 ? job.GetById(ParamData_Int, "arrest", victim.JobId)		: job.GetById(ParamData_Int, "arrest", victim.JobId,	victim.PostId));

		//delete job;

		//if (arresta
		//&&  !arrestv)
		//{
			//PrintToChatAll("\x01\x0B \x04%s\x01 Был арестован и посажен в тюрьму: %N", PREFIX, victim.Index);
		//}
		switch (GetClientTeam(attacker)){
			case 3: {
				damage = 0.0;
				return Plugin_Changed;
			}
		}
	}

	return Plugin_Continue;
}

//https://github.com/Kailo97/hidenseek-csgo/blob/master/addons/sourcemod/scripting/hidenseek.sp#L2007
void ScreenFade(int iClient, int iFlags = FFADE_PURGE, const int iaColor[4] = {0, 0, 0, 0}, int iDuration = 0, int iHoldTime = 0){
    Handle hScreenFade = StartMessageOne("Fade", iClient);
    if (GetUserMessageType() == UM_BitBuf){
		BfWriteShort(hScreenFade, iHoldTime * 500);
		BfWriteShort(hScreenFade, iDuration * 500);
		BfWriteShort(hScreenFade, iFlags);
		BfWriteByte(hScreenFade, iaColor[0]);
		BfWriteByte(hScreenFade, iaColor[1]);
		BfWriteByte(hScreenFade, iaColor[2]);
		BfWriteByte(hScreenFade, iaColor[3]);
	} else {
		PbSetInt(hScreenFade, "duration", iDuration * 500);
		PbSetInt(hScreenFade, "hold_time", iHoldTime * 500);
		PbSetInt(hScreenFade, "flags", iFlags);
		PbSetColor(hScreenFade, "clr", iaColor);
	}
    EndMessage();
}

// Experemintal
/*
stock void GetRookieLVL(int client, char[] rookie, int rookielen){
	g_kv.JumpToKey(g_jobid[client]);
	g_kv.GetString("rookie", rookie, rookielen);
	g_kv.Rewind();
}*/
// char buff[MAX_NAME_LENGTH];
// g_kv.GetString("idlejob", g_sBuffer, sizeof(g_sBuffer));
// g_rankid[target] = GetRookieLVL(client, buff, sizeof(buff));
// g_jobid[target] = g_jobid[client];

stock bool RP_IsBoss(int client){
	g_kv.JumpToKey(g_jobid[client]);
	char sBoss[64];
	g_kv.GetString("boss", sBoss, sizeof(sBoss), g_rankid[client]);
	if (StrContains(g_rankid[client], sBoss, false) != -1){
		g_kv.Rewind();
		return true;
	}
	g_kv.Rewind();
	return false;
}

public Action sm_invitejob(int client, int args){
	if (client && IsClientInGame(client) && IsPlayerAlive(client)){
		if (RP_IsBoss(client) && !RP_IsUnemployed(client)){
			int target = AimTargetPlayer(client);
			if (target != -1){
				if (RP_IsUnemployed(target)){
					g_jobid[target] = g_jobid[client];
					g_kv.JumpToKey(g_jobid[target]);
					//char buff[MAX_NAME_LENGTH];
					//g_kv.GetString("rookie", buff, sizeof(buff));
					g_kv.GetString("rookie", g_rankid[target], sizeof(g_rankid[]));
					g_kv.Rewind();
					SetJobKV(target);
					DB_SaveClientInfo(g_db, target);		// save player_info		[job,rank,money,bank]
					
					char JobName[64], RankName[64];
					GetName(target, JobName, sizeof(JobName), RankName, sizeof(RankName));
					PrintToChat(client, "You invited %N: Job: %s | Post: %s", target, JobName, RankName);
					PrintToChat(target, "Your new Job: %s | Post: %s", JobName, RankName);
					
				} else PrintToChat(client, "%N not unemployed.", target);
			} else PrintToChat(client, "This is not a player!");
		} else PrintToChat(client, "You are not the boss!");
	}
	return Plugin_Handled;
}

void SetJobKV(int client){
	SetTeamKV(client);
	SetSalaryMoneyKV(client);
	if (IsPlayerAlive(client)) SetModelKV(client);
}

stock void GetInfoEntity(int client) {
	int target = AimTargetPlayer(client);
	if (target <= 0) {
		return;
	}
	
	if (IsValidPlayer(target)) {
		char JobName[64], RankName[64];
		GetName(target, JobName, sizeof(JobName), RankName, sizeof(RankName));

		PrintHintText(client, "%N [HP:%d]\nJob: %s\nPost: %s", target, GetEntProp(target, Prop_Send, "m_iHealth"), JobName, RankName);
	}
}

public Action sm_leavejob(int client, int args){
	if (client && IsClientInGame(client) && IsPlayerAlive(client)){
		if (!RP_IsUnemployed(client)){
			RP_RemoveJob(client);
			SetJobKV(client);
			DB_SaveClientInfo(g_db, client);		// save player_info		[job,rank,money,bank]
			PrintToChat(client, "Вы теперь безработный");
		} else PrintToChat(client, "Denied");
	}
	return Plugin_Handled;
}