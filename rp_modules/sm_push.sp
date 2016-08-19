#pragma semicolon 1
#include <roleplay>
#include <sdktools>
#pragma newdecls required
#define MIN_DISTANCE_USE 80
#define cooldown_push 10
#define sound_1 "weapons/knife_push/knife_push_attack1_heavy_01.wav"
#define sound_2 "weapons/knife_push/knife_push_attack1_heavy_02.wav"
#define sound_3 "weapons/knife_push/knife_push_attack1_heavy_03.wav"
#define sound_4 "weapons/knife_push/knife_push_attack1_heavy_04.wav"

int RP_gTime[MAXPLAYERS + 1];

public Plugin gayporno = {
	author = "Hikka",
	name = "Push player",
	description = "Experimental plugin for roleplay",
	version = "0.01",
};

enum VelocityOverride {
	VelocityOvr_None = 0,
	VelocityOvr_Velocity,
	VelocityOvr_OnlyWhenNegative,
	VelocityOvr_InvertReuseVelocity
};

public void OnPluginStart(){
	RegConsoleCmd("sm_push", sm_push, "Push player");
}

public void OnClientPutInServer(int client){
	if (!IsSoundPrecached(sound_1)) PrecacheSound(sound_1, true);
	if (!IsSoundPrecached(sound_2)) PrecacheSound(sound_2, true);
	if (!IsSoundPrecached(sound_3)) PrecacheSound(sound_3, true);
	if (!IsSoundPrecached(sound_4)) PrecacheSound(sound_4, true);
}

public Action sm_push(int client, int args){
	if (client && IsClientInGame(client) && IsPlayerAlive(client)){
		int real_time;
		if (((real_time = GetTime()) - RP_gTime[client]) < cooldown_push){
			PrintToChat(client, "Wait %i's and try again.", (cooldown_push - (real_time - RP_gTime[client])));
			return Plugin_Handled;
		}
		
		int target = AimTargetPlayer(client);
		float origin[3], clientent[3];
		GetClientAbsOrigin(target, origin);
		GetClientAbsOrigin(client, clientent);
		float distance = GetVectorDistance(origin, clientent);
		if (target != -1 && distance <= MIN_DISTANCE_USE){
			float fEyeAngles[3];
			GetClientEyeAngles(client, fEyeAngles);
			fEyeAngles[0] = 0.0;
			PushUp(target, 251.0); // 251.0 - speed; 250.0 - power;
			PushPlayer(target, fEyeAngles, 250.0, view_as<VelocityOverride>{ VelocityOvr_None, VelocityOvr_None, VelocityOvr_None } );
			int sound = GetRandomInt(1, 4);
			switch (sound){
				case 1: {
					//PrecacheSound(sound_1, true);
					EmitSoundToClient(client, sound_1);
				}
				case 2: {
					//PrecacheSound(sound_2, true);
					EmitSoundToClient(client, sound_2);
				}
				case 3: {
					//PrecacheSound(sound_3, true);
					EmitSoundToClient(client, sound_3);
				}
				case 4: {
					//PrecacheSound(sound_4, true);
					EmitSoundToClient(client, sound_4);
				}
			}
			RP_gTime[client] = GetTime();
			PrintToServer("%N pushed %N", client, target);
		}
	}
	return Plugin_Handled;
}

void PushUp(int client, float power){
	PushPlayer(client, view_as<float>{-90.0,0.0,0.0}, power, view_as<VelocityOverride>{ VelocityOvr_None, VelocityOvr_None, VelocityOvr_None } );
}

stock void PushPlayer(int client, float clientEyeAngle[3], float power, VelocityOverride override[3] = VelocityOvr_None){
	float forwardVector[3], newVel[3];
	
	GetAngleVectors(clientEyeAngle, forwardVector, NULL_VECTOR, NULL_VECTOR);
	NormalizeVector(forwardVector, forwardVector);
	ScaleVector(forwardVector, power);
	
	GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", newVel);
	
	for (int i = 0; i < 3; i++){
		switch(override[i]){
			case VelocityOvr_Velocity: newVel[i] = 0.0;
			case VelocityOvr_OnlyWhenNegative: {		
				if (newVel[i] < 0.0){
					newVel[i] = 0.0;
				}
			}
			case VelocityOvr_InvertReuseVelocity: {
				if (newVel[i] < 0.0){
					newVel[i] *= -1.0;
				}
			}
		}
		newVel[i] += forwardVector[i];
	}
	TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, newVel);
}