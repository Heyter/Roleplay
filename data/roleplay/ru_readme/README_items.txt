// * items.TXT * //

#	"price"					"200"							// цена предмета в магазине
#	"enabled"				"1/0"							// включить предмет [1/0]
#	"category"				"1"								// показывает категорию предмета в магазине	[настройки : item_categories.txt]
#	"entity"				"weapon_awp или prop_dynamic"	// Создать предмет	[prop_, weapon, etc...]
#	"type"					"printer"						// тип предмета			[weapon, printer, health]
#	"slots"					"2"								// Прибавляет слот(ы) если предмет находится в инвентаре. Нужно чтобы система была включена [настройки : settings_items.txt]
#	"model"					".mdl"							// модель предмета	[типы = printer, health]
#	"health_amount"			"20"							// Добавляет указанное ХП при использование [type = health]
#	"print_time"			"10"							// время печатанья денег в секундах [type = printer]
#	"print_money_min"		"1"								// минимальная сумма получаемая за печатанье [type = printer]
#	"print_money_max"		"5"								// максимльная сумма получаемая за печатанье [type = printer]
p.s каждый новый предмет занесенный в items.txt после уже созданной базы, нужно добавлять в БД вручную, создавать столбец. (Советую использоввать: SQLiteStudio)
плохо знаком с mysql, вот и не стал решать эту проблему.

Пример предмета - оружие: 
	"AK47"
	{
		"price"		"500"
		"enabled"	"0"
		"category" 	"0"
		"entity"	"weapon_ak47"
		"type"		"weapon"
		"slots"		"5"	
	}

Пример предмета - принтер:
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
	
Пример предмета - аптечка:
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
