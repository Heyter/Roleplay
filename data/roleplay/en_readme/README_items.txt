// * items.TXT * //

#	"price"					"200"							// price in shop
#	"enabled"				"1/0"							// enabled item
#	"category"				"1"								// category show in shop	[settings here : item_categories.txt]
#	"entity"				"weapon_awp or prop_dynamic"	// Create entity name	[prop_, weapon, etc...]
#	"type"					"printer"						// type item 			[weapon, printer, health]
#	"slots"					"2"								// plus a slot if the item in the inventory. If system slots enable [settings here : settings_items.txt]
#	"model"					".mdl"							// item model	[type = printer, health]
#	"health_amount"			"20"							// Add HP [type = health]
#	"print_time"			"10"							// time printing money [type = printer]
#	"print_money_min"		"1"								// minimal print money [type = printer]
#	"print_money_max"		"1"								// maximan print money [type = printer]

Example item weapon: 
	"AK47"
	{
		"price"		"500"
		"enabled"	"0"
		"category" 	"0"
		"entity"	"weapon_ak47"
		"type"		"weapon"
		"slots"		"5"	
	}

Example item printer:
	"Printer (bronze)"
	{
		"price"				"1"
		"category" 			"1"
		"entity"			"prop_physics_override"
		"type"				"printer"
		"model"				"models/props_interiors/vcr_new.mdl"
		"slots"				"2"
		"print_time"		"10"
		"print_money_min"	"10"
		"print_money_max"	"20"
	}
	
Example item health:
	"Healthkit (100)"
	{
		"price"		"250"
		"category" 	"1"
		"entity"	"prop_physics_override"
		"type"		"health"
		"model"		"models/weapons/w_eq_healthshot_dropped.mdl"
		"slots"		"1"
		"health_amount" 	"100"
	}
	
P.s. sorry guys for my english, i didn't teach him.
