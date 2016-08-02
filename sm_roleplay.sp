#pragma semicolon 1
#include <sdktools>
#include <colors_csgo>
#include <cstrike>
#pragma newdecls required
#define IDSIZE 32

// macross
//#define RemoveJob(%1) SetClientJob(%1, "", ""), CS_SwitchTeam(%1, CS_TEAM_T)
//#define IsHaveJob(%1) (g_jobid[%1][0] != '\0')

Database g_db;
bool db_mysql, started;
char db_prefix[15] = "rp_",
	Logs[256] = "addons/sourcemod/logs/rp_logs.log";

ConVar Database_prefix;
int RP_ID[MAXPLAYERS + 1], RP_Money[MAXPLAYERS + 1], RP_Bank[MAXPLAYERS + 1],
	g_jobTarget[MAXPLAYERS + 1], RP_RespawnTime[MAXPLAYERS + 1];

char g_jobid[MAXPLAYERS + 1][IDSIZE], g_rankid[MAXPLAYERS + 1][IDSIZE],
	g_sBuffer[MAX_NAME_LENGTH];
	
float RP_LastMsg[MAXPLAYERS + 1];

// * KeyValues - jobs.txt * //
KeyValues g_kv;
Menu g_jobsmenu;

// * KeyValues - settings.txt * //
float fChatDistance;
bool iFog;
KeyValues g_settingsKV;

// * Global string - keyvalues * //
char model[PLATFORM_MAX_PATH], atm_model[PLATFORM_MAX_PATH], money_model[PLATFORM_MAX_PATH];

char Forbidden_Commands[][] = {
    "explode",		"kill",			"coverme",		"takepoint",
    "holdpos",		"regroup",		"followme",		"takingfire",
    "go",			"fallback",		"sticktog",		"getinpos",
    "stormfront",	"report",		"roger",		"enemyspot",
    "needbackup",	"sectorclear",	"inposition",	"reportingin",
    "getout",		"negative",		"enemydown",	"spectate",
    "jointeam",		"suicide",
};

public Plugin info = {
	author = "Hikka, Kailo, Exle",
	name = "[SM] Roleplay mod",
	version = "alpha 0.03",
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

	RegConsoleCmd("sm_myjob", Cmd_MyJob, "Test command");
	
	RegConsoleCmd("sm_dropmoney", sm_dropmoney, "sm_dropmoney <amount>");

	RegAdminCmd("sm_jobs", Cmd_Jobs, ADMFLAG_ROOT, "Set job for player");
	RegAdminCmd("sm_reloadsettings", sm_ReloadSettings, ADMFLAG_ROOT, "Reload config settings.txt");
	RegAdminCmd("sm_reloadjobs", Cmd_ReloadJobs, ADMFLAG_ROOT, "Reload config jobs.txt");
	RegAdminCmd("sm_unemployed", sm_unemployed, ADMFLAG_ROOT, "Set unemployed for player");
	RegAdminCmd("sm_givemoney", sm_givemoney, ADMFLAG_ROOT, "Give money");
	RegAdminCmd("sm_setmoney", sm_setmoney, ADMFLAG_ROOT, "Set money");
	RegAdminCmd("sm_givebank", sm_givebank, ADMFLAG_ROOT, "Give money in bank");
	RegAdminCmd("sm_setbank", sm_setbank, ADMFLAG_ROOT, "Set money in bank");
	RegAdminCmd("sm_dbsave", sm_dbsave, ADMFLAG_ROOT, "Force Server DB Save");
	
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
	
	ResetVariables(client);
	DB_OnClientPutInServer(client);
}

public void OnClientDisconnect(int client){
	if (!RP_IsStarted()) {
		return;
	}
	DB_SaveClient(client);
}

public void OnMapStart(){
	if (!IsModelPrecached(atm_model)) PrecacheModel(atm_model, true);
	else if (!IsModelPrecached(money_model)) PrecacheModel(money_model, true);
	else if (!IsModelPrecached(model)) PrecacheModel(model, true);
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

	char buffer[256];
	if (results.HasResults && results.FetchRow()) { 
		results.FetchString(0, buffer, sizeof(buffer));
		RP_SetJobDB(data, buffer);

		results.FetchString(1, buffer, sizeof(buffer));
		RP_SetRankDB(data, buffer);
		/*results.FetchString(0, buffer, sizeof(buffer));
		GetJobSQL(data, buffer, sizeof(buffer));
		results.FetchString(1, buffer, sizeof(buffer));
		GetRankSQL(data, buffer, sizeof(buffer));*/

		RP_Money[data] = results.FetchInt(2);
		RP_Bank[data] = results.FetchInt(3);
	}
	else {
		char query[512],
			buffer2[128],
			auth[32];
			
		Client_SteamID(data, auth, sizeof(auth));

		GetJobSQL(data, buffer, sizeof(buffer));
		GetRankSQL(data, buffer2, sizeof(buffer2));

		FormatEx(query, sizeof(query), "INSERT INTO `%splayers_info` (`auth`, `jobid`, `rankid`, `money`, `bank_money`) VALUES ('%s', '%s', '%s', '%d', '%d');", db_prefix, auth, buffer, buffer2, RP_Money[data], RP_Bank[data]);

		DB_TQueryEx(query, _, 1);

		DB_LoadClientInfo(data);
	}
}

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

public void RP_SetJobDB(int client, char[] job) {
	if (IsClientInGame(client)) {
		strcopy(g_jobid[client], sizeof(g_jobid[]), job);
	}
}

public void RP_SetRankDB(int client, char[] rank){
	if (IsClientInGame(client)){
		strcopy(g_rankid[client], sizeof(g_rankid[]), rank);
	}
}

//////////////
// * JOBS * //
//////////////

public void ResetVariables(int client){
	g_kv.GetString("idlejob", g_sBuffer, sizeof(g_sBuffer));
	g_kv.GetString("idlerank", g_sBuffer, sizeof(g_sBuffer));
	
	g_jobid[client] = g_sBuffer;
	g_rankid[client] = g_sBuffer;
	
	RP_RespawnTime[client] = 0;
	RP_LastMsg[client] = 0.0;
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
	g_kv.GetString("idlejob", g_sBuffer, sizeof(g_sBuffer));
	g_kv.GetString("idlerank", g_sBuffer, sizeof(g_sBuffer));
	SetClientJob(client, g_sBuffer, g_sBuffer);
	CS_SwitchTeam(client, CS_TEAM_T);
	SetModelKV(client);
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
			if (IsPlayerAlive(client)){
				SetModelKV(client);
			}
			SetTeamKV(client);
				
			/*if (IsPlayerAlive(client)){
				FakeClientCommand(client, "kill");
			} else PrintToChat(param1, "Target dead");
			GiveKVsettings(client);*/
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
			g_settingsKV.GetString("atm_model", atm_model, sizeof(atm_model));
			g_settingsKV.GetString("money_model", money_model, sizeof(money_model));
			fChatDistance = view_as<float>(g_settingsKV.GetFloat("localchat_distance", 500.0));
			iFog = view_as<bool>(g_settingsKV.GetNum("turn_fog", 0));
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
	else if (strcmp(command, "say") == 0){
		if ((GetEngineTime() - RP_LastMsg[client]) < 3.00){
			return Plugin_Handled;
		}
		RP_LastMsg[client] = GetEngineTime();
		CPrintToChatAll("\x01(OOC) \x03%N: \x01%s", client, text);
	}
	
	else if (strcmp(command, "say_team") == 0){
		for (int i = 1; i <= MaxClients; i++){
			if (Entity_Distance(client, i) <= fChatDistance){
				if ((GetEngineTime() - RP_LastMsg[client]) < 0.75){
					return Plugin_Handled;
				}
				
				RP_LastMsg[client] = GetEngineTime();

				CPrintToChatEx(i, client, "\x01(LOCAL) \x03%N: \x01%s", client, text);
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

stock bool CreateProp(float[] pos, const char[] name) {
	int ent;
	if ((ent = CreateEntityByName("prop_physics_override")) != -1) {
		char targetname[64];
		FormatEx(targetname, sizeof(targetname), "%s", name, ent);

		char sModel[PLATFORM_MAX_PATH];
		if (StrEqual(name, "atm")) {
			strcopy(sModel, sizeof(sModel), atm_model);
		}
		else {
			LogError("This prop name is not supported (%s)", name);
			return false;
		}
		DispatchKeyValue(ent, "model", sModel);
		DispatchKeyValue(ent, "physicsmode", "2");
		DispatchKeyValue(ent, "massScale", "50.0");
		DispatchKeyValue(ent, "targetname", targetname);
		DispatchKeyValue(ent, "spawnflags", "0");
		DispatchSpawn(ent);

		SetEntProp(ent, Prop_Send, "m_usSolidFlags", 152);
		SetEntProp(ent, Prop_Send, "m_CollisionGroup", 8);
		SetEntProp(ent, Prop_Data, "m_takedamage", 0, 1);

		AcceptEntityInput(ent, "DisableMotion", -1, -1, 0);
		SetEntityMoveType(ent, MOVETYPE_NONE);

		float posa[3], angle[3]; ;
		posa[0] = pos[0]; posa[1] = pos[1]; posa[2] = pos[2];
		angle[0] = pos[3]; angle[1] = pos[4]; angle[2] = pos[5];
		TeleportEntity(ent, posa, angle, NULL_VECTOR);
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
	RemoveWeapon(client);			// Disarm Player
	
	SetModelKV(client);				// Set the player model
	SetTeamKV(client);				// Set the player team
	GiveWeaponKV(client);			// Give the player weapons
}

public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast) {
	int client = GetClientOfUserId(event.GetInt("userid"));
	/*char sRespawn[64]; int tRespawn;
	FormatEx(sRespawn, sizeof(sRespawn), "%s/%s/respawn_time", g_jobid[client], g_rankid[client]);
	tRespawn = view_as<int>(g_kv.GetNum(sRespawn, 10));
	RP_RespawnTime[client] = tRespawn;*/
	SetRespawnTimeKV(client);
}

void RegCvars(){
	Database_prefix = CreateConVar("sm_rp_dbprefix", db_prefix, "Prefix database");
	Database_prefix.GetString(db_prefix, sizeof(db_prefix));
	Database_prefix.AddChangeHook(CvarChange);
}

public Action Cmd_MyJob(int client, int args)
{
	if (client) {
		char JobName[64], RankName[64];
		GetName(client, JobName, sizeof(JobName), RankName, sizeof(RankName));
		PrintToChat(client, "Your Job: %s \nRank: %s", JobName, RankName);
	}

	return Plugin_Handled;
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
				DB_SaveClient(target);				// save DB target
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
				DB_SaveClient(target);				// save DB target
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
				DB_SaveClient(target);				// save DB target
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
				DB_SaveClient(target);				// save DB target
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
		}
	}
	return Plugin_Handled;
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
				/*} else {
					if (rp_salarymode && rp_daytime*60%(rp_daytime*60/rp_salarytime) == 0) {
						Salary(client, SalaryTypes_Salary);
					}
					else if (!rp_salarymode && cur_time%rp_salarytime == 0) {
						Salary(client, SalaryTypes_Salary);
					}
				} */
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
		} else ThrowError("Job \"%s-%s\" don't contain team key", g_jobid[client], g_rankid[client]);			// Test: error log
	}
}

void GiveWeaponKV(int client){
	if (client && IsClientInGame(client)){
		char branch[64], tool[32];
		FormatEx(branch, sizeof(branch), "%s/%s/tool", g_jobid[client], g_rankid[client]);
		g_kv.GetString(branch, tool, sizeof(tool));
		if (tool[0] != '\0') 
			GivePlayerItem(client, tool);
	}
}

void SetRespawnTimeKV(int client){
	char sRespawn[64]; int tRespawn;
	FormatEx(sRespawn, sizeof(sRespawn), "%s/%s/respawn_time", g_jobid[client], g_rankid[client]);
	tRespawn = g_kv.GetNum(sRespawn);
	RP_RespawnTime[client] = tRespawn;
}