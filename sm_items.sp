#pragma semicolon 1
#include <roleplay>
#include <sdktools>
#pragma newdecls required
#define MAXITEMS 			500
#define MAXCATEGORIES		100
#define MIN_DISTANCE_USE 	100
#define MAXENTS				4000
#define RP_ITEMS_PREFIX "\x03[RP Items]"
KeyValues itembuykv, itemcatkv, g_itemsKV;

char item_name[MAXITEMS][64], item_entity[MAXITEMS][64], cat_name[MAXCATEGORIES][64],
	item_type[MAXITEMS][64], item_model[MAXITEMS][PLATFORM_MAX_PATH],
	def_dropmodel[PLATFORM_MAX_PATH], pickup_sound[PLATFORM_MAX_PATH];
	
int item_price[MAXITEMS], item_quantity = 0,
	item_cat[MAXITEMS], cat_quantity = 0, Item[MAXPLAYERS + 1][MAXITEMS],
	selected_item[MAXPLAYERS + 1], drop_amount[MAXENTS][MAXITEMS],
	slots[MAXPLAYERS + 1], item_slots[MAXITEMS], iMaxSlots,
	item_health_amount[MAXITEMS], item_enabled[MAXITEMS];
	
bool g_bPressedUse[MAXPLAYERS + 1], iSlotsEnable;
float g_flPressUse[MAXPLAYERS + 1];

Database g_db;
bool db_mysql, started;
char Logs[256] = "addons/sourcemod/logs/rp_items.log";

public Plugin myinfo = {
	author = "Hikka",
	name = "[RP:Module] items",
	version = "0.01",
	description = "inventory for roleplay",
	url = "https://github.com/Heyter/Roleplay",
};

public void OnPluginStart(){
	RegConsoleCmd("sm_shop", sm_shop);
	RegConsoleCmd("sm_cat_shop", sm_cat_shop);
	RegConsoleCmd("sm_inv", sm_inv);
	RegConsoleCmd("sm_item", sm_inv);
	
	RegConsoleCmd("sm_mystats", sm_mystats);			// Test command
	
	RegAdminCmd("sm_rsettings_items", sm_rsettings_items, ADMFLAG_ROOT, "Reload settings_items.txt");
	
	// Load Items
	LoadItems();
	// Load Categories
	LoadCategories();
	// Load settings_items
	LoadItemSettings();
	// Database connect
	DB_PreConnect();
}

public void OnClientPutInServer(int client){
	if (!RP_IsStarted()) return;
	
	g_bPressedUse[client] = false;
	g_flPressUse[client] = -1.0;
	slots[client] = 0;
	
	DB_OnClientPutInServer(client);
}

public Action sm_inv(int client, int args){
	if (client && IsClientInGame(client)){
		RP_InvMenu(client);
	}
	return Plugin_Handled;
}

void RP_InvMenu(int client){
	Menu menu = new Menu(Inv_CallBack);
	menu.SetTitle("Inventory menu");
	menu.AddItem("inv", "Inventory");
	menu.Display(client, MENU_TIME_FOREVER);
}

public int Inv_CallBack(Menu menu, MenuAction action, int client, int option){
	switch (action) {
		case MenuAction_End: delete menu;
		case MenuAction_Select: {
			char info[32];
			menu.GetItem(option, info, sizeof(info));
			
			switch (option){
				case 0: {
					menu = new Menu(Menu_Inv_Categories);
					char title_str[64]; GetMaxSlots(); GetEnableSlots();
					if (iSlotsEnable) {
						if (slots[client] >= iMaxSlots){
							FormatEx(title_str, sizeof(title_str), "Inventory [%i / %i]", slots[client], iMaxSlots);
						}
					} else FormatEx(title_str, sizeof(title_str), "Inventory");
					menu.SetTitle(title_str);
					
					int[] cat_owned = new int[cat_quantity]; int cat = 0;
					for (int index = 0; index < item_quantity; index++){
						if (Item[client][index] != 0){
							cat = item_cat[index];
							cat_owned[cat] = 1;
						}
					}
					
					char cat_str[4];
					for (int i = 0; i < cat_quantity; i++){
						FormatEx(cat_str, sizeof(cat_str), "%i", i);
						switch (cat_owned[i]){
							case 1: menu.AddItem(cat_str, cat_name[i]);
							case 0: menu.AddItem(cat_str, cat_name[i], ITEMDRAW_DISABLED);
						}
					}
					menu.Display(client, MENU_TIME_FOREVER);
					selected_item[client] = -1;
					return;
				}
			}
		}
	}
}

public int Menu_Inv_Categories(Menu menu, MenuAction action, int client, int option){
	switch (action) {
		case MenuAction_End: delete menu;
		case MenuAction_Select: {
			char info[32];
			menu.GetItem(option, info, sizeof(info));
			int cat = StringToInt(info);
			
			menu = new Menu(Menu_Inventory);
			char buffer[64], X_str[8];
			
			for (int X = 0; X < item_quantity; X++){
				if (Item[client][X] != 0){
					if (item_cat[X] == cat){
						FormatEx(X_str, sizeof(X_str), "%i", X);
						FormatEx(buffer, sizeof(buffer), "%s (%i)", item_name[X], Item[client][X]);
						menu.AddItem(X_str, buffer);
					}
				}
			}
			menu.SetTitle(cat_name[cat]);
			menu.Display(client, MENU_TIME_FOREVER);
		}
	}
}

public int Menu_Inventory(Menu menu, MenuAction action, int client, int option){
	switch (action) {
		case MenuAction_End: delete menu;
		case MenuAction_Select: {
			char info[32];
			menu.GetItem(option, info, sizeof(info));
			int index = StringToInt(info);
			
			menu = new Menu(Menu_Use);
			char title_str[32];
			FormatEx(title_str, sizeof(title_str), "%s:", item_name[index]);
				
			menu.AddItem("0", "[ Use ]");
			menu.AddItem("1", "[ Remove ]");
			menu.AddItem("2", "[ Drop ]");
			menu.SetTitle(title_str);
				
			selected_item[client] = index;
			menu.Display(client, MENU_TIME_FOREVER);
		}
	}
}

public int Menu_Use(Menu menu, MenuAction action, int client, int option){
	switch (action) {
		case MenuAction_End: delete menu;
		case MenuAction_Select: {
			if (!IsPlayerAlive(client)) selected_item[client] = -1;
			GetEnableSlots();
			
			char info[32];
			menu.GetItem(option, info, sizeof(info));
			int index = selected_item[client];
			if (index != -1){
				switch (option){
					case 0: {			// 0 = use item
						if (strcmp(item_type[index], "weapon") == 0){
							if (iSlotsEnable) {
								slots[client] -= item_slots[index];
								Item[client][index] -= 1;
							} else {
								Item[client][index] -= 1;
							}
							
							GivePlayerItem(client, item_entity[index]);
							RP_SaveItem(client, item_name[index], Item[client][index]);
							PrintToChat(client, "%s \x04%s \x01удален из инвентаря", RP_ITEMS_PREFIX, item_name[index]);
							selected_item[client] = -1;
						}
						
						else if (strcmp(item_type[index], "health") == 0){
							int player_hp = GetClientHealth(client),
								combined_hp = (player_hp + item_health_amount[index]);
							if (player_hp >= 100) {
								PrintToChat(client, "%s You have full health", RP_ITEMS_PREFIX, client);
								selected_item[client] = -1;
							}
							
							else if (combined_hp >= 100)
							{
								Item[client][index] -= 1;
								if (iSlotsEnable) slots[client] += item_slots[index];
								RP_SaveItem(client, item_name[index], Item[client][index]);
								SetEntityHealth(client, 100);
								PrintToChat(client, "%s You have full health", RP_ITEMS_PREFIX, client);
								PrintToChat(client, "%s You have %i %s left.", RP_ITEMS_PREFIX, Item[client][index], item_name[index]);
								selected_item[client] = -1;
							} else {
								Item[client][index] -= 1;
								if (iSlotsEnable) slots[client] += item_slots[index];
								RP_SaveItem(client, item_name[index], Item[client][index]);
								player_hp += item_health_amount[index];
								SetEntityHealth(client, player_hp);
								PrintToChat(client, "%s You have been given %i HP.", RP_ITEMS_PREFIX, item_health_amount[index]);
								PrintToChat(client, "%s You have %i %s left.", RP_ITEMS_PREFIX, Item[client][index], item_name[index]);
								selected_item[client] = -1;
							}
						}
					}
					
					case 1: {
						// 1 = trash one
						menu = new Menu(Menu_Verify);
						char str_sure[48], str_yes[16], str_no[16];
						FormatEx(str_sure, sizeof(str_sure), "Item remove?", client);
						FormatEx(str_yes, sizeof(str_yes), "Yes", client);
						FormatEx(str_no, sizeof(str_no), "No", client);
						menu.AddItem("0", str_no);
						menu.AddItem("1", str_yes);
						menu.SetTitle(str_sure);
						menu.Display(client, MENU_TIME_FOREVER);
					}
					
					case 2: {
						// 2 = [ Drop ]
						menu = new Menu(Drop_Callback);
						menu.SetTitle("Select amount");
						
						if (Item[client][index] >= 1) menu.AddItem("1", "1");
						if (Item[client][index] >= 5) menu.AddItem("5", "5");
						if (Item[client][index] >= 10) menu.AddItem("10", "10");
						if (Item[client][index] >= 15) menu.AddItem("15", "15");
						if (Item[client][index] >= 20) menu.AddItem("20", "20");
						if (Item[client][index] >= 25) menu.AddItem("25", "25");
						
						menu.Display(client, MENU_TIME_FOREVER);
					}
				}
			}
		}
	}
}

public int Drop_Callback(Menu menu, MenuAction action, int client, int option) {
    switch (action){
        case MenuAction_End: delete menu;
        case MenuAction_Select: {
			if (!IsPlayerAlive(client)) selected_item[client] = -1;

			char sData[16];
			menu.GetItem(option, sData, sizeof(sData));
			int index = selected_item[client],
				amount = StringToInt(sData);
			//if (!item_model[index][0]){
			if (!item_model[index][0] || strcmp(item_type[index], "weapon") == 0){
				DropItemDefault(client, index, amount);
			} else DropItem(client, index, amount);
			RP_SaveItem(client, item_name[index], Item[client][index]);
			RP_InvMenu(client);
		}
	}
}
				
public int Menu_Verify(Menu menu, MenuAction action, int client, int option){
	switch (action) {
		case MenuAction_End: delete menu;
		case MenuAction_Select: {
			if (!IsPlayerAlive(client)) selected_item[client] = -1;
			GetEnableSlots();
			
			char info[32];
			menu.GetItem(option, info, sizeof(info));
			switch (option){
				case 1: {
					int index = selected_item[client];
					Item[client][index]--;
					if (iSlotsEnable) {
						slots[client] -= item_slots[index];
						selected_item[client] = -1;
					} else {
						selected_item[client] = -1;
					}
					PrintToChat(client, "%s \x03%N \x04%s \x01removed", RP_ITEMS_PREFIX, client, item_name[index]);
					RP_SaveItem(client, item_name[index], Item[client][index]);
					RP_InvMenu(client);
				}
			}
		}
	}
}

stock void DropItemDefault(int client, int index, int amount){
	float EyeAng[3], ForwardVec[3];
	GetClientEyeAngles(client, EyeAng);
	GetAngleVectors(EyeAng, ForwardVec, NULL_VECTOR, NULL_VECTOR);
	ScaleVector(ForwardVec, 100.0);
	ForwardVec[2] = 0.0;
	
	float EyePos[3], AbsAngle[3];
	GetClientEyePosition(client, EyePos);
	GetClientAbsAngles(client, AbsAngle);
	
	float SpawnAngles[3], SpawnOrigin[3];
	SpawnAngles[1] = EyeAng[1];
	AddVectors(EyePos, ForwardVec, SpawnOrigin);
	
	if (Item[client][index] >= amount){
		int ent; GetDefaultModelDrop();
		if ((ent = CreateEntityByName("prop_physics_override")) != -1){
			if (!IsModelPrecached(def_dropmodel)) PrecacheModel(def_dropmodel);
			ActivateEntity(ent);
			DispatchKeyValue(ent, "model", def_dropmodel);
			DispatchKeyValueFloat (ent, "MaxPitch", 360.00);
			DispatchKeyValueFloat (ent, "MinPitch", -360.00);
			DispatchKeyValueFloat (ent, "MaxYaw", 90.00);
			SetEntProp(ent, Prop_Send, "m_CollisionGroup", 11);
			DispatchSpawn(ent);
			TeleportEntity(ent, SpawnOrigin, SpawnAngles, NULL_VECTOR);
			
			PrintToChat(client, "%s \x03%N \x01dropped by \x04%s", RP_ITEMS_PREFIX, client, item_name[index]);
			PrintToServer("%s %s dropped by %N.", RP_ITEMS_PREFIX, item_name[index], client);
			
			Item[client][index] -= amount;
			GetEnableSlots();
			if (iSlotsEnable) {
				slots[client] -= (item_slots[index] * amount);
				drop_amount[ent][index] = amount;
			} else {
				drop_amount[ent][index] = amount;
			}
			selected_item[client]--;
		}
	}
}
								
stock void DropItem(int client, int index, int amount){
	float EyeAng[3], ForwardVec[3];
	GetClientEyeAngles(client, EyeAng);
	GetAngleVectors(EyeAng, ForwardVec, NULL_VECTOR, NULL_VECTOR);
	ScaleVector(ForwardVec, 100.0);
	ForwardVec[2] = 0.0;
	
	float EyePos[3], AbsAngle[3];
	GetClientEyePosition(client, EyePos);
	GetClientAbsAngles(client, AbsAngle);
	
	float SpawnAngles[3], SpawnOrigin[3];
	SpawnAngles[1] = EyeAng[1];
	AddVectors(EyePos, ForwardVec, SpawnOrigin);
	
	if (Item[client][index] >= amount){
		int ent;
		//if (IsValidEntity(ent))
		if ((ent = CreateEntityByName(item_entity[index])) != -1)
		{
			if (!IsModelPrecached(item_model[index])) PrecacheModel(item_model[index]);
			ActivateEntity(ent);
			SetEntityModel(ent, item_model[index]);
			DispatchKeyValueFloat (ent, "MaxPitch", 360.00);
			DispatchKeyValueFloat (ent, "MinPitch", -360.00);
			DispatchKeyValueFloat (ent, "MaxYaw", 90.00);
			DispatchSpawn(ent);
			TeleportEntity(ent, SpawnOrigin, SpawnAngles, NULL_VECTOR);
			
			PrintToChat(client, "%s \x03%N \x01dropped \x04%s", RP_ITEMS_PREFIX, client, item_name[index]);
			PrintToServer("%s %s dropped by %N.", RP_ITEMS_PREFIX, item_name[index], client);
			
			Item[client][index] -= amount;
			GetEnableSlots();
			if (iSlotsEnable) {
				slots[client] -= (item_slots[index] * amount);
				drop_amount[ent][index] = amount;
			} else {
				drop_amount[ent][index] = amount;
			}
			selected_item[client]--;
		}
	}
}
	
public Action sm_shop(int client, int args){
	if (client && IsClientInGame(client) && IsPlayerAlive(client)){
		RP_ShopMenu(client);
	}
	return Plugin_Handled;
}

void RP_ShopMenu(int client){
	Menu menu = new Menu(Menu_Vend);
	menu.SetTitle("Store");
	int price = 0; char buffer[64], X_str[8];
	for (int X = 0; X < item_quantity; X++){
	//for (int X = 0; X < MAXITEMS.Length; X++){
		if (!item_name[X][0]) break;
		switch (item_enabled[X]){
			case 1: {
				price = item_price[X];
				FormatEx(buffer, sizeof(buffer), "%s $%i", item_name[X], price);
				FormatEx(X_str, sizeof(X_str), "%i", X);
				if (GetClientMoney(client) >= price){
					GetMaxSlots();
					int max_slots = iMaxSlots;
					if (slots[client] >= max_slots){
						menu.AddItem(X_str, buffer, ITEMDRAW_DISABLED);
					} else {
						menu.AddItem(X_str, buffer);
					}
				}
			}
		}
	}
	menu.Display(client, MENU_TIME_FOREVER);
}

public int Menu_Vend(Menu menu, MenuAction action, int client, int option){
	switch (action) {
		case MenuAction_End: delete menu;
		case MenuAction_Select: {
			/*float clientent[3];
			GetClientAbsOrigin(client, clientent);
			float distance = GetVectorDistance(g_fATMorigin[client], clientent);
			if (distance > MIN_DISTANCE_USE) {
				PrintToChat(client, "%s You have departed from the NPC", RP_ITEMS_PREFIX);
				return;
			}*/
			if (!IsPlayerAlive(client))PrintToChat(client, "%s You die", RP_ITEMS_PREFIX);
			char info[32];
			menu.GetItem(option, info, sizeof(info));
			int X = StringToInt(info, 10);
			
			if (X != -1){
				int price = item_price[X];
				if (GetClientMoney(client) >= price){
					GetMaxSlots();
					GetEnableSlots();
					int max_slots = iMaxSlots;
					if (slots[client] >= max_slots){
						PrintToChat(client, "%s \x01You don't have \x03slots", RP_ITEMS_PREFIX);
					} else {
						SetClientMoney(client, GetClientMoney(client) - price);
						Item[client][X]++;
						if (iSlotsEnable) {
							slots[client] += item_slots[X];
							PrintToChat(client, "%s \x01You buy \x04%s \x01for \x04%i + %d \x01slots", RP_ITEMS_PREFIX, item_name[X], price, item_slots[X]);
						} else PrintToChat(client, "%s \x01You buy \x04%s \x01for \x04%i", RP_ITEMS_PREFIX, item_name[X], price);
						RP_SaveItem(client, item_name[X], Item[client][X]);
						RP_ShopMenu(client);
					}
				} else PrintToChat(client, "%s You don't have money!", RP_ITEMS_PREFIX);
			}
		}
	}
}
					
public void LoadItems()
{
	itembuykv = new KeyValues("Items");
	char path[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, path, sizeof(path), "data/roleplay/items.txt");
	if (!itembuykv.ImportFromFile(path)) SetFailState("Can't read %s", path);

	itembuykv.Rewind();

	if (!itembuykv.GotoFirstSubKey()) SetFailState("There are no items listed in invent.txt, or there is an error with the file.");
	
	int items = 0;
	do
	{
		itembuykv.GetSectionName(item_name[items], sizeof(item_name[]));
		itembuykv.GetString("type", item_type[items], sizeof(item_type[]), "INVALID");
		item_enabled[items] = itembuykv.GetNum("enabled", 1);
		item_price[items] = itembuykv.GetNum("price", 500);
		if (item_price[items] < 0){
			item_enabled[items] = 0;
			PrintToServer("%s Item %s (#%i) Disabled -- price less than 0.", RP_ITEMS_PREFIX, item_name[items], 1);
		}
		item_slots[items] = itembuykv.GetNum("slots", 1);
		itembuykv.GetString("entity", item_entity[items], sizeof(item_entity[]), "INVALID");
		itembuykv.GetString("model", item_model[items], sizeof(item_model[]), "INVALID");
		item_cat[items] = itembuykv.GetNum("category", 0);
		item_health_amount[items] = itembuykv.GetNum("health_amount", 0);		
		
		items++;

	} while (itembuykv.GotoNextKey() && (items < MAXITEMS));
	
	item_quantity = items;

	itembuykv.Rewind();
	
	PrintToServer("%s Items Loaded", RP_ITEMS_PREFIX);
	PrintToServer("%s %i Items were detected.", RP_ITEMS_PREFIX, item_quantity);
	
	// Now make a super item quantity array!!
}

public void LoadCategories()
{
	itemcatkv = new KeyValues("Categories");
	char path[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, path, sizeof(path), "data/roleplay/item_categories.txt");
	if (!itemcatkv.ImportFromFile(path)) SetFailState("Can't read %s", path);
	else if (!itemcatkv.GotoFirstSubKey()) SetFailState("There are no items listed in item_categories.txt, or there is an error with the file.");

	int items = 0;
	do
	{
		itemcatkv.GetString("name", cat_name[items], sizeof(cat_name[]), "INVALID");
		cat_quantity++;
		items++;
	} while ((itemcatkv.GotoNextKey()) && (cat_quantity < MAXCATEGORIES));
	
	itemcatkv.Rewind();
	
	PrintToServer("%s Item Categories Loaded", RP_ITEMS_PREFIX);
	PrintToServer("%s %i Categories were detected.", RP_ITEMS_PREFIX, cat_quantity);
}

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
					GetDefaultModelDrop();			// def_drop_model
					GetPickUpSound();				// pickup_sound
					GetMaxSlots();					// max_slots
					GetEnableSlots();				// Enable system slots
					
					for (int X = 0; X < item_quantity; X++){
						if (strcmp(modelname, def_dropmodel) == 0 || strcmp(modelname, item_model[X]) == 0){
							int max_slots = iMaxSlots;
							if (slots[client] != max_slots){
								float origin[3], clientent[3];
								GetEntPropVector(ent, Prop_Send, "m_vecOrigin", origin);
								GetClientAbsOrigin(client, clientent);
								float distance = GetVectorDistance(origin, clientent);
								if (distance < MIN_DISTANCE_USE && drop_amount[ent][X] != 0){
									RemoveEdict(ent);
									Item[client][X] += drop_amount[ent][X];
									EmitSoundToClient(client, pickup_sound);
									if (iSlotsEnable) {
										slots[client] += (item_slots[X] * drop_amount[ent][X]);
										PrintToChat(client, "%s \x03You pick up \x04%i \x01of \x04%s + %d \x01slots", RP_ITEMS_PREFIX, drop_amount[ent][X], item_name[X], item_slots[X] * drop_amount[ent][X]);
									} else PrintToChat(client, "%s \x03You pick up \x04%i \x01of \x04%s", RP_ITEMS_PREFIX, drop_amount[ent][X], item_name[X]);
									RP_SaveItem(client, item_name[X], Item[client][X]);
									drop_amount[ent][X] = 0;
								}
							}
						}
					}
				}
			}
		}
	}
	return Plugin_Continue;
}

public Action sm_rsettings_items(int client, int args){
	delete g_itemsKV;
	LoadItemSettings();
	return Plugin_Handled;
}

void LoadItemSettings(){
	g_itemsKV = new KeyValues("Settings");
	char path[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, path, sizeof(path), "data/roleplay/settings_items.txt");
	if (!g_itemsKV.ImportFromFile(path)) SetFailState("Can't read %s", path);
	
	if (g_itemsKV.GotoFirstSubKey()){
		do 
		{
			GetDefaultModelDrop();
			GetPickUpSound();
			GetMaxSlots();
			GetEnableSlots();
		} while (g_itemsKV.GotoNextKey());
	}
}

void GetDefaultModelDrop(){
	g_itemsKV.GetString("def_drop_model", def_dropmodel, sizeof(def_dropmodel));
}

void GetPickUpSound(){
	g_itemsKV.GetString("pickup_sound", pickup_sound, sizeof(pickup_sound));
}

void GetMaxSlots(){
	iMaxSlots = view_as<int>(g_itemsKV.GetNum("max_slots", 20));
}

void GetEnableSlots(){
	iSlotsEnable = view_as<bool>(g_itemsKV.GetNum("slots_enable", 1));
}

public void OnMapStart(){
	GetDefaultModelDrop();
	GetPickUpSound();
	
	if (!IsModelPrecached(def_dropmodel)) PrecacheModel(def_dropmodel, true);
	if (!IsSoundPrecached(pickup_sound)) PrecacheSound(pickup_sound, true);
}

public Action sm_cat_shop(int client, int args){
	if (client && IsClientInGame(client)){
		RP_ShopCatMenu(client);
	}
	return Plugin_Handled;
}

void RP_ShopCatMenu(int client){
	Menu menu = new Menu(Menu_Categories);
	menu.SetTitle("Choose a Category");
	char cat_str[4];
	for (int i = 0; i < cat_quantity; i++){
		FormatEx(cat_str, sizeof(cat_str), "%i", i);
		menu.AddItem(cat_str, cat_name[i]);
	}
	menu.Display(client, MENU_TIME_FOREVER);
}

public int Menu_Categories(Menu menu, MenuAction action, int client, int option){
	switch (action) {
		case MenuAction_End: delete menu;
		case MenuAction_Select: {
			/*float clientent[3];
			GetClientAbsOrigin(client, clientent);
			float distance = GetVectorDistance(g_fATMorigin[client], clientent);
			if (distance > MIN_DISTANCE_USE) {
				PrintToChat(client, "%s You have departed from the NPC", RP_ITEMS_PREFIX);
				return;
			}*/
			
			if (!IsPlayerAlive(client))PrintToChat(client, "%s You die", RP_ITEMS_PREFIX);
			
			menu = new Menu(Menu_Buy);
			char i_str[4], name_str[64];
			for (int i = 0; i < item_quantity; i++){
				if (item_cat[i] == option){
					switch (item_enabled[i]){
						case 1: {
							FormatEx(i_str, sizeof(i_str), "%i", i);
							FormatEx(name_str, sizeof(name_str), "%s - $%i", item_name[i], item_price[i]);
							if (GetClientMoney(client) >= item_price[i]){
								GetMaxSlots();
								int max_slots = iMaxSlots;
								if (slots[client] >= max_slots){
									menu.AddItem(i_str, name_str, ITEMDRAW_DISABLED);
								} else {
									menu.AddItem(i_str, name_str);
								}
							}
						}
					}
				}
			}
			menu.SetTitle(cat_name[option]);
			menu.Display(client, MENU_TIME_FOREVER);
		}
	}
}

public int Menu_Buy(Menu menu, MenuAction action, int client, int option){
	switch (action) {
		case MenuAction_End: delete menu;
		case MenuAction_Select: {
			char info[32];
			menu.GetItem(option, info, sizeof(info));
			int X = StringToInt(info, 10);
			
			if (X != -1){
				int price = item_price[X];
				if (GetClientMoney(client) >= price){
					GetMaxSlots();
					GetEnableSlots();
					int max_slots = iMaxSlots;
					if (slots[client] >= max_slots){
						PrintToChat(client, "%s \x01You don't have \x03slots", RP_ITEMS_PREFIX);
					} else {
						SetClientMoney(client, GetClientMoney(client) - price);
						Item[client][X]++;
						if (iSlotsEnable) {
							slots[client] += item_slots[X];
							PrintToChat(client, "%s \x01You buy \x04%s \x01for \x04%i + %d \x01slots", RP_ITEMS_PREFIX, item_name[X], price, item_slots[X]);
						} else PrintToChat(client, "%s \x01You buy \x04%s \x01for \x04%i", RP_ITEMS_PREFIX, item_name[X], price);
						RP_SaveItem(client, item_name[X], Item[client][X]);
						RP_ShopCatMenu(client);
					}
				} else PrintToChat(client, "%s You don't have money!", RP_ITEMS_PREFIX);
			}
		}
	}
}

void DB_PreConnect() {
	if (g_db != null) {
		return;
	}

	if (SQL_CheckConfig("rp_items")) {
		Database.Connect(DB_Connect, "rp_items", 1);
	}
	else {
		char error[256];

		g_db = SQLite_UseDatabase("rp_items", error, sizeof(error));

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
		LogToFile(Logs, "[DB - Errors] DB_Connect: %s", error);
		LogError("DB_Connect: %s", error);
		CreateTimer(10.0, DB_ReconnectTimer);
		return;
	}

	if (error[0]) {
		LogToFile(Logs, "[DB - Errors] (data %d) DB_Connect: %s", data, error);
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
		LogToFile(Logs, "[DB - Errors] DB_Connect: Driver \"%s\" is not supported!", ident);
		SetFailState("DB_Connect: Driver \"%s\" is not supported!", ident);
	}

	g_db.SetCharset("utf8");

	DB_CreateTables(g_db);
}

void DB_CreateTables(Database db) {
	char query[8192]; int len = 0;
	if (db_mysql) {
		len += FormatEx(query[len], sizeof(query)-len, "CREATE TABLE IF NOT EXISTS `player_items`");
		len += FormatEx(query[len], sizeof(query)-len, " (`auth` varchar(22) NOT NULL, `name` varchar(32) NOT NULL DEFAULT 'unknown', ");
		for (int i = 0; i < item_quantity; i++)
		{
			len += FormatEx(query[len], sizeof(query)-len, "`%s` int(10) NOT NULL, ", item_name[i]);
		}
		len += FormatEx(query[len], sizeof(query)-len, "PRIMARY KEY (`auth`), ");
		len += FormatEx(query[len], sizeof(query)-len, "ENGINE=MyISAM DEFAULT CHARSET=utf8 AUTO_INCREMENT=1);");

		db.Query(DB_PlayersTable, query, 1, DBPrio_High);
	} else {
		len += FormatEx(query[len], sizeof(query)-len, "CREATE TABLE IF NOT EXISTS `player_items`");
		len += FormatEx(query[len], sizeof(query)-len, " (`auth` varchar(22) NOT NULL, `name` VARCHAR DEFAULT 'unknown', ");
		for (int i = 0; i < item_quantity; i++)
		{
			len += FormatEx(query[len], sizeof(query)-len, "`%s` int(10) NOT NULL DEFAULT 0, ", item_name[i]);
		}
		len += FormatEx(query[len], sizeof(query)-len, "PRIMARY KEY (`auth`));");

		db.Query(DB_PlayersTable, query, 1, DBPrio_High);
	}
}

public void DB_PlayersTable(Database db, DBResultSet results, const char[] error, any data) {
	//if (results == null) ThrowError("DB_PlayersTable results error query: %s", error);
	if (error[0]) {
		LogToFile(Logs, "[RP - Errors] (data %d) DB_PlayersTable: %s", data, error);
		LogError("DB_PlayersTable %d: %s", data, error);
		delete g_db;
		g_db = null;
		CreateTimer(10.0, DB_ReconnectTimer);
		return;
	}
	switch (data){
		case 1: RP_Start();
	}
}

void DB_OnClientPutInServer(int client, DBPriority prio = DBPrio_Normal) {
	if (g_db == null || !RP_IsStarted()) {
		LogToFile(Logs, "[RP - Warnings] DB_OnClientPutInServer: g_db = (%d) or rp %s", g_db, RP_IsStarted() ? "started" : "not started");
		return;
	}

	char auth[32], query[512];
	Client_SteamID(client, auth, sizeof(auth));

	FormatEx(query, sizeof(query), "SELECT * FROM `player_items` WHERE auth = '%s';", auth);

	g_db.Query(DB_OnClientPutInServerCallback, query, client, prio);
}

public void DB_OnClientPutInServerCallback(Database db, DBResultSet results, const char[] error, any data) {
	if (!IsClientInGame(data)) return;
	
	GetEnableSlots();			// Enable slots system
	
	if (results.HasResults && results.FetchRow()) {
		for (int X = 0; X < item_quantity; X++)
		{
			PrintToServer("items");
			Item[data][X] = results.FetchInt(X+2);
			if (Item[data][X] > 0){
				if (iSlotsEnable) slots[data] += (Item[data][X] * item_slots[X]);
			} else {
				Item[data][X] = 0;
			}
		}
	}
	else {
		char query[512],
			 name[MAX_NAME_LENGTH],
			 buffer[65];

		Client_GetName(data, name, sizeof(name));
		EscapeString(db, name, buffer, sizeof(buffer));

		char auth[32];
		Client_SteamID(data, auth, sizeof(auth));

		FormatEx(query, sizeof(query), "INSERT INTO `player_items` (`name`, `auth`) VALUES ('%s', '%s');", buffer, auth);
		
		for (int X = 0; X < item_quantity; X++)
		{
			Item[data][X] = 0;			
		}
		slots[data] = 0;

		DB_TQueryEx(query, _, 0);

		DB_OnClientPutInServer(data);
	}
}

// save all info client
void DB_SaveClient(int client, DBPriority prio = DBPrio_Normal) {
	if (!client || !IsClientInGame(client)) return;

	char query[512],
		 name[MAX_NAME_LENGTH],
		 auth[32];

	Client_GetName(client, name, sizeof(name));
	EscapeString(g_db, name, name, sizeof(name));
	
	Client_SteamID(client, auth, sizeof(auth));

	FormatEx(query, sizeof(query), "UPDATE `player_items` SET `name` = '%s' WHERE `auth` = '%s';", name, auth);

	DB_TQueryEx(query, prio, 2);
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

public bool Client_GetName(int client, char[] name, int maxlen) {
	if (IsClientInGame(client)) {
		return view_as<bool>(GetClientName(client, name, maxlen));
	}
	return false;
}

void RP_SaveItem(int client, char[] itemname, int amount, DBPriority prio = DBPrio_Normal) 
{
	if (IsClientInGame(client))
	{
		char query[512], auth[32];
		Client_SteamID(client, auth, sizeof(auth));
		//for (int i = 0; i < item_quantity; i++){
			//FormatEx(query, sizeof(query), "UPDATE `player_items` SET `%s` = %i WHERE `auth` = '%s';", item_name[i], amount, auth);
		//}
		FormatEx(query, sizeof(query), "UPDATE `player_items` SET `%s` = %i WHERE `auth` = '%s';", itemname, amount, auth);
		DB_TQueryEx(query, prio, 2);
	}
}

public void OnClientDisconnect(int client){
	if (!RP_IsStarted()) {
		return;
	}
	DB_SaveClient(client);
}

public Action sm_mystats(int client, int args){
	if (client){
		GetMaxSlots();
		GetEnableSlots();
		if (iSlotsEnable) PrintToChat(client, "Slots: min.%i / max.%i", slots[client], iMaxSlots);
		for (int X = 0; X < item_quantity; X++){
			PrintToChat(client, "Item Name: %s [%i]", item_name[X], Item[client][X]);
		}
	}
	return Plugin_Handled;
}

//////////////////////
// * GLOBAL TIMER * //
//////////////////////
public Action RP_StartGlobalTimer(){
	if (RP_IsStartedDB()) {
		PrintToServer("Test global forward");
	}
}