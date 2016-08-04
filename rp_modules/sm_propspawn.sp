#pragma semicolon 1
#include <sdktools>
#pragma newdecls required

#define MAX_PROPS			256
#define CHAT_TAG			"[\x03PROPS] \x01"
#define CONFIG_SPAWNS		"data/roleplay/props.txt"

KeyValues g_settingsKV;
Handle g_hMenuAng, g_hMenuPos;
int g_iPropsCount;
char atm_model[PLATFORM_MAX_PATH], g_iProps[MAX_PROPS][2];

public Plugin porno = {
	author = "Hikka",
	name = "[RP:Module] Props spawn",
	version = "0.02",
};

public void OnPluginStart(){
	RegAdminCmd("sm_createprop", sm_createprop, ADMFLAG_ROOT, "Create test prop");
	RegAdminCmd("sm_saveprop", sm_saveprop, ADMFLAG_ROOT, "Save prop");
	RegAdminCmd("sm_delprop", sm_delprop, ADMFLAG_ROOT, "Delete prop");
	RegAdminCmd("sm_angprop", sm_angprop, ADMFLAG_ROOT, "Rotate prop - angles");
	RegAdminCmd("sm_posprop", sm_posprop, ADMFLAG_ROOT, "Rotate prop - position");
	RegAdminCmd("sm_propmenu", sm_propmenu, ADMFLAG_ROOT, "Admin - Prop menu");
	RegAdminCmd("sm_loadprop", sm_loadprop, ADMFLAG_ROOT, "Force load props");
	RegAdminCmd("sm_cleanprop", sm_cleanprop, ADMFLAG_ROOT, "Remove all props");
	
	RegAdminCmd("sm_rsettings", sm_rsettings, ADMFLAG_ROOT, "Reload config settings.txt");		// sm_roleplay.sp
	
	LoadKVSettings();
}

public Action sm_rsettings(int client, int args){
	delete g_settingsKV;
	LoadKVSettings();
	return Plugin_Handled;
}

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
		} while (g_settingsKV.GotoNextKey());
	}
	//g_settingsKV.Rewind();
}

public Action sm_propmenu(int client, int args){
	if (client && IsClientInGame(client)){
		RP_PropMenu(client);
	}
	return Plugin_Handled;
}

void RP_PropMenu(int client){
	Menu menu = new Menu(Select_propmenu); 
	menu.SetTitle("Admin - Prop menu");
	
	menu.AddItem("sm_createprop", "Create test prop");
	menu.AddItem("sm_saveprop", "Save prop");
	menu.AddItem("sm_delprop", "Delete prop");
	menu.AddItem("sm_angprop", "Rotate prop - angles");
	menu.AddItem("sm_posprop", "Rotate prop - position");
	menu.AddItem("sm_loadprop", "Force load props");
	menu.AddItem("sm_cleanprop", "Remove all props");
	
	menu.Display(client, MENU_TIME_FOREVER);
}

public int Select_propmenu(Menu menu, MenuAction action, int client, int option) {
	switch (action){
		case MenuAction_End: delete menu;
		case MenuAction_Select: {
			switch (option) {
				case 0: {
					FakeClientCommand(client, "sm_createprop");
					RP_PropMenu(client);
				}
				case 1: {
					FakeClientCommand(client, "sm_saveprop");
					RP_PropMenu(client);
				}
				case 2: {
					FakeClientCommand(client, "sm_delprop");
					RP_PropMenu(client);
				}
				case 3: FakeClientCommand(client, "sm_angprop");
				case 4: FakeClientCommand(client, "sm_posprop");
				case 5: FakeClientCommand(client, "sm_loadprop");
				case 6: {
					FakeClientCommand(client, "sm_cleanprop");
					RP_PropMenu(client);
				}
			}
		}
	}
}

public Action sm_cleanprop(int client, int args){
	if (client && IsClientInGame(client)){
		for (int i = 0; i < MAX_PROPS; i++){
			RemoveProps(i);
		}
		PrintToChat(client, "%sIts not save in config", CHAT_TAG);
	}
	return Plugin_Handled;
}

public Action sm_loadprop(int client, int args){
	if (client && IsClientInGame(client)){
		LoadProps();
	}
	return Plugin_Handled;
}

public void OnMapStart(){
	LoadProps();
}

void LoadProps()
{	
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "%s", CONFIG_SPAWNS);
	if (!FileExists(sPath))
		return;
	
	// Load config
	KeyValues hFile = CreateKeyValues("props");
	if (!FileToKeyValues(hFile, sPath))
	{
		delete hFile;
		return;
	}
	
	// Check for current map in the config
	char sMap[64];
	GetCurrentMap(sMap, sizeof(sMap));
	
	if (!hFile.JumpToKey(sMap)){
		delete hFile;
		return;
	}
	
	// Retrieve how many props to display
	int iCount = hFile.GetNum("num", 0);
	if (iCount == 0){
		delete hFile;
		return;
	}
	
	// Spawn only a select few props?
	int iIndexes[MAX_PROPS+1];
	if( iCount > MAX_PROPS )
		iCount = MAX_PROPS;
	// Spawn saved props or create random
	int iRandom = -1;
	if (iRandom == -1 || iRandom > iCount)
		iRandom = iCount;
	if (iRandom != -1){
		for (int i = 1; i <= iCount; i++)
			iIndexes[i-1] = i;
		
		SortIntegers(iIndexes, iCount, Sort_Random);
		iCount = iRandom;
	}
	
	// Get the props origins and spawn
	char sTemp[10]; 
	float vPos[3], vAng[3];
	int index;
	for (int i = 1; i <= iCount; i++)
	{
		index = iIndexes[i-1];
		index = i;
		
		IntToString(index, sTemp, sizeof(sTemp));
	
		if (hFile.JumpToKey(sTemp))
		{
			hFile.GetVector("angle", vAng);
			hFile.GetVector("origin", vPos);
			
			if (vPos[0] == 0.0 && vPos[0] == 0.0 && vPos[0] == 0.0)		// Should never happen.
				LogError("Error: 0,0,0 origin. Iteration=%d. Index=%d. Count=%d.", i, index, iCount);
			else
				CreateProps(vPos, vAng, index);
			hFile.GoBack();
		}
	}
	PrintToServer("[RP] Props load successfully: %i", iCount);			// DEBUG
	delete hFile;
}

public Action sm_createprop(int client, int args){
	if (!client || !IsClientInGame(client)){
		ReplyToCommand(client, "ERROR: You can't use that command while not in game!");
		return Plugin_Handled;
	}
	
	float vPos[3], vAng[3];
	if (!SetTeleportEndPoint(client, vPos, vAng)){
		PrintToChat(client, "%sCannot place prop, please try again.", CHAT_TAG);
		return Plugin_Handled;
	}

	CreateProps(vPos, vAng);
	return Plugin_Handled;
}

stock bool SetTeleportEndPoint(int client, float vPos[3], float vAng[3])
{
	GetClientEyePosition(client, vPos);
	GetClientEyeAngles(client, vAng);

	Handle trace = TR_TraceRayFilterEx(vPos, vAng, MASK_SHOT, RayType_Infinite, _TraceFilter);

	if(TR_DidHit(trace)){
		float vNorm[3];
		TR_GetEndPosition(vPos, trace);
		TR_GetPlaneNormal(trace, vNorm);
		float angle = vAng[1];
		GetVectorAngles(vNorm, vAng);

		vPos[2] += 25.0;

		if (vNorm[2] == 1.0){
			vAng[0] = 0.0;
			vAng[1] += angle;
			MoveSideway(vPos, vAng, vPos, -8.0);
		} else {
			vAng[0] = 0.0;
			vAng[1] += angle - 90.0;
			MoveForward(vPos, vAng, vPos, -10.0);
		}
	} else {
		delete trace;
		return false;
	}
	delete trace;
	return true;
}

public bool _TraceFilter(int entity, int contentsMask)
{
	return entity > MaxClients || !entity;
}

void MoveForward(const float vPos[3], const float vAng[3], float vReturn[3], float fDistance)
{
	fDistance *= -1.0;
	float vDir[3];
	GetAngleVectors(vAng, vDir, NULL_VECTOR, NULL_VECTOR);
	vReturn = vPos;
	vReturn[0] += vDir[0] * fDistance;
	vReturn[1] += vDir[1] * fDistance;
}

void MoveSideway(const float vPos[3], const float vAng[3], float vReturn[3], float fDistance)
{
	fDistance *= -1.0;
	float vDir[3];
	GetAngleVectors(vAng, NULL_VECTOR, vDir, NULL_VECTOR);
	vReturn = vPos;
	vReturn[0] += vDir[0] * fDistance;
	vReturn[1] += vDir[1] * fDistance;
}

void CreateProps(const float vOrigin[3], const float vAngles[3], int index = 0)
{
	int iPropsIndex = -1;
	for (int i = 0; i < MAX_PROPS; i++)
	{
		if (g_iProps[i][0] == 0)
		{
			iPropsIndex = i;
			break;
		}
	}

	if( iPropsIndex == -1 )
		return;

	int entity = CreateEntityByName("prop_physics_override");
	if( entity == -1 )
		ThrowError("Failed to create prop model.");

	g_iProps[iPropsIndex][0] = EntIndexToEntRef(entity);
	g_iProps[iPropsIndex][1] = index;
	GetStringATM();
	DispatchKeyValue(entity, "model", atm_model);				// Model in settings.txt.... yes. Suka blyad.
	//SetEntityModel(entity, atm_model);
	DispatchKeyValue(entity, "physicsmode", "2");
	DispatchKeyValue(entity, "massScale", "50.0");
	DispatchKeyValue(entity, "targetname", "atm");
	DispatchKeyValue(entity, "spawnflags", "0");
	DispatchSpawn(entity);
	
	SetEntProp(entity, Prop_Send, "m_usSolidFlags",  152);
	SetEntProp(entity, Prop_Send, "m_CollisionGroup", 8);
	SetEntProp(entity, Prop_Data, "m_takedamage", 0, 1);
	
	AcceptEntityInput(entity, "DisableMotion", -1, -1, 0);
	SetEntityMoveType(entity, MOVETYPE_NONE);

	TeleportEntity(entity, vOrigin, vAngles, NULL_VECTOR);
	
	g_iPropsCount++;
}

public Action sm_saveprop(int client, int args)
{
	if (!client || !IsClientInGame(client)){
		ReplyToCommand(client, "ERROR: You can't use that command while not in game!");
		return Plugin_Handled;
	}

	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "%s", CONFIG_SPAWNS);
	if( !FileExists(sPath) )
	{
		Handle hCfg = OpenFile(sPath, "w");
		WriteFileLine(hCfg, "");
		delete hCfg;
	}

	// Load config
	KeyValues hFile = CreateKeyValues("props");
	if( !FileToKeyValues(hFile, sPath) ){
		PrintToChat(client, "%sError: Cannot read the props config, assuming empty file. (\x05%s\x01).", CHAT_TAG, sPath);
	}

	// Check for current map in the config
	char sMap[64];
	GetCurrentMap(sMap, 64);
	if (!hFile.JumpToKey(sMap, true)){
		PrintToChat(client, "%sError: Failed to add map to props spawn config.", CHAT_TAG);
		delete hFile;
		return Plugin_Handled;
	}

	// Retrieve how many Props are saved
	int iCount = hFile.GetNum("num", 0);
	if (iCount >= MAX_PROPS)
	{
		PrintToChat(client, "%sError: Cannot add anymore props. Used: (\x05%d/%d\x01).", CHAT_TAG, iCount, MAX_PROPS);
		delete hFile;
		return Plugin_Handled;
	}

	// Save count
	iCount++;
	hFile.SetNum("num", iCount);

	char sTemp[10];

	IntToString(iCount, sTemp, sizeof(sTemp));

	if (hFile.JumpToKey(sTemp, true))
	{
		float vPos[3], vAng[3];
		// Set player position as props spawn location
		if( !SetTeleportEndPoint(client, vPos, vAng) )
		{
			PrintToChat(client, "%sCannot place props, please try again.", CHAT_TAG);
			delete hFile;
			return Plugin_Handled;
		}

		// Save angle / origin
		hFile.SetVector("angle", vAng);
		hFile.SetVector("origin", vPos);

		CreateProps(vPos, vAng, iCount);

		// Save cfg
		hFile.Rewind();
		KeyValuesToFile(hFile, sPath);

		PrintToChat(client, "%s(\x05%d/%d\x01) - Saved at pos:[\x05%f %f %f\x01] ang:[\x05%f %f %f\x01]", CHAT_TAG, iCount, MAX_PROPS, vPos[0], vPos[1], vPos[2], vAng[0], vAng[1], vAng[2]);
	}
	else
		PrintToChat(client, "%s(\x05%d/%d\x01) - Failed to save Props.", CHAT_TAG, iCount, MAX_PROPS);

	delete hFile;
	return Plugin_Handled;
}

public Action sm_delprop(int client, int args)
{
	if (!client || !IsClientInGame(client))
	{
		ReplyToCommand(client, "ERROR: You can't use that command while not in game!");
		return Plugin_Handled;
	}

	int entity = GetClientAimTarget(client, false);
	if (!IsValidEntity(entity)) return Plugin_Handled;

	int cfgindex, index = -1;
	for (int i = 0; i < MAX_PROPS; i++)
	{
		if (g_iProps[i][0] == entity)
		{
			index = i;
			break;
		}
	}

	if (index == -1)
		return Plugin_Handled;

	cfgindex = g_iProps[index][1];
	if (cfgindex == 0)
	{
		RemoveProps(index);
		return Plugin_Handled;
	}

	for (int i = 0; i < MAX_PROPS; i++)
	{
		if (g_iProps[i][1] > cfgindex)
			g_iProps[i][1]--;
	}

	g_iPropsCount--;

	// Load config
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "%s", CONFIG_SPAWNS);
	if (!FileExists(sPath))
	{
		PrintToChat(client, "%sError: Cannot find the Props config (\x05%s\x01).", CHAT_TAG, CONFIG_SPAWNS);
		return Plugin_Handled;
	}

	KeyValues hFile = CreateKeyValues("props");
	if (!FileToKeyValues(hFile, sPath))
	{
		PrintToChat(client, "%sError: Cannot load the Props config (\x05%s\x01).", CHAT_TAG, sPath);
		delete hFile;
		return Plugin_Handled;
	}

	// Check for current map in the config
	char sMap[64];
	GetCurrentMap(sMap, 64);

	if (!hFile.JumpToKey(sMap))
	{
		PrintToChat(client, "%sError: Current map not in the Props config.", CHAT_TAG);
		delete hFile;
		return Plugin_Handled;
	}

	// Retrieve how many Props
	int iCount = hFile.GetNum("num", 0);
	if (iCount == 0)
	{
		delete hFile;
		return Plugin_Handled;
	}

	bool bMove;
	char sTemp[16];

	// Move the other entries down
	for (int i = cfgindex; i <= iCount; i++)
	{
		IntToString(i, sTemp, sizeof(sTemp));

		if (hFile.JumpToKey(sTemp))
		{
			if (!bMove)
			{
				bMove = true;
				KvDeleteThis(hFile);
				RemoveProps(index);
			}
			else
			{
				IntToString(i-1, sTemp, sizeof(sTemp));
				hFile.SetSectionName(sTemp);
			}
		}

		hFile.Rewind();
		hFile.JumpToKey(sMap);
	}

	if (bMove)
	{
		iCount--;
		hFile.SetNum("num", iCount);

		// Save to file
		hFile.Rewind();
		KeyValuesToFile(hFile, sPath);

		PrintToChat(client, "%s(\x05%d/%d\x01) - Props removed from config.", CHAT_TAG, iCount, MAX_PROPS);
	}
	else
		PrintToChat(client, "%s(\x05%d/%d\x01) - Failed to remove Props from config.", CHAT_TAG, iCount, MAX_PROPS);

	delete hFile;
	return Plugin_Handled;
}

void RemoveProps(int index)
{
	int entity = g_iProps[index][0];
	g_iProps[index][0] = 0;

	if( IsValidEntRef(entity) )
		AcceptEntityInput(entity, "kill");
}

bool IsValidEntRef(int entity)
{
	if( entity && EntRefToEntIndex(entity) != INVALID_ENT_REFERENCE )
		return true;
	return false;
}

public Action sm_angprop(int client, int args)
{
	ShowMenuAng(client);
	return Plugin_Handled;
}

void ShowMenuAng(int client)
{
	CreateMenus();
	DisplayMenu(g_hMenuAng, client, MENU_TIME_FOREVER);
}

void CreateMenus()
{
	if (g_hMenuAng == INVALID_HANDLE)
	{
		g_hMenuAng = CreateMenu(AngMenuHandler);
		AddMenuItem(g_hMenuAng, "", "X + 5.0");
		AddMenuItem(g_hMenuAng, "", "Y + 5.0");
		AddMenuItem(g_hMenuAng, "", "Z + 5.0");
		AddMenuItem(g_hMenuAng, "", "X - 5.0");
		AddMenuItem(g_hMenuAng, "", "Y - 5.0");
		AddMenuItem(g_hMenuAng, "", "Z - 5.0");
		AddMenuItem(g_hMenuAng, "", "SAVE");
		SetMenuTitle(g_hMenuAng, "Set Angle");
	}

	if( g_hMenuPos == INVALID_HANDLE )
	{
		g_hMenuPos = CreateMenu(PosMenuHandler);
		AddMenuItem(g_hMenuPos, "", "X + 0.5");
		AddMenuItem(g_hMenuPos, "", "Y + 0.5");
		AddMenuItem(g_hMenuPos, "", "Z + 0.5");
		AddMenuItem(g_hMenuPos, "", "X - 0.5");
		AddMenuItem(g_hMenuPos, "", "Y - 0.5");
		AddMenuItem(g_hMenuPos, "", "Z - 0.5");
		AddMenuItem(g_hMenuPos, "", "SAVE");
		SetMenuTitle(g_hMenuPos, "Set Position");
	}
}

public int AngMenuHandler(Handle menu, MenuAction action, int client, int index)
{
	switch (action){
		case MenuAction_Select: {
			if (index == 6)
				SaveData(client);
			else
				SetAngle(client, index);
			ShowMenuAng(client);
		}
	}
}

void SetAngle(int client, int index)
{
	int aim = GetClientAimTarget(client, false);
	if (IsValidEntity(aim))
	{
		float vAng[3]; int entity;

		for (int i = 0; i < MAX_PROPS; i++)
		{
			entity = g_iProps[i][0];

			if (entity == aim)
			{
				GetEntPropVector(entity, Prop_Send, "m_angRotation", vAng);

				/*if( index == 0 ) vAng[0] += 5.0;
				else if( index == 1 ) vAng[1] += 5.0;
				else if( index == 2 ) vAng[2] += 5.0;
				else if( index == 3 ) vAng[0] -= 5.0;
				else if( index == 4 ) vAng[1] -= 5.0;
				else if( index == 5 ) vAng[2] -= 5.0;*/
				switch (index){
					case 0: vAng[0] += 5.0;
					case 1: vAng[1] += 5.0;
					case 2: vAng[2] += 5.0;
					case 3: vAng[0] -= 5.0;
					case 4: vAng[1] -= 5.0;
					case 5: vAng[2] -= 5.0;
				}

				TeleportEntity(entity, NULL_VECTOR, vAng, NULL_VECTOR);

				PrintToChat(client, "%sNew angles: %f %f %f", CHAT_TAG, vAng[0], vAng[1], vAng[2]);
				break;
			}
		}
	}
}

public Action sm_posprop(int client, int args)
{
	ShowMenuPos(client);
	return Plugin_Handled;
}

void ShowMenuPos(int client)
{
	CreateMenus();
	DisplayMenu(g_hMenuPos, client, MENU_TIME_FOREVER);
}

public int PosMenuHandler(Handle menu, MenuAction action, int client, int index)
{
	switch (action){
		case MenuAction_Select: {
			if( index == 6 )
				SaveData(client);
			else
				SetOrigin(client, index);
			ShowMenuPos(client);
		}
	}
}

void SetOrigin(int client, int index)
{
	int aim = GetClientAimTarget(client, false);
	if (IsValidEntity(aim))
	{
		float vPos[3]; int entity;

		for (int i = 0; i < MAX_PROPS; i++)
		{
			entity = g_iProps[i][0];

			if( entity == aim  ){
				GetEntPropVector(entity, Prop_Send, "m_vecOrigin", vPos);
	
				/*if( index == 0 ) vPos[0] += 0.5;
				else if( index == 1 ) vPos[1] += 0.5;
				else if( index == 2 ) vPos[2] += 0.5;
				else if( index == 3 ) vPos[0] -= 0.5;
				else if( index == 4 ) vPos[1] -= 0.5;
				else if( index == 5 ) vPos[2] -= 0.5;*/
				
				switch (index){
					case 0: vPos[0] += 0.5;
					case 1: vPos[1] += 0.5;
					case 2: vPos[2] += 0.5;
					case 3: vPos[0] -= 0.5;
					case 4: vPos[1] -= 0.5;
					case 5: vPos[2] -= 0.5;
				}
	
				TeleportEntity(entity, vPos, NULL_VECTOR, NULL_VECTOR);
	
				PrintToChat(client, "%sNew origin: %f %f %f", CHAT_TAG, vPos[0], vPos[1], vPos[2]);
				break;
			}
		}
	}
}

void SaveData(int client)
{
	int entity, index;
	int aim = GetClientAimTarget(client, false);
	if (IsValidEntity(aim)){

		for (int i = 0; i < MAX_PROPS; i++)
		{
			entity = g_iProps[i][0];
	
			if (entity == aim)
			{
				index = g_iProps[i][1];
				break;
			}
		}
	
		if (index == 0)
			return;
	
		// Load config
		char sPath[PLATFORM_MAX_PATH];
		BuildPath(Path_SM, sPath, sizeof(sPath), "%s", CONFIG_SPAWNS);
		if (!FileExists(sPath))
		{
			PrintToChat(client, "%sError: Cannot find the Props config (\x05%s\x01).", CHAT_TAG, CONFIG_SPAWNS);
			return;
		}
	
		KeyValues hFile = CreateKeyValues("props");
		if (!FileToKeyValues(hFile, sPath))
		{
			PrintToChat(client, "%sError: Cannot load the Props config (\x05%s\x01).", CHAT_TAG, sPath);
			delete hFile;
			return;
		}
	
		// Check for current map in the config
		char sMap[64];
		GetCurrentMap(sMap, 64);
	
		if (!hFile.JumpToKey(sMap))
		{
			PrintToChat(client, "%sError: Current map not in the Props config.", CHAT_TAG);
			delete hFile;
			return;
		}
	
		float vAng[3], vPos[3]; char sTemp[32];
		GetEntPropVector(entity, Prop_Send, "m_vecOrigin", vPos);
		GetEntPropVector(entity, Prop_Send, "m_angRotation", vAng);
	
		IntToString(index, sTemp, sizeof(sTemp));
		if (hFile.JumpToKey(sTemp))
		{
			hFile.SetVector("angle", vAng);
			hFile.SetVector("origin", vPos);
	
			// Save cfg
			hFile.Rewind();
			KeyValuesToFile(hFile, sPath);
	
			PrintToChat(client, "%sSaved origin and angles to the data config", CHAT_TAG);
		}
	}
}

void GetStringATM(){
	g_settingsKV.GetString("atm_model", atm_model, sizeof(atm_model));
}

// Original plugin: [L4D2] Gnome health - https://forums.alliedmods.net/showthread.php?p=1658852