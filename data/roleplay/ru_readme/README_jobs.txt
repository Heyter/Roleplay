// * JOBS.TXT * //
"team"						"2 или 3"		2 - T; 3 - CT;		// командаа за которую перевести игрока
"name"						"перевод job/rank"			[Не использовать если статус работы безработный ("idlejob" "Unemployed" и "idlerank" "Hobo")]
"respawn_time"				"10"			// время воскрешение игрока если он умер
"model"						"model/skin/player.mdl"					// модель игрока
"salary"					"100"			// зарплата получаемая каждые X сек, время получение зарплаты настраивается в settings.txt
"health"					"150"			// здоровье выдаваемое при воскрешение игрока
"armor"						"150"			// броня выдаваемая при воскрешение игрока
"tools"						{ "tool" "weapon_name"  "tool" "weapon_name"  "tool" "weapon_name" }		// оружие выдаваемое при воскрешение игрока
"tools"						{}		// Писать так если не хотите выдавать оружие при воскрешение
"rookie"					"name rank"			// уровень работы - самый низкий уровень			[Новичок]
"boss"						"name rank"			// Уровень работы - самый высокий в организации		[Главный]
"steal"						"1"					1 - ВКЛ; 0 - ВЫКЛ 		// Позволяет воровать деньги у игрока на клавишу [E]. Стоит защита - своих обворовать нельзя
"pvp_amount"				"20"			// Если игрок убил игрока то добавляем к PVP статусу секунды. Чтобы выключить просто введите 0.


// * Пример работ * //
	"Mafia"			// имя работа
	{
		"rookie"	"Test"
		"Test"		// имя ранга / должности
		{
			"respawn_time" "5"
			"salary" "1"
			"tools" { "tool" "weapon_knife"  "tool" "weapon_deagle" }
			"team" "3"
		}
		
		"Soldier"
		{
			"respawn_time" "5"
			"salary" "4"
			"tools" {}
			"team" "3"
			"steal" "1"	
		}
		
		"boss"		"C.Boss"
		"C.Boss"
		{
			"respawn_time" "4"
			"salary" "5"
			"tools" { "tool" "weapon_knife"  "tool" "weapon_awp"}
			"team" "3"
			"steal" "1"	
		}
	}