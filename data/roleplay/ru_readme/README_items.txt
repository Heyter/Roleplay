// * items.TXT * //

#	"price"					"200"							// ���� �������� � ��������
#	"enabled"				"1/0"							// �������� ������� [1/0]
#	"category"				"1"								// ���������� ��������� �������� � ��������	[��������� : item_categories.txt]
#	"entity"				"weapon_awp ��� prop_dynamic"	// ������� �������	[prop_, weapon, etc...]
#	"type"					"printer"						// ��� ��������			[weapon, printer, health]
#	"slots"					"2"								// ���������� ����(�) ���� ������� ��������� � ���������. ����� ����� ������� ���� �������� [��������� : settings_items.txt]
#	"model"					".mdl"							// ������ ��������	[���� = printer, health]
#	"health_amount"			"20"							// ��������� ��������� �� ��� ������������� [type = health]
#	"print_time"			"10"							// ����� ��������� ����� � �������� [type = printer]
#	"print_money_min"		"1"								// ����������� ����� ���������� �� ��������� [type = printer]
#	"print_money_max"		"5"								// ����������� ����� ���������� �� ��������� [type = printer]
p.s ������ ����� ������� ���������� � items.txt ����� ��� ��������� ����, ����� ��������� � �� �������, ��������� �������. (������� �������������: SQLiteStudio)
����� ������ � mysql, ��� � �� ���� ������ ��� ��������.

������ �������� - ������: 
	"AK47"
	{
		"price"		"500"
		"enabled"	"0"
		"category" 	"0"
		"entity"	"weapon_ak47"
		"type"		"weapon"
		"slots"		"5"	
	}

������ �������� - �������:
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
	
������ �������� - �������:
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
