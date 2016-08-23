#pragma semicolon 1
#include <roleplay>
#pragma newdecls required
int RP_gCuffTime[MAXPLAYERS + 1], RP_gCuffTarget[MAXPLAYERS + 1], RP_Cuff[MAXPLAYERS + 1];
float radius = 100.0;	// radius cuff
int rtime = 5;			// time cuff
int RP_gTimeCuff[MAXPLAYERS + 1];
bool RP_CuffProtection[MAXPLAYERS + 1];

public Plugin porno = {
	author = "Hikka",
	name = "[RP:Module] cuff",
	description = "experimental plugin - cuff for roleplay",
	version = "0.02",
	url = "https://github.com/Heyter/Roleplay/devplugins",
};

stock bool IsValidPlayer(int client){
	if (0 < client <= MaxClients && IsClientInGame(client))
	{
		return true;
	}
	else return false;
}

public void OnPluginStart(){
	CreateTimer(1.0, OnEverySecond, _, TIMER_REPEAT);
	
	for (int i = 1; i < MaxClients; i++) {
		if (IsClientInGame(i)) OnClientPutInServer(i);
	}
}

public void OnClientPutInServer(int client) {
	Stop(client, false);
	RP_gTimeCuff[client] = 0;
	RP_CuffProtection[client] = false;
}
public void OnClientDisconnect(int client) {
	Stop(client, false);
}

public Action OnEverySecond(Handle timer) {
	for (int i = 1; i < MaxClients; i++) {
		if (IsValidPlayer(i)) {
			if (0 < RP_gCuffTime[i]) {
				if (IsValidPlayer(RP_gCuffTarget[i]) && IsPlayerAlive(RP_gCuffTarget[i])) {
					if (GetEntityFlags(i) & FL_ONGROUND && GetClientButtons(i) & IN_USE && GetDist(i, RP_gCuffTarget[i], radius)) {
						switch (RP_gCuffTime[i]) {
							case 1: Cuff_Player(i, RP_gCuffTarget[i]);
						}
						RP_gCuffTime[i]--;
					} else Stop(i, true);
				} else Stop(i, false);
			}
		}
	}
}

Action Stop(int client, bool typemsg) {
	if (typemsg) {
		int revived = AimTargetPlayer(client);
		if (revived != -1) {
			PrintToChat(client, "Вы прекратили арест \x04%N", RP_gCuffTarget[client]);
			Stop(RP_gCuffTarget[client], false);
		}
	}
	SendProgressBar(client, 0);
	RP_gCuffTime[client] = 0;
	RP_gCuffTarget[client] = 0;
	SetEntityMoveType(client, MOVETYPE_WALK);
	SetEntityMoveType(RP_gCuffTarget[client], MOVETYPE_WALK);
	RP_CuffProtection[client] = false;
	RP_CuffProtection[RP_gCuffTarget[client]] = false;
	return Plugin_Handled;
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon) {
	if (IsValidPlayer(client) && RP_CuffProtection[client]) {
		if (buttons & IN_ATTACK || buttons & IN_ATTACK2) {
			buttons &= ~IN_ATTACK;
			buttons &= ~IN_ATTACK2;
		}
	}
	
	if (RP_gCuffTime[client] > 0
	|| !IsPlayerAlive(client)
	|| !(buttons & IN_USE)
	|| !(GetEntityFlags(client) & FL_ONGROUND)) {
		return Plugin_Continue;
	}
		
	int target = AimTargetPlayer(client);
	for (int revived = 1; revived <= MaxClients; revived++) {
		if (IsClientInGame(revived) && client != revived && target != -1) {
			CuffTarget(client, target, revived);
			break;
		}
	}

	return Plugin_Continue;
}

bool CuffTarget(int client, int target, int revived) {
	if (!GetDist(client, target, radius) || !IsPlayerAlive(target)
	|| !(GetEntityFlags(target) & FL_ONGROUND)) return false;
	
	int realtime_cuff;
	if (((realtime_cuff = GetTime()) - RP_gTimeCuff[client]) < 15){
		PrintHintText(client, "Wait %i's and try again.", (15 - (realtime_cuff - RP_gTimeCuff[client])));
		return false;
	}
	
	RP_gCuffTarget[client] = target;
	RP_gCuffTime[client] = rtime;
	SetEntityMoveType(client, MOVETYPE_NONE);
	SetEntityMoveType(target, MOVETYPE_NONE);
	RP_CuffProtection[client] = true;
	RP_CuffProtection[target] = true;
	
	PrintToChat(client,	"Вы надеваете наручники на \x04%N", target);
	PrintToChat(revived, "На вас надевает наручники \x04%N", client);

	if (rtime > 1) SendProgressBar(client, rtime);
	else Cuff_Player(client, revived);

	return true;
}

void SendProgressBar(int client, int time) {
	SetEntPropFloat(client, Prop_Send, "m_flProgressBarStartTime", 0 < time ? GetGameTime() : 0.0);
	SetEntProp(client, Prop_Send, "m_iProgressBarDuration", 0 < time ? time : 0);
}

void Cuff_Player(int client, int revived = 0) {
	if (revived == 0 || !IsClientInGame(revived) || !IsPlayerAlive(revived) || !IsPlayerAlive(client)) {
		Stop(client, false);
		return;
	}

	Stop(client, false);
	RP_gTimeCuff[client] = GetTime();
	if (RP_Cuff[revived]) {
		RP_Cuff[revived] = false;
		SetEntityRenderColor(revived, 255, 255, 255, 255);
		SetEntityMoveType(revived, MOVETYPE_WALK);
	} else {
		RP_Cuff[revived] = true;
		SetEntityRenderColor(revived, 217, 255, 0, 200);
		SetEntityMoveType(revived, MOVETYPE_WALK);
	}
	RP_CuffProtection[revived] = false;

	PrintToChat(revived, "Вы были арестованы - \x04%N", client);
	PrintToChat(client, "Вы арестовали - \x04%N", revived);
}

bool GetDist(int client, int target, float radiuss) {
	float entitypos[3], clientpos[3];

	GetClientAbsOrigin(target, entitypos);
	GetClientAbsOrigin(client, clientpos);
	
	if (GetVectorDistance(entitypos, clientpos) > radiuss) return false;
	return true;
}