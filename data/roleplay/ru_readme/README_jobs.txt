// * JOBS.TXT * //
"team"						"2 ��� 3"		2 - T; 3 - CT;		// �������� �� ������� ��������� ������
"name"						"������� job/rank"			[�� ������������ ���� ������ ������ ����������� ("idlejob" "Unemployed" � "idlerank" "Hobo")]
"respawn_time"				"10"			// ����� ����������� ������ ���� �� ����
"model"						"model/skin/player.mdl"					// ������ ������
"salary"					"100"			// �������� ���������� ������ X ���, ����� ��������� �������� ������������� � settings.txt
"health"					"150"			// �������� ���������� ��� ����������� ������
"armor"						"150"			// ����� ���������� ��� ����������� ������
"tools"						{ "tool" "weapon_name"  "tool" "weapon_name"  "tool" "weapon_name" }		// ������ ���������� ��� ����������� ������
"tools"						{}		// ������ ��� ���� �� ������ �������� ������ ��� �����������
"rookie"					"name rank"			// ������� ������ - ����� ������ �������			[�������]
"boss"						"name rank"			// ������� ������ - ����� ������� � �����������		[�������]
"steal"						"1"					1 - ���; 0 - ���� 		// ��������� �������� ������ � ������ �� ������� [E]. ����� ������ - ����� ���������� ������
"pvp_amount"				"20"			// ���� ����� ���� ������ �� ��������� � PVP ������� �������. ����� ��������� ������ ������� 0.


// * ������ ����� * //
	"Mafia"			// ��� ������
	{
		"rookie"	"Test"
		"Test"		// ��� ����� / ���������
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