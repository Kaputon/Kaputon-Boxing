#pragma semicolon 1
#pragma tabsize 0
#pragma newdecls required

#include <sourcemod>
#include <tf2_stocks>
#include <adt_array>
#include <sdkhooks>
#include <sdktools>

//=======================================================//
//=======================================================//
//================== PLUGIN VARIABLES ===================//
//=======================================================//
//=======================================================//

#define PLUGIN_VERSION "0.00"
#define MAX_PLAYERS 32
#define REQ_MAP {"kb_lakeside", "kb_minecraft"}
#define WIN_NUMBER 10
#define MAIN_LOOP_TIME 3.5
#define WIN_SOUND "Passtime.Crowd.Cheer" // Sound which plays when a player wins <WIN_NUMBER> rounds.
#define DASH_SOUND "DisciplineDevice.Impact"
#define DASH_SCALE 1.74 // The scale that your dash is multiplied by.

char RW1[] = "Samurai.Koto";
char RW2[] = "soccer.vuvezela";
char RW3[] = "Duck.Quack";
char RW4[] = "Passtime.Merasmus.Laugh";
char RW5[] = "engineer_mvm_class_is_dead03"; // "Heavy's a goner!"
char RW6[] = "Halloween.BlackCat";

char ENT_CLSNAME_WHITELIST[] = {"tf_ammo_pack" // Medium ammo pack.
};

float g_BoostScale = 1.75; // JUMP boost scale. It is not a <const> for the sake of being able to edit it ingame.

float vec_fSpawn[3]; // First player's spawn worldpos.
float vec_sSpawn[3]; // Second player's spawn worldpos.
float vec_fAngles[3]; // First players spawn view angles.
float vec_sAngles[3]; // Second players spawn view angles.
float vec_Vel[3] = { 0.0, 0.0, 0.0 }; // Both players velocity after teleporting.

bool STARTED = false; // Toggled on when the first round is started.
bool HOOKED[32];	  // bool array which stores if the client has been hooked yet.
bool USED_DJ[32];	  // bool array which stores if the client has used the JUMP in the round.
bool USED_DASH[32];	  // bool array which stores if the client has used the DASH in the round.
int PLAYERS[32];	  // int array which stores all the client integers.
int PLR_SCORES[32];	  // int array which stores each PLAYERS score.
ArrayList QUEUE;	  // Declaration of an ArrayList to be initialized in "OnPluginStart( )".
int FIGHTERS[2];	  // int array that holds the two fighters in the arena.



public Plugin myinfo = {
	name = "Kaputon Boxing", 
	author = "Kaputon", 
	description = "N/A", 
	version = PLUGIN_VERSION, 
	url = ""
};

//=======================================================//
//=======================================================//
//================== CLIENT FUNCTIONS ===================//
//=======================================================//
//=======================================================//

// Determines if a client is valid.
bool IsValidClient(int iClient)
{
    if (iClient <= 0 || iClient > MaxClients || !IsClientInGame(iClient))
    {
        return false;
    }
    if (IsClientSourceTV(iClient) || IsClientReplay(iClient))
    {
        return false;
    }
    return true;
}

// Returns true if the client is a spectator, and false if not.
bool IsClientSpectator(int iClient)
{
	TFTeam iTeam = TF2_GetClientTeam(iClient);
	if (iTeam == TFTeam_Spectator)
	{
		return true;
	}
	return false;
}

// Returns true if the client is in the FIGHTERS table, false if not.
bool IsFighter(int client)
{
	for (int i = 0; i < sizeof(FIGHTERS); i++)
	{
		if (client == FIGHTERS[i])
		{
			return true;
		}
	}
	return false;
}

// Returns true if the client has hit the threshold for winning.
bool ClientWon(int iAttacker)
{
	if (PLR_SCORES[iAttacker] >= WIN_NUMBER)
	{
		return true;
	}
	return false;
}

// Check if we can start the game
int GetPlayers()
{
	int CUMULATOR = 0;
	for (int i = 1; i <= MAXPLAYERS; i++)
	{
		if (IsValidClient(i) && !IsClientSpectator(i))
		{
			CUMULATOR += 1;
		}
	}
	return CUMULATOR;
}

// Forces client to melee only.
void ForceClientMelee(int iClient)
{
	TF2_AddCondition(iClient, TFCond_RestrictToMelee, TFCondDuration_Infinite, 0);
	int melee = GetPlayerWeaponSlot(iClient, TFWeaponSlot_Melee);
	SetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon", melee);
}

// Add a client to the queue.
void AddClientToQueue(int client)
{
	PrintToServer("[SM] QUEUE Length : %d", QUEUE.Length);
	if (QUEUE.Length < 1)
	{
		QUEUE.Push(client);
	}
	else
	{
		QUEUE.ShiftUp(0);
		QUEUE.Set(0, client);
	}
}

// Remove a client from the queue.
void RemoveClientFromQueue(int client)
{
	QUEUE.Erase(QUEUE.FindValue(client));
}


//=======================================================//
//=======================================================//
//============= GAME LOGIC FUNCTIONS ====================//
//=======================================================//
//=======================================================//


// This function finds the 'point_teleport' entities.
// TODO: Add 'point_teleport's to kb_lakeside and completely move off of manual teleportation.
void FindTeleports(char[] MAP)
{
	bool FIRST_FOUND = false;
	
	if (StrEqual(MAP, "kb_lakeside"))
	{
		
		float fSpawn[3] = { 368.891876, 572.114258, -366.968689 }; // First player's spawn worldpos.
		float sSpawn[3] = { -350.0, 572.114258, -366.968689 }; // Second player's spawn worldpos.
		float fAngles[3] = { 5.821329, 179.373764, 0.000000 }; // First players spawn view angles.
		float sAngles[3] = { 1.104859, -0.214165, 0.000000 }; // Second players spawn view angles.
		
		vec_fSpawn = fSpawn;
		vec_sSpawn = sSpawn;
		vec_fAngles = fAngles;
		vec_sAngles = sAngles;
	}
	else
	{
		
		char classname[32]; // Buffer to store entity name in.
		for (int i = 1; i <= GetMaxEntities(); i++) // Iterate through every possible entity
		{
			if (IsValidEdict(i))
			{
				GetEdictClassname(i, classname, sizeof(classname));
				if (StrEqual(classname, "point_teleport")) // If the entity is equal to "point_teleport".
				{ // There are two point_teleport entities, we need to get the vector pos and angle rotation of both and store them.
					if (!FIRST_FOUND) 
					{
						FIRST_FOUND = true;
						GetEntPropVector(i, Prop_Send, "m_vecOrigin", vec_fSpawn);
						GetEntPropVector(i, Prop_Data, "m_angRotation", vec_fAngles);
					}
					else
					{
						GetEntPropVector(i, Prop_Send, "m_vecOrigin", vec_sSpawn);
						GetEntPropVector(i, Prop_Data, "m_angRotation", vec_sAngles);
					}
				}
			}		
		}
	}
}


// Returns the speed of the client to pre-dash speed. 
// (The reason it is a timer is due to the fact that it is always turned off seconds after being activated)
Action Timer_ResetSpeed(Handle timer, int client)
{
	float CURRENT_SPEED = GetEntPropFloat(client, Prop_Data, "m_flMaxspeed");
	SetEntPropFloat(client, Prop_Data, "m_flMaxspeed", (CURRENT_SPEED/DASH_SCALE));
}

// Resets every players double jumps.
void ResetGimmicks()
{
	for (int i = 0; i < sizeof(USED_DJ); i++)
	{
		USED_DJ[i] = false;
		USED_DASH[i] = false;
	}
}

// Restart the Queue.
void RestartQueue()
{
	QUEUE.Clear();
	
	for (int x = 0; x < sizeof(PLAYERS); x++)
	{
		if (IsValidClient(PLAYERS[x]))
		{
			if(QUEUE.Length < 1)
			{
				QUEUE.Push(PLAYERS[x]);
			}
			else
			{
				QUEUE.ShiftUp(0);
				QUEUE.Set(0, PLAYERS[x]);
			}
		}
	}
}

// Plays a random round win sound.
//<iAttacker> : The entity the sound plays from.
void PlayRandomSound(int iAttacker)
{
	int NUM = GetRandomInt(0, 5);
	switch (NUM)
	{
		case 0:
		{
			EmitGameSoundToAll(RW1, iAttacker);
		}
		case 1:
		{
			EmitGameSoundToAll(RW2, iAttacker);
		}
		case 2:
		{
			EmitGameSoundToAll(RW3, iAttacker);
		}
		case 3:
		{
			EmitGameSoundToAll(RW4, iAttacker);
		}
		case 4:
		{
			EmitGameSoundToAll(RW5, iAttacker);
		}
		case 5:
		{
			EmitGameSoundToAll(RW6, iAttacker);
		}
	}
}

// Completely wipe all game data for next match. <iAttacker> for win sound.
void CleanUp(int iAttacker = -1)
{
	FIGHTERS[0] = 0;
	FIGHTERS[1] = 0;
	if (!(iAttacker == -1))
	{
		EmitGameSoundToAll(WIN_SOUND, iAttacker);
		SDKHooks_TakeDamage(iAttacker, 0, 0, 450.0);
		TF2_RespawnPlayer(iAttacker);	
	}
	STARTED = false;
	RestartQueue();
	for (int i = 0; i < sizeof(PLR_SCORES); i++)
	{
		PLR_SCORES[i] = 0;
	}
	CreateTimer(4.0, Timer_Setup, _, TIMER_REPEAT);
}

// Make sure two of the same team players do not battle.
void MixTeams()
{
	if (IsClientSpectator(FIGHTERS[0])) // Make sure our FIGHTERS are not somehow in spectator.
	{
		TF2_ChangeClientTeam(FIGHTERS[0], TFTeam_Red);
	}
	if (IsClientSpectator(FIGHTERS[1]))
	{
		TF2_ChangeClientTeam(FIGHTERS[1], TFTeam_Red);
	}
	
	TFTeam P1 = TF2_GetClientTeam(FIGHTERS[0]);
	TFTeam P2 = TF2_GetClientTeam(FIGHTERS[1]);
	TFTeam OPP;
	int RAND;
	
	if (P1 == P2)
	{
		RAND = GetRandomInt(0, 1); // Get a random team color each time to passively prevent team imbalances.
		if (P1 == TFTeam_Blue)
		{
			OPP = TFTeam_Red;
		}
		if (P1 == TFTeam_Red)
		{
			OPP = TFTeam_Blue;
		}
		SetEntProp(FIGHTERS[RAND], Prop_Send, "m_lifeState", 2); // Set the client's lifestate to "dead" so the client can instantly change class without dying
		TF2_ChangeClientTeam(FIGHTERS[RAND], OPP);
		SetEntProp(FIGHTERS[RAND], Prop_Send, "m_lifeState", 0); // Return the life state to alive.
	}
	
}

// Gather the first two fighters to begin the loop.
void GatherBeginFighters()
{
	bool FIRST_GOT = false;
	int TOP_LENGTH;
	
	for (int i = 0; i < sizeof(FIGHTERS); i++)
	{
		TOP_LENGTH = (QUEUE.Length - 1); // Set this variable to the top of the queue each loop.
		
		if (!FIRST_GOT)
		{
			FIRST_GOT = true;
			FIGHTERS[0] = QUEUE.Get(TOP_LENGTH);
			
		}
		else
		{
			FIGHTERS[1] = QUEUE.Get(TOP_LENGTH);
		}
		
		QUEUE.Erase(TOP_LENGTH); // Erase the top player to send them "out" of the queue.
	}
	
	MixTeams();
}

// Teleport both clients in the 'FIGHTERS' array to the corresponding spots.
// Adjusts entity health and resets game gimmicks as well.
void TeleportFighters()
{
	TeleportEntity(FIGHTERS[0], vec_fSpawn, vec_fAngles, vec_Vel);
	TeleportEntity(FIGHTERS[1], vec_sSpawn, vec_sAngles, vec_Vel);
	
	SetEntityHealth(FIGHTERS[0], 1);
	SetEntityHealth(FIGHTERS[1], 1);
	
	ResetGimmicks();
	
	//PrintToChatAll("[SM] Fighters teleported."); // TODO: Remove when finished.
}

// Debugging function to alter the RELOAD jump properties.
public Action BoostChange(int client, int args)
{
	if (args > 1)
	{
		PrintToConsole(client, "Usage: kb_boost_scale <float>");
		return Plugin_Handled;
	}
	
	char ARG[32];
	
	GetCmdArg(1, ARG, sizeof(ARG));
	
	g_BoostScale = StringToFloat(ARG);
	
	return Plugin_Handled;
}

//=======================================================//
//=======================================================//
//=============== EVENTS/CALLBACKS ======================//
//=======================================================//
//=======================================================//

// Hook Players when they are put in the server.
// This function serves as the client's entry point to the game.
public void OnClientPutInServer(int client)
{	
	AddClientToQueue(client);
	PLAYERS[client] = client;
	HOOKED[client] = true;
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

// Remove all presence of the client upon disconnect.
public void OnClientDisconnect(int client)
{
	RemoveClientFromQueue(client);
	PLAYERS[client] = 0;
	HOOKED[client] = false;
	PLR_SCORES[client] = 0;
}

// Event Hook that fires on class switch.
// This forces the client on to Heavy.
public void Event_PlayerClass(Event event, const char[] name, bool dontBroadcast)
{
	int iClient = GetClientOfUserId(event.GetInt("userid")),
		iClass = event.GetInt("class"); // 5 is Heavy.
	
	if (iClass != 5)
	{
		TF2_SetPlayerClass(iClient, TFClass_Heavy);
	}
}

// Event Hook that fires on client spawn.
// Forces melee and also forces Heavy.
public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int iClient = GetClientOfUserId(event.GetInt("userid"));
	int iClass = event.GetInt("class");
	
	ForceClientMelee(iClient);
	
	if (iClass != 5)
	{
		TF2_SetPlayerClass(iClient, TFClass_Heavy);
	}
}

// Event function that fires when an entity is created.
// This function solely exists to remove ammo boxes and dropped weapons on death.
public void OnEntityCreated(int entity, const char[] classname)
{
	for (int i = 0; i < sizeof(ENT_CLSNAME_WHITELIST); i++) // Any entity placed in the whitelist (I think blacklist is the proper but whatever) gets removed.
	{
		if (StrEqual(classname, ENT_CLSNAME_WHITELIST[i]))
		{
			RemoveEntity(entity);
		}
	}
}

// Event that fires when a player presses anything.
// This function solely exists to incorporate the JUMP and DASH gimmicks.
public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	if (IsFighter(client))
	{
		if ((buttons & IN_ATTACK3) && !USED_DJ[client]) // IN_ATTACK3 is set to middle click by default. Used for MVM Medic shields.
		{
			USED_DJ[client] = true;
			float cVel[3];
			GetEntPropVector(client, Prop_Data, "m_vecVelocity", cVel);
			
			ScaleVector(cVel, g_BoostScale);
			
			cVel[2] += 70.00;
			
			TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, cVel);
		}
		if ((buttons & IN_RELOAD) && !USED_DASH[client])
		{
			USED_DASH[client] = true;
			EmitGameSoundToAll(DASH_SOUND, client);
			float ORIGINAL_SPEED = GetEntPropFloat(client, Prop_Data, "m_flMaxspeed");
			SetEntPropFloat(client, Prop_Data, "m_flMaxspeed", (ORIGINAL_SPEED * DASH_SCALE));
			CreateTimer(0.75, Timer_ResetSpeed, client);
			TF2_AddCondition(client, TFCond_TeleportedGlow, 1.0, 0);
			
		}
	}
}

// Event that fires when a client takes damage.
// This function solely exists to prevent non-FIGHTERS from damaging each other in the spectator booth.
// [ADDED 3-20-22] : Remove Fall Damage
public Action OnTakeDamage(int client, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
	if (damagetype & DMG_FALL) // If damage type is fall damage, ignore it.
	{
		return Plugin_Handled;
	}
	
	for (int i = 0; i < sizeof(FIGHTERS); i++)
	{
		if (client == FIGHTERS[i])
		{
			return Plugin_Continue;
		}
	}
	return Plugin_Handled;
}

// Event that fires when the map is started.
// This function does not do much but it may in the future.
public void OnMapStart()
{
	char MAP_NAME[32];
	GetCurrentMap(MAP_NAME, sizeof(MAP_NAME));
	FindTeleports(MAP_NAME);
}

//=======================================================//
//=======================================================//
//=============== MAIN LOGIC SEQUENCE ===================//
//=======================================================//
//=======================================================//

// OnPluginStart --> Timer_Setup --> Timer_MainLoop --> Wait for Event_PlayerDeath --> Go back to MainLoop//

public void OnPluginStart()
{
	QUEUE = new ArrayList(MAXPLAYERS);
	RegConsoleCmd("kb_boost_scale", BoostChange);
	
	// TODO: Figure out a more efficient way to deal with these sounds.
	PrecacheScriptSound(WIN_SOUND);
	PrecacheScriptSound(RW1);
	PrecacheScriptSound(RW2);
	PrecacheScriptSound(RW3); 
	PrecacheScriptSound(RW4);
	PrecacheScriptSound(RW5);
	PrecacheScriptSound(DASH_SOUND);
	HookEvent("player_changeclass", Event_PlayerClass);
	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("player_spawn", Event_PlayerSpawn);
	PrintToServer("[SM] Heavy Footsies Plugin Loaded.");
	
	for (int i = 1; i <= MAXPLAYERS; i++)
	{
		if (IsValidClient(i))
		{
			OnClientPutInServer(i);
		}
	}
	
	CreateTimer(5.0, Timer_Setup, _ , TIMER_REPEAT);
}

// Beginning timer to set up the game.
// Wait here until we have 2 or more players.
public Action Timer_Setup(Handle timer)
{
	if (GetPlayers() >= 2)
	{
		CreateTimer(MAIN_LOOP_TIME, Timer_MainLoop, _, TIMER_REPEAT);
		return Plugin_Stop;
	}

	return Plugin_Continue;
}

// The Main game loop.
public Action Timer_MainLoop(Handle timer)
{
	int ACTIVE_PLAYERS = GetPlayers();
	
	// Game cannot function without at least 2 people.
	if (ACTIVE_PLAYERS < 2)
	{
		CleanUp();
		CreateTimer(0.5, Timer_Setup, _, TIMER_REPEAT);
		return Plugin_Stop;
	}
	//===//
	
	// If we haven't started. Gather first two fighters.
	if(!STARTED)
	{
		GatherBeginFighters();
		STARTED = true;
	}
	else if (STARTED) // If we have, this function is just gathering a new fighter.
	{
		for (int i = 0; i < sizeof(FIGHTERS); i++)
		{
			if (FIGHTERS[i] == 0)
			{
				FIGHTERS[i] = QUEUE.Get(QUEUE.Length - 1);
				QUEUE.Erase(QUEUE.Length - 1);
			}
		}
	}
	//===//
	
	MixTeams(); // Make sure they are not the same team.
	TeleportFighters(); // Go ahead and teleport our fighters to the arena.
	
	return Plugin_Stop; // Plugin hands reigns over to the Death event.
}

// Event Hook that fires upon player death.
// This event is a main part of the logic and deals with the PLAYER SCORES and PLAYER WIN condition.
public Action Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int iClient = GetClientOfUserId(event.GetInt("userid"));
	int iAttacker;
	
	if (IsFighter(iClient))
	{
		char VIC_NAME[32], ATT_NAME[32];
		
		// This for-loop serves as a 100% guarantee that the attacker and loser are correct.
		for (int i = 0; i < sizeof(FIGHTERS); i++)
		{
			if (FIGHTERS[i] == iClient)
			{
				iClient = FIGHTERS[i];
			}
			if (FIGHTERS[i] != iClient)
			{
				iAttacker = FIGHTERS[i];
			}
		}
		//===//
		
		// Get both loser and winner's names.
		GetClientName(iClient, VIC_NAME, sizeof(VIC_NAME));
		GetClientName(iAttacker, ATT_NAME, sizeof(ATT_NAME));
		PLR_SCORES[iAttacker] += 1;
		//===//
		
		
		// Play the round winning sound and respawn the loser.
		PlayRandomSound(iAttacker);
		TF2_RespawnPlayer(iClient);
		//==//
		
		if (ClientWon(iAttacker))
		{
			PrintHintTextToAll("%s has won by hitting %d wins!", ATT_NAME, WIN_NUMBER);
			CleanUp(iAttacker);
			return Plugin_Handled;
		}
		else
		{
			AddClientToQueue(iClient);
			PrintHintTextToAll("'%s' : %d || '%s' : %d", VIC_NAME, PLR_SCORES[iClient], ATT_NAME, PLR_SCORES[iAttacker]);
			if (FIGHTERS[0] == iClient)// Set the FIGHTERS index to 0 so the next player can be determined.
			{
				FIGHTERS[0] = 0;
			}
			else 
			{
				FIGHTERS[1] = 0;
			}
			CreateTimer(MAIN_LOOP_TIME, Timer_MainLoop); // Hand the program back over to the Main loop.
			return Plugin_Handled;
		}
		
	}
	return Plugin_Handled;
}
