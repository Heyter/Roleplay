// * JOBS.TXT * //
"team"						"2 or 3"		2 - T; 3 - CT;
"name"						"translation job/rank"			[Dont use in unemployed job]
"respawn_time"				"10"			// respawn timer if you dead. 1 or ...
"model"						"model/skin/player.mdl"					// skin/model player
"salary"					"100"
"health"					"150"
"armor"						"150"
"tools"						{ "tool" "weapon_name"  "tool" "weapon_name"  "tool" "weapon_name" }
"tools"						{}		// Do not give weapons
"rookie"					"name rank"			// This is level on the job			[Newbie]
"boss"						"name rank"			// This is level on the job			[Main]


// * EXAMPLE JOB * //
	"Mafia"			// Job
	{
		"rookie"	"Test"
		"Test"
		{
			"respawn_time" "5"
			"salary" "1"				// salary get money
			"tools" { "tool" "weapon_knife"  "tool" "weapon_deagle" }
			"team" "3"
		}
		
		"Soldier"
		{
			"respawn_time" "5"
			"salary" "4"				// salary get money
			"tools" {}
			"team" "3"
		}
		
		"boss"		"C.Boss"
		"C.Boss"
		{
			"respawn_time" "4"
			"salary" "5"				// salary get money
			"tools" { "tool" "weapon_knife"  "tool" "weapon_awp"}
			"team" "3"
		}
	}
