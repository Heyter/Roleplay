#pragma semicolon 1
#include <sdktools>
#include <createspawns>

#define MAX_SPAWNS 128
KeyValues g_kvspawns;
float g_fSpawns[MAX_SPAWNS][3], NULLZONE[3] = {0.0, 0.0, 0.0};
int exitjail, jail, spawns;
#define RP_SPAWNS_PREFIX "[RP Spawns]"

public Plugin myinfo = {
	author = "Hikka",
	name = "[RP:Module] spawns",
	description = "Create spawns for roleplay mod",
	version = "0.01",
	url = "https://github.com/Heyter/Roleplay",
};

public void OnPluginStart(){
	RegAdminCmd("sm_tp", sm_tp, ADMFLAG_ROOT, "- Teleport to spawns -  test function");
	RegAdminCmd("sm_spawns", sm_spawns, ADMFLAG_ROOT, "- Create spawns");

	LoadSpawn(0);	// Load jails
	LoadSpawn(1);	// Load exit jail
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max){
	RegPluginLibrary("createspawns");
	
	CreateNative("RP_TeleportToCell", Native_TeleportToCell);
	CreateNative("RP_TeleportToExitCell", Native_TeleportToExitCell);
	
	PrintToServer("[RP Spawns] Natives Loaded");
	return APLRes_Success;
}

public int Native_TeleportToCell(Handle plugin, int numParams){
	TeleportToCell(GetNativeCell(1));
	return;
}

public int Native_TeleportToExitCell(Handle plugin, int numParams){
	TeleportToExitCell(GetNativeCell(1));
	return;
}

public Action sm_tp(int client, int args){
	if (!client || !IsClientInGame(client)){
		ReplyToCommand(client, "ERROR: You can't use that command while not in game!");
		return Plugin_Handled;
	}
	int random = GetRandomInt(0, exitjail - 1);
	if (g_fSpawns[random][0] != NULLZONE[0])
		TeleportEntity(client, g_fSpawns[random], NULL_VECTOR, NULL_VECTOR);
	PrintToChat(client, "Random: %i", random);
	PrintToChat(client, "Position: %f %f %f", g_fSpawns[random][0], g_fSpawns[random][1], g_fSpawns[random][2]);
	return Plugin_Handled;
}

stock int TeleportToExitCell(int client){
	int random_ex = GetRandomInt(0, exitjail - 1);
	if (g_fSpawns[random_ex][0] != NULLZONE[0]) {
		TeleportEntity(client, g_fSpawns[random_ex], NULL_VECTOR, NULL_VECTOR);
	}
}

stock int TeleportToCell(int client){
	int random_j = GetRandomInt(0, jail - 1);
	if (g_fSpawns[random_j][0] != NULLZONE[0]) {
		TeleportEntity(client, g_fSpawns[random_j], NULL_VECTOR, NULL_VECTOR);
	}
}

public Action sm_spawns(int client, int args){
	if (!client || !IsClientInGame(client)){
		ReplyToCommand(client, "ERROR: You can't use that command while not in game!");
		return Plugin_Handled;
	}
	RP_AddSpawn(client);
	return Plugin_Handled;
}

void RP_AddSpawn(int client){
	Menu menu = new Menu(select_addspawn); 
	menu.SetTitle("[RP] Create spawns");
	
	menu.AddItem("", "Set cell");
	menu.AddItem("", "Set exit cell");
	
	menu.Display(client, MENU_TIME_FOREVER);
}

public int select_addspawn(Menu menu, MenuAction action, int client, int option) {
	switch (action){
		case MenuAction_End: delete menu;
		case MenuAction_Select: {
			switch (option) {
				case 0: AddSpawn(client, 0);		// Jail
				case 1: AddSpawn(client, 1);		// Exit jail
			}
		}
	}
}

stock void LoadSpawn(int type){
	char path[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, path, sizeof(path), "data/roleplay/spawns.txt");
	if (!FileExists(path)){
		Handle hCfg = OpenFile(path, "w");
		WriteFileLine(hCfg, "");
		delete hCfg;
	}
	
	g_kvspawns = new KeyValues("Spawns");
	if (!g_kvspawns.ImportFromFile(path)) SetFailState("Can't read %s", path);
	g_kvspawns.Rewind();
	
	char map[64];
	GetCurrentMap(map, sizeof(map));
	if (!g_kvspawns.JumpToKey(map, true)){
		PrintToServer("Error: Failed to add map to spawn config.");
		delete g_kvspawns;
	}

	switch(type) {
		case 0: {
			g_kvspawns.JumpToKey("Jail", true);
			jail = 0;
		}
		case 1: {
			g_kvspawns.JumpToKey("JailExit", true);
			exitjail = 0;
		}
	}
	
	if (g_kvspawns.GotoFirstSubKey(false)) {
		do {
			switch (type) {
				case 0: {
					g_kvspawns.GetVector(NULL_STRING, g_fSpawns[jail], NULLZONE);
					jail++;
				}
				case 1: {
					g_kvspawns.GetVector(NULL_STRING, g_fSpawns[exitjail], NULLZONE);
					exitjail++;
				}
			}
		} while (g_kvspawns.GotoNextKey(false));
	}
	g_kvspawns.Rewind();
	switch (type) {
		case 0: PrintToServer("%s %i Spawns - cells were detected.", RP_SPAWNS_PREFIX, jail);
		case 1: PrintToServer("%s %i Spawns - cells exit were detected.", RP_SPAWNS_PREFIX, exitjail);
	}
}

stock void AddSpawn(int client, int type){
    char path[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, path, sizeof(path), "data/roleplay/spawns.txt");
    if (!FileExists(path)){
        Handle hCfg = OpenFile(path, "w");
        WriteFileLine(hCfg, "");
        delete hCfg;
    }
   
    g_kvspawns = new KeyValues("Spawns");
    if (!g_kvspawns.ImportFromFile(path))
        SetFailState("Can't read %s", path);
   
    char map[64];
    GetCurrentMap(map, sizeof(map));
    if (!g_kvspawns.JumpToKey(map, true)){
        PrintToChat(client, "Error: Failed to add map to spawn config.");
        delete g_kvspawns;
    }
   
    switch(type) {
        case 0: g_kvspawns.JumpToKey("Jail", true);
        case 1: g_kvspawns.JumpToKey("JailExit", true);
    }
 
    spawns = 0;
    if (g_kvspawns.GotoFirstSubKey(false)) {
        do {
            spawns++;
        } while (g_kvspawns.GotoNextKey(false));
        g_kvspawns.GoBack();
    }
 
    if(spawns >= MAX_SPAWNS) {
        PrintToChat(client, "%s Max spawns: %i", RP_SPAWNS_PREFIX, MAX_SPAWNS);
        return;
    }
   
    char nextindex[3];
    IntToString(spawns, nextindex, sizeof(nextindex));
    PrintToChat(client, "%s New spawn index: %s / %d", RP_SPAWNS_PREFIX, nextindex, type);
    spawns++;

    float origin[3];
    GetClientAbsOrigin(client, origin);
    g_kvspawns.SetVector(nextindex, origin);
 
    g_kvspawns.Rewind();
    g_kvspawns.ExportToFile(path);
    delete g_kvspawns;
    
    switch (type){
    	case 0:LoadSpawn(0);
    	case 1:LoadSpawn(1);
    }
    	
    RP_AddSpawn(client);
}