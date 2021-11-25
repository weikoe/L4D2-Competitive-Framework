/*
*
* -Member: m_hActiveWeapon (offset 2100) (type integer) (bits 21)
*
* Sub-Class Table (2 Deep): DT_LocalActiveWeaponData
*-Member: m_flNextPrimaryAttack (offset 1156) (type float) (bits 0)
*-Member: m_flNextSecondaryAttack (offset 1160) (type float) (bits 0)
*
*
* Test 696.716674 697.950012
* Test 700.016723 697.966674

*/

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

int tankCount;

float nextTankPunchAllowed[MAXPLAYERS + 1];

int tankClassIndex;

public Plugin myinfo =
{
	name = "TankDoorFix",
	author = "PP(R)TH: Dr. Gregory House",
	description = "This should at some point fix the case in which the tank misses the door he's supposed to destroy by using his punch",
	version = "1.4.3",
	url = "https://github.com/L4D-Community/L4D2-Competitive-Framework"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	switch (GetEngineVersion())
	{
		case Engine_Left4Dead:
		{
			tankClassIndex = 5;
		}
		case Engine_Left4Dead2:
		{
			tankClassIndex = 8;
		}
		default:
		{
			strcopy(error, err_max, "This plugin only supports L4D(2).");
			return APLRes_SilentFailure;
		}
	}
	return APLRes_Success;
}

public void OnPluginStart()
{
	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
	HookEvent("tank_spawn", Event_TankSpawn);
	HookEvent("player_death", Event_PlayerDeath);
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	if (tankCount > 0)
	{
		if (IsClientInGame(client) && GetClientTeam(client) == 3 && GetEntProp(client, Prop_Send, "m_zombieClass") == tankClassIndex)
		{
			if (buttons & IN_ATTACK)
			{
				int tankweapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");

				if(tankweapon > 0)
				{
					float gameTime = GetGameTime();

					if(GetEntPropFloat(tankweapon, Prop_Send, "m_flTimeWeaponIdle") <= gameTime && nextTankPunchAllowed[client] <= gameTime)
					{
						nextTankPunchAllowed[client] = gameTime + 2.0;

						CreateTimer(1.0, Timer_DoorCheck, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
					}
				}
			}
		}
	}

	return Plugin_Continue;
}

public Action Timer_DoorCheck(Handle timer, int clientUserID)
{
	int client = GetClientOfUserId(clientUserID);

	if (client > 0 && IsClientInGame(client))
	{
		float direction[3];

		int result = IsLookingAtBreakableDoor(client, direction);

		if (result > 0)
		{
			SDKHooks_TakeDamage(result, client, client, 1200.0, DMG_CLUB, _, direction);
		}
	}

	return Plugin_Stop;
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	tankCount = 0;
}

public void Event_TankSpawn(Event event, const char[] name, bool dontBroadcast)
{
	tankCount++;

	nextTankPunchAllowed[GetClientOfUserId(event.GetInt("userid"))] = GetGameTime() + 0.8;
}

public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	if (client > 0 && GetClientTeam(client) == 3 && GetEntProp(client, Prop_Send, "m_zombieClass") == tankClassIndex)
	{
		tankCount--;
	}
}

int IsLookingAtBreakableDoor(int client, float direction[3] = NULL_VECTOR)
{
	int target = GetClientAimTarget(client, false);

	if(target > 0)
	{
		char entName[64];

		if (!GetEntityClassname(target, entName, sizeof(entName)))
		{
			return 0;
		}

		if (strcmp(entName, "prop_door_rotating") == 0)
		{
			//Compare distances, i.e. "is in range to destroy the door"
			float clientPos[3], doorPos[3];

			GetClientAbsOrigin(client, clientPos);
			GetEntPropVector(target, Prop_Send, "m_vecOrigin", doorPos);

			if(GetVectorDistance(clientPos, doorPos, true) <= 8100.0) //90.0
			{
				SubtractVectors(doorPos, clientPos, direction);
				return target;
			}
			else
			{
				return -2;
			}
		}
		else
		{
			return 0;
		}
	}
	else
	{
		return -1;
	}
}
