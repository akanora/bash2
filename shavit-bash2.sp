#define TIMER

#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <sdkhooks>

#if defined TIMER
#include <shavit>
#endif

#undef REQUIRE_EXTENSIONS
#include <dhooks>
#include <sendproxy>

#pragma newdecls required

#define BAN_LENGTH "0"
#define IDENTICAL_STRAFE_MIN 20

public Plugin myinfo =
{
	name = "[BASH] (Blacky's Anti-Strafehack)",
	author = "Blacky, edited by carnifex",
	description = "Detects strafe hackers",
	version = "2.0",
	url = "https://github.com/hermansimensen/bash2"
};

// Definitions
#define Button_Forward 0
#define Button_Back    1
#define Button_Left    2
#define Button_Right   3

#define BT_Move 0
#define BT_Key  1

#define Moving_Forward 0
#define Moving_Back    1
#define Moving_Left    2
#define Moving_Right   3

#define Turn_Left 0
#define Turn_Right 1

// Start/End Strafe Data
#define StrafeData_Button 0
#define StrafeData_TurnDirection 1
#define StrafeData_MoveDirection 2
#define StrafeData_Difference 3
#define StrafeData_Tick 4
#define StrafeData_IsTiming 5

// Key switch data
#define KeySwitchData_Button 0
#define KeySwitchData_Difference 1
#define KeySwitchData_IsTiming 2

// Detection reasons
#define DR_StartStrafe_LowDeviation (1 << 0) // < 1.0 very likely strafe hacks (Warn admins)
#define DR_StartStrafe_AlwaysPositive (1 << 1) // Might not be strafe hacking but a good indicator of someone trying to bypass anticheat (Warn admins)
#define DR_EndStrafe_LowDeviation (1 << 2) // < 1.0 very likely strafe hacks (Warn admins)
#define DR_EndStrafe_AlwaysPositive (1 << 3) // Might not be strafe hacking but a good indicator of someone trying to bypass anticheat (Warn admins)
#define DR_StartStrafeMatchesEndStrafe (1 << 4) // A way to catch an angle delay hack (Do nothing)
#define DR_KeySwitchesTooPerfect (1 << 5) // Could be movement config or anti ghosting keyboard (Warn admins)
#define DR_FailedManualAngleTest (1 << 6) // Almost definitely strafe hacking (Ban)
#define DR_ButtonsAndSideMoveDontMatch (1 << 7) // Could be caused by lag but can be made to detect strafe hacks perfectly (Ban/Warn based on severity)
#define DR_ImpossibleSideMove (1 << 8) // Could be +strafe or controller but most likely strafe hack (Warn admins/Stop player movements)
#define DR_FailedManualMOTDTest (1 << 9) // Almost definitely strafe hacking (Ban)
#define DR_AngleDelay (1 << 10) // Player freezes their angles for 1 or more ticks after they press a button until the angle changes again
#define DR_ImpossibleGains (1 << 11) // < 85% probably strafe hacks
#define DR_WiggleHack (1 << 12) // Almost definitely strafe hack. Check for IN_LEFT/IN_RIGHT
#define DR_TurningInfraction (1 << 13) // Client turns at impossible speeds

EngineVersion g_Engine;
int   g_iRealButtons[MAXPLAYERS + 1];
int   g_iButtons[MAXPLAYERS + 1][2];
int   g_iLastButtons[MAXPLAYERS + 1][2];
int   g_iLastPressTick[MAXPLAYERS + 1][4][2];
int   g_iLastPressTick_Recorded[MAXPLAYERS + 1][4][2];
int   g_iLastPressTick_Recorded_KS[MAXPLAYERS + 1][4][2];
int   g_iKeyPressesThisStrafe[MAXPLAYERS + 1][2];
int   g_iLastReleaseTick[MAXPLAYERS + 1][4][2];
int   g_iLastReleaseTick_Recorded[MAXPLAYERS + 1][4][2];
int   g_iLastReleaseTick_Recorded_KS[MAXPLAYERS + 1][4][2];
float g_fLastMove[MAXPLAYERS + 1][3];
int   g_iLastTurnDir[MAXPLAYERS + 1];
int   g_iLastTurnTick[MAXPLAYERS + 1];
int   g_iLastTurnTick_Recorded_StartStrafe[MAXPLAYERS + 1];
int   g_iLastTurnTick_Recorded_EndStrafe[MAXPLAYERS + 1];
int   g_iLastStopTurnTick[MAXPLAYERS + 1];
bool  g_bIsTurning[MAXPLAYERS + 1];
int   g_iReleaseTickAtLastEndStrafe[MAXPLAYERS + 1][4];
float g_fLastAngles[MAXPLAYERS + 1][3];
int   g_InvalidButtonSidemoveCount[MAXPLAYERS + 1];
int   g_iCmdNum[MAXPLAYERS + 1];
float g_fLastPosition[MAXPLAYERS + 1][3];
int   g_iLastTeleportTick[MAXPLAYERS + 1];
float g_fAngleDifference[MAXPLAYERS + 1][2];
float g_fLastAngleDifference[MAXPLAYERS + 1][2];

// Gain calculation
int   g_strafeTick[MAXPLAYERS + 1];
float g_flRawGain[MAXPLAYERS + 1];
bool  g_bTouchesWall[MAXPLAYERS + 1];
int   g_iJump[MAXPLAYERS + 1];
int   g_iTicksOnGround[MAXPLAYERS + 1];
float g_iYawSpeed[MAXPLAYERS + 1];
int   g_iYawTickCount[MAXPLAYERS + 1];
int   g_iTimingTickCount[MAXPLAYERS + 1];
int   g_iStrafesDone[MAXPLAYERS + 1];
bool  g_bFirstSixJumps[MAXPLAYERS + 1];
#define BHOP_TIME 15

// Optimizer detection
bool g_bTouchesFuncRotating[MAXPLAYERS + 1];

// Mouse cvars
float g_mYaw[MAXPLAYERS + 1]; int g_mYawChangedCount[MAXPLAYERS + 1]; int g_mYawCheckedCount[MAXPLAYERS + 1];
bool  g_mFilter[MAXPLAYERS + 1]; int g_mFilterChangedCount[MAXPLAYERS + 1]; int g_mFilterCheckedCount[MAXPLAYERS + 1];
int   g_mCustomAccel[MAXPLAYERS + 1]; int g_mCustomAccelChangedCount[MAXPLAYERS + 1]; int g_mCustomAccelCheckedCount[MAXPLAYERS + 1];
float g_mCustomAccelMax[MAXPLAYERS + 1]; int g_mCustomAccelMaxChangedCount[MAXPLAYERS + 1]; int g_mCustomAccelMaxCheckedCount[MAXPLAYERS + 1];
float g_mCustomAccelScale[MAXPLAYERS + 1]; int g_mCustomAccelScaleChangedCount[MAXPLAYERS + 1]; int g_mCustomAccelScaleCheckedCount[MAXPLAYERS + 1];
float g_mCustomAccelExponent[MAXPLAYERS + 1]; int g_mCustomAccelExponentChangedCount[MAXPLAYERS + 1]; int g_mCustomAccelExponentCheckedCount[MAXPLAYERS + 1];
bool  g_mRawInput[MAXPLAYERS + 1]; int g_mRawInputChangedCount[MAXPLAYERS + 1]; int g_mRawInputCheckedCount[MAXPLAYERS + 1];
float g_Sensitivity[MAXPLAYERS + 1]; int g_SensitivityChangedCount[MAXPLAYERS + 1]; int g_SensitivityCheckedCount[MAXPLAYERS + 1];
float g_JoySensitivity[MAXPLAYERS + 1]; int g_JoySensitivityChangedCount[MAXPLAYERS + 1]; int g_JoySensitivityCheckedCount[MAXPLAYERS + 1];
float g_ZoomSensitivity[MAXPLAYERS + 1]; int g_ZoomSensitivityChangedCount[MAXPLAYERS + 1]; int g_ZoomSensitivityCheckedCount[MAXPLAYERS + 1];
bool  g_JoyStick[MAXPLAYERS + 1]; int g_JoyStickChangedCount[MAXPLAYERS + 1]; int g_JoyStickCheckedCount[MAXPLAYERS + 1];

// Recorded data to analyze
#define MAX_FRAMES 50
#define MAX_FRAMES_KEYSWITCH 50
int   g_iStartStrafe_CurrentFrame[MAXPLAYERS + 1];
any   g_iStartStrafe_Stats[MAXPLAYERS + 1][7][MAX_FRAMES];
int   g_iStartStrafe_LastRecordedTick[MAXPLAYERS + 1];
int   g_iStartStrafe_LastTickDifference[MAXPLAYERS + 1];
bool  g_bStartStrafe_IsRecorded[MAXPLAYERS + 1][MAX_FRAMES];
int   g_iStartStrafe_IdenticalCount[MAXPLAYERS + 1];
int   g_iEndStrafe_CurrentFrame[MAXPLAYERS + 1];
any   g_iEndStrafe_Stats[MAXPLAYERS + 1][7][MAX_FRAMES];
int   g_iEndStrafe_LastRecordedTick[MAXPLAYERS + 1];
int   g_iEndStrafe_LastTickDifference[MAXPLAYERS + 1];
bool  g_bEndStrafe_IsRecorded[MAXPLAYERS + 1][MAX_FRAMES];
int   g_iEndStrafe_IdenticalCount[MAXPLAYERS + 1];
int   g_iKeySwitch_CurrentFrame[MAXPLAYERS + 1][2];
any   g_iKeySwitch_Stats[MAXPLAYERS + 1][3][2][MAX_FRAMES_KEYSWITCH];
bool  g_bKeySwitch_IsRecorded[MAXPLAYERS + 1][2][MAX_FRAMES_KEYSWITCH];
int   g_iKeySwitch_LastRecordedTick[MAXPLAYERS + 1][2];
bool  g_iIllegalTurn[MAXPLAYERS + 1][MAX_FRAMES];
int   g_iIllegalTurn_CurrentFrame[MAXPLAYERS + 1];
bool  g_iIllegalTurn_IsTiming[MAXPLAYERS + 1][MAX_FRAMES];
int   g_iLastIllegalReason[MAXPLAYERS + 1];
int   g_iIllegalSidemoveCount[MAXPLAYERS + 1];
int   g_iLastIllegalSidemoveCount[MAXPLAYERS + 1];
int   g_iLastInvalidButtonCount[MAXPLAYERS + 1];
int   g_iYawChangeCount[MAXPLAYERS + 1];

//bool  g_bTasLoaded;
bool  g_bCheckedYet[MAXPLAYERS + 1];
float g_MOTDTestAngles[MAXPLAYERS + 1][3];
bool  g_bMOTDTest[MAXPLAYERS + 1];
int   g_iTarget[MAXPLAYERS + 1];

// this is like 5600+ bytes xd
enum struct fuck_sourcemod
{
	int accountid;

	int   g_iRealButtons;
	int   g_iButtons[2];
	int   g_iLastButtons[2];

	//int   g_iLastPressTick[4][2];
	int   g_iLastPressTick_0[2];
	int   g_iLastPressTick_1[2];
	int   g_iLastPressTick_2[2];
	int   g_iLastPressTick_3[2];

	//int   g_iLastPressTick_Recorded[4][2];
	int   g_iLastPressTick_Recorded_0[2];
	int   g_iLastPressTick_Recorded_1[2];
	int   g_iLastPressTick_Recorded_2[2];
	int   g_iLastPressTick_Recorded_3[2];

	//int   g_iLastPressTick_Recorded_KS[4][2];
	int   g_iLastPressTick_Recorded_KS_0[2];
	int   g_iLastPressTick_Recorded_KS_1[2];
	int   g_iLastPressTick_Recorded_KS_2[2];
	int   g_iLastPressTick_Recorded_KS_3[2];

	int   g_iKeyPressesThisStrafe[2];

	//int   g_iLastReleaseTick[4][2];
	int   g_iLastReleaseTick_0[2];
	int   g_iLastReleaseTick_1[2];
	int   g_iLastReleaseTick_2[2];
	int   g_iLastReleaseTick_3[2];

	//int   g_iLastReleaseTick_Recorded[4][2];
	int   g_iLastReleaseTick_Recorded_0[2];
	int   g_iLastReleaseTick_Recorded_1[2];
	int   g_iLastReleaseTick_Recorded_2[2];
	int   g_iLastReleaseTick_Recorded_3[2];

	//int   g_iLastReleaseTick_Recorded_KS[4][2];
	int   g_iLastReleaseTick_Recorded_KS_0[2];
	int   g_iLastReleaseTick_Recorded_KS_1[2];
	int   g_iLastReleaseTick_Recorded_KS_2[2];
	int   g_iLastReleaseTick_Recorded_KS_3[2];

	float g_fLastMove[3];
	int   g_iLastTurnDir;
	int   g_iLastTurnTick;
	int   g_iLastTurnTick_Recorded_StartStrafe;
	int   g_iLastTurnTick_Recorded_EndStrafe;
	int   g_iLastStopTurnTick;
	bool  g_bIsTurning;
	int   g_iReleaseTickAtLastEndStrafe[4];
	float g_fLastAngles[3];
	int   g_InvalidButtonSidemoveCount;
	int   g_iCmdNum;
	float g_fLastPosition[3];
	int   g_iLastTeleportTick;
	float g_fAngleDifference[2];
	float g_fLastAngleDifference[2];

	int   g_strafeTick;
	float g_flRawGain;
	bool  g_bTouchesWall;
	int   g_iJump;
	int   g_iTicksOnGround;
	float g_iYawSpeed;
	int   g_iYawTickCount;
	int   g_iTimingTickCount;
	int   g_iStrafesDone;
	bool  g_bFirstSixJumps;

	int   g_iStartStrafe_CurrentFrame;

	//any   g_iStartStrafe_Stats[7][MAX_FRAMES];
	any   g_iStartStrafe_Stats_0[MAX_FRAMES];
	any   g_iStartStrafe_Stats_1[MAX_FRAMES];
	any   g_iStartStrafe_Stats_2[MAX_FRAMES];
	any   g_iStartStrafe_Stats_3[MAX_FRAMES];
	any   g_iStartStrafe_Stats_4[MAX_FRAMES];
	any   g_iStartStrafe_Stats_5[MAX_FRAMES];
	any   g_iStartStrafe_Stats_6[MAX_FRAMES];

	int   g_iStartStrafe_LastRecordedTick;
	int   g_iStartStrafe_LastTickDifference;
	bool  g_bStartStrafe_IsRecorded[MAX_FRAMES];
	int   g_iStartStrafe_IdenticalCount;
	int   g_iEndStrafe_CurrentFrame;

	//any   g_iEndStrafe_Stats[7][MAX_FRAMES];
	any   g_iEndStrafe_Stats_0[MAX_FRAMES];
	any   g_iEndStrafe_Stats_1[MAX_FRAMES];
	any   g_iEndStrafe_Stats_2[MAX_FRAMES];
	any   g_iEndStrafe_Stats_3[MAX_FRAMES];
	any   g_iEndStrafe_Stats_4[MAX_FRAMES];
	any   g_iEndStrafe_Stats_5[MAX_FRAMES];
	any   g_iEndStrafe_Stats_6[MAX_FRAMES];

	int   g_iEndStrafe_LastRecordedTick;
	int   g_iEndStrafe_LastTickDifference;
	bool  g_bEndStrafe_IsRecorded[MAX_FRAMES];
	int   g_iEndStrafe_IdenticalCount;
	int   g_iKeySwitch_CurrentFrame[2];

	//any   g_iKeySwitch_Stats[3][2][MAX_FRAMES_KEYSWITCH];
	any   g_iKeySwitch_Stats_0_0[MAX_FRAMES_KEYSWITCH];
	any   g_iKeySwitch_Stats_0_1[MAX_FRAMES_KEYSWITCH];
	any   g_iKeySwitch_Stats_1_0[MAX_FRAMES_KEYSWITCH];
	any   g_iKeySwitch_Stats_1_1[MAX_FRAMES_KEYSWITCH];
	any   g_iKeySwitch_Stats_2_0[MAX_FRAMES_KEYSWITCH];
	any   g_iKeySwitch_Stats_2_1[MAX_FRAMES_KEYSWITCH];

	//bool  g_bKeySwitch_IsRecorded[2][MAX_FRAMES_KEYSWITCH];
	bool  g_bKeySwitch_IsRecorded_0[MAX_FRAMES_KEYSWITCH];
	bool  g_bKeySwitch_IsRecorded_1[MAX_FRAMES_KEYSWITCH];

	int   g_iKeySwitch_LastRecordedTick[2];
	bool  g_iIllegalTurn[MAX_FRAMES];
	int   g_iIllegalTurn_CurrentFrame;
	bool  g_iIllegalTurn_IsTiming[MAX_FRAMES];
	int   g_iLastIllegalReason;
	int   g_iIllegalSidemoveCount;
	int   g_iLastIllegalSidemoveCount;
	int   g_iLastInvalidButtonCount;
	int   g_iYawChangeCount;
}

bool g_bLateLoad;

Handle g_hTeleport;
bool   g_bDhooksLoaded;
#if defined TIMER
bool   g_bSendProxyLoaded;
#endif

Handle g_fwdOnDetection;
Handle g_fwdOnClientBanned;

ConVar g_hBanLength;
char   g_sBanLength[32];
ConVar g_hAntiNull;
ConVar g_hPrintNullLogs;
ConVar g_hAutoban;
bool g_bAdminMode[MAXPLAYERS + 1];
ConVar g_hQueryRate;
ConVar g_hPersistentData;

char g_aclogfile[PLATFORM_MAX_PATH];
char g_sPlayerIp[MAXPLAYERS + 1][16];

//shavit

#if defined TIMER
stylestrings_t g_sStyleStrings[STYLE_LIMIT];
bool  g_bIsBeingTimed[MAXPLAYERS +1];
#endif

ArrayList g_aPersistentData = null;

public void OnPluginStart()
{
	char sDate[64];
	FormatTime(sDate, sizeof(sDate), "%y%m%d", GetTime());

	BuildPath(Path_SM, g_aclogfile, PLATFORM_MAX_PATH, "logs/ac_%s.txt", sDate);

	UserMsg umVGUIMenu = GetUserMessageId("VGUIMenu");
	if (umVGUIMenu == INVALID_MESSAGE_ID)
		SetFailState("UserMsg `umVGUIMenu` not found!");

	g_hBanLength = CreateConVar("bash_banlength", "0", "Ban length for the automated bans", _, true, 0.0);
	g_hAutoban = CreateConVar("bash_autoban", "1", "Auto ban players who are detected", _, true, 0.0, true, 1.0);
	HookConVarChange(g_hBanLength, OnBanLengthChanged);
	g_hAntiNull = CreateConVar("bash_antinull", "0", "Punish for null movement stats", _, true, 0.0, true, 1.0);
	g_hPrintNullLogs = CreateConVar("bash_print_null_logs", "0", "Should null logs be print to chat?", _, true, 0.0, true, 1.0);
	g_hQueryRate = CreateConVar("bash_query_rate", "0.2", "How often will convars be queried from the client?", _, true, 0.1, true, 2.0);
	g_hPersistentData = CreateConVar("bash_persistent_data", "1", "Whether to save and reload strafe stats on a map for players when they disconnect.\nThis is useful to prevent people from frequently rejoining to wipe their strafe stats.", _, true, 0.0, true, 1.0);
	AutoExecConfig(true, "bash", "sourcemod");

	g_fwdOnDetection = CreateGlobalForward("Bash_OnDetection", ET_Event, Param_Cell, Param_String);
	g_fwdOnClientBanned = CreateGlobalForward("Bash_OnClientBanned", ET_Event, Param_Cell);

	//HookUserMessage(umVGUIMenu, OnVGUIMenu, true);

	g_Engine = GetEngineVersion();
	RegAdminCmd("bash2_stats", Bash_Stats, ADMFLAG_RCON, "Check a player's strafe stats");
	RegAdminCmd("bash2_admin", Bash_AdminMode, ADMFLAG_RCON, "Opt in/out of admin mode (Prints bash info into chat).");
	RegAdminCmd("bash2_test", Bash_Test, ADMFLAG_RCON, "trigger a test message so you can know if webhooks are working :)");

	HookEvent("player_jump", Event_PlayerJump);

	RequestFrame(CheckLag);
}

public void OnConfigsExecuted()
{
	GetConVarString(g_hBanLength, g_sBanLength, sizeof(g_sBanLength));
}

public void OnBanLengthChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	strcopy(g_sBanLength, sizeof(g_sBanLength), newValue);
}

public void OnAllPluginsLoaded()
{
	//g_bTasLoaded = LibraryExists("tas");

	if(g_hTeleport == INVALID_HANDLE && LibraryExists("dhooks"))
	{
		Initialize();
		g_bDhooksLoaded = true;
	}

	#if defined TIMER
	g_bSendProxyLoaded = LibraryExists("sendproxy");
	#endif
}

public void OnLibraryAdded(const char[] name)
{
	if(StrEqual(name, "tas"))
	{
		//g_bTasLoaded = true;
	}
	else if(StrEqual(name, "dhooks") && g_hTeleport == INVALID_HANDLE)
	{
		Initialize();
		g_bDhooksLoaded = true;
	}
	#if defined TIMER
	else if(StrEqual(name, "sendproxy"))
	{
		g_bSendProxyLoaded = true;
	}
	#endif
}

public void OnLibraryRemoved(const char[] name)
{
	if(StrEqual(name, "tas"))
	{
		//g_bTasLoaded = false;
	}
	else if(StrEqual(name, "dhooks"))
	{
		g_bDhooksLoaded = false;
	}
	#if defined TIMER
	else if(StrEqual(name, "sendproxy"))
	{
		g_bSendProxyLoaded = false;
	}
	#endif
}

stock void PrintToAdmins(const char[] msg, any...)
{
	char buffer[300];
	VFormat(buffer, sizeof(buffer), msg, 2);

	for (int i = 1; i <= MaxClients; i++)
	{
		if (CheckCommandAccess(i, "bash2_chat_log", ADMFLAG_RCON))
		{
			if(g_bAdminMode[i]) {
				PrintToChat(i, buffer);
			}
		}
	}
}

void Initialize()
{
	Handle hGameData = LoadGameConfigFile("sdktools.games");
	if(hGameData == INVALID_HANDLE)
		return;

	int iOffset = GameConfGetOffset(hGameData, "Teleport");

	CloseHandle(hGameData);

	if(iOffset == -1)
		return;

	g_hTeleport = DHookCreate(iOffset, HookType_Entity, ReturnType_Void, ThisPointer_CBaseEntity, Hook_DHooks_Teleport);

	if(g_hTeleport == INVALID_HANDLE){
		PrintToServer("\n!! g_hTeleport -> INVALID_HANDLE !!\n");
		return;
	}

	DHookAddParam(g_hTeleport, HookParamType_VectorPtr);
	DHookAddParam(g_hTeleport, HookParamType_ObjectPtr);
	DHookAddParam(g_hTeleport, HookParamType_VectorPtr);

	if(g_Engine == Engine_CSGO)
		DHookAddParam(g_hTeleport, HookParamType_Bool); // CS:GO only
}

public MRESReturn Hook_DHooks_Teleport(int client, Handle hParams)
{
	if(!IsClientConnected(client) || IsFakeClient(client) || !IsPlayerAlive(client))
		return MRES_Ignored;

	g_iLastTeleportTick[client] = g_iCmdNum[client];

	return MRES_Ignored;
}

void AutoBanPlayer(int client)
{
	if(g_hAutoban.BoolValue && IsClientInGame(client) && !IsClientInKickQueue(client))
	{
		ServerCommand("sm_ban #%d %s Cheating", GetClientUserId(client), g_sBanLength);

		Call_StartForward(g_fwdOnClientBanned);
		Call_PushCell(client);
		Call_Finish();
	}
}

float g_fLag_LastCheckTime;
//float g_fLastLagTime;

public void CheckLag(any data)
{
	if(GetEngineTime() - g_fLag_LastCheckTime > 0.02)
	{
		//g_fLastLagTime = GetEngineTime();
	}

	g_fLag_LastCheckTime = GetEngineTime();

	RequestFrame(CheckLag);
}

void SaveOldLogs()
{
	char sDate[64];
	FormatTime(sDate, sizeof(sDate), "%y%m%d", GetTime() - (60 * 60 * 24)); // Save logs from day before to new file
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "logs/ac_%s.txt", sDate);

	if(!FileExists(sPath))
	{
		return;
	}

	char sNewPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sNewPath, sizeof(sNewPath), "logs/bash.txt");

	File hOld = OpenFile(sPath, "r");
	File hNew = OpenFile(sNewPath, "a");

	if(hOld == INVALID_HANDLE)
	{
		LogError("Couldn't open '%s'", sPath);
		return;
	}

	if(hNew == INVALID_HANDLE)
	{
		LogError("Couldn't open '%s'", sNewPath);
		return;
	}

	char sDateFormatted[64];
	FormatTime(sDateFormatted, sizeof(sDateFormatted), "%y-%m-%d", GetTime() - (60 * 60 * 24));
	WriteFileLine(hNew, "\n***** ------------ Logs from %s ------------ *****", sDateFormatted);

	char sLine[256];
	while(!IsEndOfFile(hOld))
	{
		if(ReadFileLine(hOld, sLine, sizeof(sLine)))
		{
			ReplaceString(sLine, sizeof(sLine), "\n", "");
			WriteFileLine(hNew, sLine);
		}
	}

	delete hOld;
	delete hNew;
	DeleteFile(sPath);
}

stock bool AnticheatLog(int client, const char[] log, any ...)
{
	char buffer[1024];
	VFormat(buffer, sizeof(buffer), log, 3);

	Call_StartForward(g_fwdOnDetection);
	Call_PushCell(client);
	Call_PushString(buffer);
	Call_Finish();

	LogToFile(g_aclogfile, "%L<%s> %s", client, g_sPlayerIp[client], buffer);

	if (!g_hPrintNullLogs.BoolValue && StrContains(buffer, "nullPct") != -1)
	{
		return;
	}

	PrintToAdmins("%N %s", client, buffer);
}

public Action Event_PlayerJump(Event event, const char[] name, bool dontBroadcast)
{
	int iclient = GetClientOfUserId(GetEventInt(event, "userid"));

	if(++g_iJump[iclient] == 6)
	{
		float gainPct = GetGainPercent(iclient);
		float yawPct = (float(g_iYawTickCount[iclient]) / float(g_strafeTick[iclient])) * 100.0;
		float timingPct = (float(g_iTimingTickCount[iclient]) / float(g_strafeTick[iclient])) * 100.0;

		float spj;
		if(g_bFirstSixJumps[iclient])
			spj = g_iStrafesDone[iclient] / 5.0;
		else
			spj = g_iStrafesDone[iclient] / 6.0;

		if(g_strafeTick[iclient] > 300)
		{
			if(gainPct > 85.0 && yawPct < 60.0)
			{
				AnticheatLog(iclient, "has %.2f％ gains (Yawing %.1f％, Timing: %.1f％, SPJ: %.1f)", gainPct, yawPct, timingPct, spj);

				if(gainPct == 100.0 && timingPct == 100.0)
				{
					AutoBanPlayer(iclient);
				}
			}
		}

		g_iJump[iclient] = 0;
		g_flRawGain[iclient] = 0.0;
		g_strafeTick[iclient] = 0;
		g_iYawTickCount[iclient] = 0;
		g_iTimingTickCount[iclient] = 0;
		g_iStrafesDone[iclient] = 0;
		g_bFirstSixJumps[iclient] = false;
	}
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	RegPluginLibrary("shavit-bash2");

	g_bLateLoad = late;

	return APLRes_Success;
}

public Action OnVGUIMenu(UserMsg msg_id, Protobuf msg, const int[] players, int playersNum, bool reliable, bool init)
{
	int iclient = players[0];

	if(g_bMOTDTest[iclient])
	{
		GetClientEyeAngles(iclient, g_MOTDTestAngles[iclient]);
		CreateTimer(0.1, Timer_MOTD, GetClientUserId(iclient));
	}
}

public Action Timer_MOTD(Handle timer, any data)
{
	int iclient = GetClientOfUserId(data);

	if(iclient != 0)
	{
		float vAng[3];
		GetClientEyeAngles(iclient, vAng);
		if(FloatAbs(g_MOTDTestAngles[iclient][1] - vAng[1]) > 50.0)
		{
			PrintToAdmins("%N is strafe hacking", iclient);
		}
		g_bMOTDTest[iclient] = false;
	}
}

public void OnMapStart()
{
	delete g_aPersistentData;
	g_aPersistentData = new ArrayList(sizeof(fuck_sourcemod));

	CreateTimer(g_hQueryRate.FloatValue, Timer_UpdateYaw, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);

	if(g_bLateLoad)
	{
		for(int iclient = 1; iclient <= MaxClients; iclient++)
		{
			if(IsClientInGame(iclient))
			{
				OnClientConnected(iclient);
				OnClientPutInServer(iclient);
			}
		}
	}

	SaveOldLogs();
}

public Action Timer_UpdateYaw(Handle timer, any data)
{
	for(int iclient = 1; iclient <= MaxClients; iclient++)
	{
		if(IsClientInGame(iclient) && !IsFakeClient(iclient))
		{
			QueryForCvars(iclient);
		}
	}
}

public void OnClientConnected(int client)
{
	if(IsFakeClient(client))
		return;

	GetClientIP(client, g_sPlayerIp[client], 16);

	for(int idx; idx < MAX_FRAMES; idx++)
	{
		g_bStartStrafe_IsRecorded[client][idx]         = false;
		g_bEndStrafe_IsRecorded[client][idx]           = false;
	}

	for(int idx; idx < MAX_FRAMES_KEYSWITCH; idx++)
	{
		g_bKeySwitch_IsRecorded[client][BT_Key][idx]   = false;
		g_bKeySwitch_IsRecorded[client][BT_Move][idx]  = false;
	}

	g_iStartStrafe_CurrentFrame[client]        = 0;
	g_iEndStrafe_CurrentFrame[client]          = 0;
	g_iKeySwitch_CurrentFrame[client][BT_Key]  = 0;
	g_iKeySwitch_CurrentFrame[client][BT_Move] = 0;
	g_bCheckedYet[client] = false;
	g_iStartStrafe_LastTickDifference[client] = 0;
	g_iEndStrafe_LastTickDifference[client] = 0;
	g_iStartStrafe_IdenticalCount[client] = 0;
	g_iEndStrafe_IdenticalCount[client]   = 0;

	g_iYawSpeed[client] = 210.0;
	g_mYaw[client] = 0.0;
	g_mYawChangedCount[client] = 0;
	g_mYawCheckedCount[client] = 0;
	g_mFilter[client] = false;
	g_mFilterChangedCount[client] = 0;
	g_mFilterCheckedCount[client] = 0;
	g_mRawInput[client] = true;
	g_mRawInputChangedCount[client] = 0;
	g_mRawInputCheckedCount[client] = 0;
	g_mCustomAccel[client] = 0;
	g_mCustomAccelChangedCount[client] = 0;
	g_mCustomAccelCheckedCount[client] = 0;
	g_mCustomAccelMax[client] = 0.0;
	g_mCustomAccelMaxChangedCount[client] = 0;
	g_mCustomAccelMaxCheckedCount[client] = 0;
	g_mCustomAccelScale[client] = 0.0;
	g_mCustomAccelScaleChangedCount[client] = 0;
	g_mCustomAccelScaleCheckedCount[client] = 0;
	g_mCustomAccelExponent[client] = 0.0;
	g_mCustomAccelExponentChangedCount[client] = 0;
	g_mCustomAccelExponentCheckedCount[client] = 0;
	g_Sensitivity[client] = 0.0;
	g_SensitivityChangedCount[client] = 0;
	g_SensitivityCheckedCount[client] = 0;
	g_JoySensitivity[client] = 0.0;
	g_JoySensitivityChangedCount[client] = 0;
	g_JoySensitivityCheckedCount[client] = 0;
	g_ZoomSensitivity[client] = 0.0;
	g_ZoomSensitivityChangedCount[client] = 0;
	g_ZoomSensitivityCheckedCount[client] = 0;

	g_iLastInvalidButtonCount[client] = 0;

	g_JoyStick[client] = false;
	g_JoyStickChangedCount[client] = 0;
}

public void OnClientPostAdminCheck(int client)
{
	if (CheckCommandAccess(client, "bash2_chat_log", ADMFLAG_RCON))
	{
		g_bAdminMode[client] = true;
	}

	if(IsFakeClient(client))
		return;

	if (!g_hPersistentData.BoolValue)
		return;

	int index = g_aPersistentData.FindValue(GetSteamAccountID(client));

	if (index != -1)
	{
		fuck_sourcemod x;
		g_aPersistentData.GetArray(index, x);
		g_aPersistentData.Erase(index);

		g_iRealButtons[client] = x.g_iRealButtons;
		g_iButtons[client] = x.g_iButtons;
		g_iLastButtons[client] = x.g_iLastButtons;

		g_iLastPressTick[client][0] = x.g_iLastPressTick_0;
		g_iLastPressTick[client][1] = x.g_iLastPressTick_1;
		g_iLastPressTick[client][2] = x.g_iLastPressTick_2;
		g_iLastPressTick[client][3] = x.g_iLastPressTick_3;

		g_iLastPressTick_Recorded[client][0] = x.g_iLastPressTick_Recorded_0;
		g_iLastPressTick_Recorded[client][1] = x.g_iLastPressTick_Recorded_1;
		g_iLastPressTick_Recorded[client][2] = x.g_iLastPressTick_Recorded_2;
		g_iLastPressTick_Recorded[client][3] = x.g_iLastPressTick_Recorded_3;

		g_iLastPressTick_Recorded_KS[client][0] = x.g_iLastPressTick_Recorded_KS_0;
		g_iLastPressTick_Recorded_KS[client][1] = x.g_iLastPressTick_Recorded_KS_1;
		g_iLastPressTick_Recorded_KS[client][3] = x.g_iLastPressTick_Recorded_KS_2;
		g_iLastPressTick_Recorded_KS[client][3] = x.g_iLastPressTick_Recorded_KS_3;

		g_iKeyPressesThisStrafe[client] = x.g_iKeyPressesThisStrafe;

		g_iLastReleaseTick[client][0] = x.g_iLastReleaseTick_0;
		g_iLastReleaseTick[client][1] = x.g_iLastReleaseTick_1;
		g_iLastReleaseTick[client][2] = x.g_iLastReleaseTick_2;
		g_iLastReleaseTick[client][3] = x.g_iLastReleaseTick_3;

		g_iLastReleaseTick_Recorded[client][0] = x.g_iLastReleaseTick_Recorded_0;
		g_iLastReleaseTick_Recorded[client][1] = x.g_iLastReleaseTick_Recorded_1;
		g_iLastReleaseTick_Recorded[client][2] = x.g_iLastReleaseTick_Recorded_2;
		g_iLastReleaseTick_Recorded[client][3] = x.g_iLastReleaseTick_Recorded_3;

		g_iLastReleaseTick_Recorded_KS[client][0] = x.g_iLastReleaseTick_Recorded_KS_0;
		g_iLastReleaseTick_Recorded_KS[client][1] = x.g_iLastReleaseTick_Recorded_KS_1;
		g_iLastReleaseTick_Recorded_KS[client][2] = x.g_iLastReleaseTick_Recorded_KS_2;
		g_iLastReleaseTick_Recorded_KS[client][3] = x.g_iLastReleaseTick_Recorded_KS_3;

		g_fLastMove[client] = x.g_fLastMove;
		g_iLastTurnDir[client] = x.g_iLastTurnDir;
		g_iLastTurnTick[client] = x.g_iLastTurnTick;
		g_iLastTurnTick_Recorded_StartStrafe[client] = x.g_iLastTurnTick_Recorded_StartStrafe;
		g_iLastTurnTick_Recorded_EndStrafe[client] = x.g_iLastTurnTick_Recorded_EndStrafe;
		g_iLastStopTurnTick[client] = x.g_iLastStopTurnTick;
		//g_bIsTurning[client] = x.g_bIsTurning;
		g_iReleaseTickAtLastEndStrafe[client] = x.g_iReleaseTickAtLastEndStrafe;
		g_fLastAngles[client] = x.g_fLastAngles;
		g_InvalidButtonSidemoveCount[client] = x.g_InvalidButtonSidemoveCount;
		g_iCmdNum[client] = x.g_iCmdNum;
		g_fLastPosition[client] = x.g_fLastPosition;
		//g_iLastTeleportTick[client] = x.g_iLastTeleportTick;
		g_fAngleDifference[client] = x.g_fAngleDifference;
		g_fLastAngleDifference[client] = x.g_fLastAngleDifference;

		g_strafeTick[client] = x.g_strafeTick;
		g_flRawGain[client] = x.g_flRawGain;
		g_bTouchesWall[client] = x.g_bTouchesWall;
		g_iJump[client] = x.g_iJump;
		g_iTicksOnGround[client] = x.g_iTicksOnGround;
		g_iYawSpeed[client] = x.g_iYawSpeed;
		g_iYawTickCount[client] = x.g_iYawTickCount;
		g_iTimingTickCount[client] = x.g_iTimingTickCount;
		g_iStrafesDone[client] = x.g_iStrafesDone;
		g_bFirstSixJumps[client] = x.g_bFirstSixJumps;

		g_iStartStrafe_CurrentFrame[client] = x.g_iStartStrafe_CurrentFrame;

		g_iStartStrafe_Stats[client][0] = x.g_iStartStrafe_Stats_0;
		g_iStartStrafe_Stats[client][1] = x.g_iStartStrafe_Stats_1;
		g_iStartStrafe_Stats[client][2] = x.g_iStartStrafe_Stats_2;
		g_iStartStrafe_Stats[client][3] = x.g_iStartStrafe_Stats_3;
		g_iStartStrafe_Stats[client][4] = x.g_iStartStrafe_Stats_4;
		g_iStartStrafe_Stats[client][5] = x.g_iStartStrafe_Stats_5;
		g_iStartStrafe_Stats[client][6] = x.g_iStartStrafe_Stats_6;

		g_iStartStrafe_LastRecordedTick[client] = x.g_iStartStrafe_LastRecordedTick;
		g_iStartStrafe_LastTickDifference[client] = x.g_iStartStrafe_LastTickDifference;
		g_bStartStrafe_IsRecorded[client] = x.g_bStartStrafe_IsRecorded;
		g_iStartStrafe_IdenticalCount[client] = x.g_iStartStrafe_IdenticalCount;

		g_iEndStrafe_CurrentFrame[client] = x.g_iEndStrafe_CurrentFrame;

		g_iEndStrafe_Stats[client][0] = x.g_iEndStrafe_Stats_0;
		g_iEndStrafe_Stats[client][1] = x.g_iEndStrafe_Stats_1;
		g_iEndStrafe_Stats[client][2] = x.g_iEndStrafe_Stats_2;
		g_iEndStrafe_Stats[client][3] = x.g_iEndStrafe_Stats_3;
		g_iEndStrafe_Stats[client][4] = x.g_iEndStrafe_Stats_4;
		g_iEndStrafe_Stats[client][5] = x.g_iEndStrafe_Stats_5;
		g_iEndStrafe_Stats[client][6] = x.g_iEndStrafe_Stats_6;

		g_iEndStrafe_LastRecordedTick[client] = x.g_iEndStrafe_LastRecordedTick;
		g_iEndStrafe_LastTickDifference[client] = x.g_iEndStrafe_LastTickDifference;
		g_bEndStrafe_IsRecorded[client] = x.g_bEndStrafe_IsRecorded;
		g_iEndStrafe_IdenticalCount[client] = x.g_iEndStrafe_IdenticalCount;
		g_iKeySwitch_CurrentFrame[client] = x.g_iKeySwitch_CurrentFrame;

		g_iKeySwitch_Stats[client][0][0] = x.g_iKeySwitch_Stats_0_0;
		g_iKeySwitch_Stats[client][0][1] = x.g_iKeySwitch_Stats_0_1;
		g_iKeySwitch_Stats[client][1][0] = x.g_iKeySwitch_Stats_1_0;
		g_iKeySwitch_Stats[client][1][1] = x.g_iKeySwitch_Stats_1_1;
		g_iKeySwitch_Stats[client][2][0] = x.g_iKeySwitch_Stats_2_0;
		g_iKeySwitch_Stats[client][2][1] = x.g_iKeySwitch_Stats_2_1;

		g_bKeySwitch_IsRecorded[client][0] = x.g_bKeySwitch_IsRecorded_0;
		g_bKeySwitch_IsRecorded[client][1] = x.g_bKeySwitch_IsRecorded_1;

		g_iKeySwitch_LastRecordedTick[client] = x.g_iKeySwitch_LastRecordedTick;
		g_iIllegalTurn[client] = x.g_iIllegalTurn;
		g_iIllegalTurn_CurrentFrame[client] = x.g_iIllegalTurn_CurrentFrame;
		g_iIllegalTurn_IsTiming[client] = x.g_iIllegalTurn_IsTiming;
		g_iLastIllegalReason[client] = x.g_iLastIllegalReason;
		g_iIllegalSidemoveCount[client] = x.g_iIllegalSidemoveCount;
		g_iLastIllegalSidemoveCount[client] = x.g_iLastIllegalSidemoveCount;
		g_iLastInvalidButtonCount[client] = x.g_iLastInvalidButtonCount;
		g_iYawChangeCount[client] = x.g_iYawChangeCount;
	}
}

public void OnClientPutInServer(int client)
{
	if(IsFakeClient(client) || !IsClientInGame(client))
		return;

	SDKHook(client, SDKHook_Touch, Hook_OnTouch);

	if(g_bDhooksLoaded)
	{
		DHookEntity(g_hTeleport, false, client);
	}

	#if defined TIMER
	if(g_bSendProxyLoaded)
	{
		SendProxy_Hook(client, "m_fFlags", Prop_Int, Hook_GroundFlags);
	}
	#endif

	QueryForCvars(client);
}

public void OnClientDisconnect(int client)
{
	if (GetSteamAccountID(client) != 0 && g_hPersistentData.BoolValue)
	{
		fuck_sourcemod x;
		x.accountid = GetSteamAccountID(client);

		x.g_iRealButtons = g_iRealButtons[client];
		x.g_iButtons = g_iButtons[client];
		x.g_iLastButtons = g_iButtons[client];

		x.g_iLastPressTick_0 = g_iLastPressTick[client][0];
		x.g_iLastPressTick_1 = g_iLastPressTick[client][1];
		x.g_iLastPressTick_2 = g_iLastPressTick[client][2];
		x.g_iLastPressTick_3 = g_iLastPressTick[client][3];

		x.g_iLastPressTick_Recorded_0 = g_iLastPressTick_Recorded[client][0];
		x.g_iLastPressTick_Recorded_1 = g_iLastPressTick_Recorded[client][1];
		x.g_iLastPressTick_Recorded_2 = g_iLastPressTick_Recorded[client][2];
		x.g_iLastPressTick_Recorded_3 = g_iLastPressTick_Recorded[client][3];

		x.g_iLastPressTick_Recorded_KS_0 = g_iLastPressTick_Recorded_KS[client][0];
		x.g_iLastPressTick_Recorded_KS_1 = g_iLastPressTick_Recorded_KS[client][1];
		x.g_iLastPressTick_Recorded_KS_2 = g_iLastPressTick_Recorded_KS[client][2];
		x.g_iLastPressTick_Recorded_KS_3 = g_iLastPressTick_Recorded_KS[client][3];

		x.g_iKeyPressesThisStrafe = g_iKeyPressesThisStrafe[client];

		x.g_iLastReleaseTick_0 = g_iLastReleaseTick[client][0];
		x.g_iLastReleaseTick_1 = g_iLastReleaseTick[client][1];
		x.g_iLastReleaseTick_2 = g_iLastReleaseTick[client][2];
		x.g_iLastReleaseTick_3 = g_iLastReleaseTick[client][3];

		x.g_iLastReleaseTick_Recorded_0 = g_iLastReleaseTick_Recorded[client][0];
		x.g_iLastReleaseTick_Recorded_1 = g_iLastReleaseTick_Recorded[client][1];
		x.g_iLastReleaseTick_Recorded_2 = g_iLastReleaseTick_Recorded[client][2];
		x.g_iLastReleaseTick_Recorded_3 = g_iLastReleaseTick_Recorded[client][3];

		x.g_iLastReleaseTick_Recorded_KS_0 = g_iLastReleaseTick_Recorded_KS[client][0];
		x.g_iLastReleaseTick_Recorded_KS_1 = g_iLastReleaseTick_Recorded_KS[client][1];
		x.g_iLastReleaseTick_Recorded_KS_2 = g_iLastReleaseTick_Recorded_KS[client][2];
		x.g_iLastReleaseTick_Recorded_KS_3 = g_iLastReleaseTick_Recorded_KS[client][3];

		x.g_fLastMove = g_fLastMove[client];
		x.g_iLastTurnDir = g_iLastTurnDir[client];
		x.g_iLastTurnTick = g_iLastTurnTick[client];
		x.g_iLastTurnTick_Recorded_StartStrafe = g_iLastTurnTick_Recorded_StartStrafe[client];
		x.g_iLastTurnTick_Recorded_EndStrafe = g_iLastTurnTick_Recorded_EndStrafe[client];
		x.g_iLastStopTurnTick = g_iLastStopTurnTick[client];
		x.g_bIsTurning = g_bIsTurning[client];
		x.g_iReleaseTickAtLastEndStrafe = g_iReleaseTickAtLastEndStrafe[client];
		x.g_fLastAngles = g_fLastAngles[client];
		x.g_InvalidButtonSidemoveCount = g_InvalidButtonSidemoveCount[client];
		x.g_iCmdNum = g_iCmdNum[client];
		x.g_fLastPosition = g_fLastPosition[client];
		x.g_iLastTeleportTick = g_iLastTeleportTick[client];
		x.g_fAngleDifference = g_fAngleDifference[client];
		x.g_fLastAngleDifference = g_fLastAngleDifference[client];

		x.g_strafeTick = g_strafeTick[client];
		x.g_flRawGain = g_flRawGain[client];
		x.g_bTouchesWall = g_bTouchesWall[client];
		x.g_iJump = g_iJump[client];
		x.g_iTicksOnGround = g_iTicksOnGround[client];
		x.g_iYawSpeed = g_iYawSpeed[client];
		x.g_iYawTickCount = g_iYawTickCount[client];
		x.g_iTimingTickCount = g_iTimingTickCount[client];
		x.g_iStrafesDone = g_iStrafesDone[client];
		x.g_bFirstSixJumps = g_bFirstSixJumps[client];

		x.g_iStartStrafe_CurrentFrame = g_iStartStrafe_CurrentFrame[client];

		x.g_iStartStrafe_Stats_0 = g_iStartStrafe_Stats[client][0];
		x.g_iStartStrafe_Stats_1 = g_iStartStrafe_Stats[client][1];
		x.g_iStartStrafe_Stats_2 = g_iStartStrafe_Stats[client][2];
		x.g_iStartStrafe_Stats_3 = g_iStartStrafe_Stats[client][3];
		x.g_iStartStrafe_Stats_4 = g_iStartStrafe_Stats[client][4];
		x.g_iStartStrafe_Stats_5 = g_iStartStrafe_Stats[client][5];
		x.g_iStartStrafe_Stats_6 = g_iStartStrafe_Stats[client][6];

		x.g_iStartStrafe_LastRecordedTick = g_iStartStrafe_LastRecordedTick[client];
		x.g_iStartStrafe_LastTickDifference = g_iStartStrafe_LastTickDifference[client];
		x.g_bStartStrafe_IsRecorded = g_bStartStrafe_IsRecorded[client];
		x.g_iStartStrafe_IdenticalCount = g_iStartStrafe_IdenticalCount[client];

		x.g_iEndStrafe_CurrentFrame = g_iEndStrafe_CurrentFrame[client];

		x.g_iEndStrafe_Stats_0 = g_iEndStrafe_Stats[client][0];
		x.g_iEndStrafe_Stats_1 = g_iEndStrafe_Stats[client][1];
		x.g_iEndStrafe_Stats_2 = g_iEndStrafe_Stats[client][2];
		x.g_iEndStrafe_Stats_3 = g_iEndStrafe_Stats[client][3];
		x.g_iEndStrafe_Stats_4 = g_iEndStrafe_Stats[client][4];
		x.g_iEndStrafe_Stats_5 = g_iEndStrafe_Stats[client][5];
		x.g_iEndStrafe_Stats_6 = g_iEndStrafe_Stats[client][6];

		x.g_iEndStrafe_LastRecordedTick = g_iEndStrafe_LastRecordedTick[client];
		x.g_iEndStrafe_LastTickDifference = g_iEndStrafe_LastTickDifference[client];
		x.g_bEndStrafe_IsRecorded = g_bEndStrafe_IsRecorded[client];
		x.g_iEndStrafe_IdenticalCount = g_iEndStrafe_IdenticalCount[client];
		x.g_iKeySwitch_CurrentFrame = g_iKeySwitch_CurrentFrame[client];

		x.g_iKeySwitch_Stats_0_0 = g_iKeySwitch_Stats[client][0][0];
		x.g_iKeySwitch_Stats_0_1 = g_iKeySwitch_Stats[client][0][1];
		x.g_iKeySwitch_Stats_1_0 = g_iKeySwitch_Stats[client][1][0];
		x.g_iKeySwitch_Stats_1_1 = g_iKeySwitch_Stats[client][1][1];
		x.g_iKeySwitch_Stats_2_0 = g_iKeySwitch_Stats[client][2][0];
		x.g_iKeySwitch_Stats_2_1 = g_iKeySwitch_Stats[client][2][1];

		x.g_bKeySwitch_IsRecorded_0 = g_bKeySwitch_IsRecorded[client][0];
		x.g_bKeySwitch_IsRecorded_1 = g_bKeySwitch_IsRecorded[client][1];

		x.g_iKeySwitch_LastRecordedTick = g_iKeySwitch_LastRecordedTick[client];
		x.g_iIllegalTurn = g_iIllegalTurn[client];
		x.g_iIllegalTurn_CurrentFrame = g_iIllegalTurn_CurrentFrame[client];
		x.g_iIllegalTurn_IsTiming = g_iIllegalTurn_IsTiming[client];
		x.g_iLastIllegalReason = g_iLastIllegalReason[client];
		x.g_iIllegalSidemoveCount = g_iIllegalSidemoveCount[client];
		x.g_iLastIllegalSidemoveCount = g_iLastIllegalSidemoveCount[client];
		x.g_iLastInvalidButtonCount = g_iLastInvalidButtonCount[client];
		x.g_iYawChangeCount = g_iYawChangeCount[client];

		g_aPersistentData.PushArray(x);
	}
}

public Action Hook_GroundFlags(int entity, const char[] PropName, int &iValue, int element)
{
	#if defined TIMER
	int style = Shavit_GetBhopStyle(entity);
	bool autobhop = Shavit_GetStyleSettingBool(style, "autobhop");

	if(autobhop == false)
		iValue &= ~FL_ONGROUND;

	return Plugin_Changed;
	#endif
}


void QueryForCvars(int client)
{
	if(g_Engine == Engine_CSS) QueryClientConVar(client, "cl_yawspeed", OnYawSpeedRetrieved);
	QueryClientConVar(client, "m_yaw", OnYawRetrieved);
	QueryClientConVar(client, "m_filter", OnFilterRetrieved);
	QueryClientConVar(client, "m_customaccel", OnCustomAccelRetrieved);
	QueryClientConVar(client, "m_customaccel_max", OnCustomAccelMaxRetrieved);
	QueryClientConVar(client, "m_customaccel_scale", OnCustomAccelScaleRetrieved);
	QueryClientConVar(client, "m_customaccel_exponent", OnCustomAccelExRetrieved);
	QueryClientConVar(client, "m_rawinput", OnRawInputRetrieved);
	QueryClientConVar(client, "sensitivity", OnSensitivityRetrieved);
	QueryClientConVar(client, "joy_yawsensitivity", OnYawSensitivityRetrieved);
	QueryClientConVar(client, "joystick", OnJoystickRetrieved);
	if(g_Engine == Engine_CSGO) QueryClientConVar(client, "zoom_sensitivity_ratio_mouse", OnZoomSensitivityRetrieved);
	if(g_Engine == Engine_CSS) QueryClientConVar(client, "zoom_sensitivity_ratio", OnZoomSensitivityRetrieved);
}

public void OnYawSpeedRetrieved(QueryCookie cookie, int client, ConVarQueryResult result, const char[] cvarName, const char[] cvarValue)
{
	g_iYawSpeed[client] = StringToFloat(cvarValue);

	if(g_iYawSpeed[client] < 0)
	{
		KickClient(client, "cl_yawspeed cannot be negative");
	}
}

public void OnYawRetrieved(QueryCookie cookie, int client, ConVarQueryResult result, const char[] cvarName, const char[] cvarValue)
{
	float mYaw = StringToFloat(cvarValue);
	if(mYaw != g_mYaw[client])
	{
		g_mYaw[client] = mYaw;
		g_mYawChangedCount[client]++;

		if(g_mYawChangedCount[client] > 1)
		{
			PrintToAdmins("%N changed their m_yaw ConVar to %.2f", client, mYaw);
				//AnticheatLog("%L changed their m_yaw ConVar to %.2f", client, mYaw);
		}
	}

	g_mYawCheckedCount[client]++;
}

public void OnFilterRetrieved(QueryCookie cookie, int client, ConVarQueryResult result, const char[] cvarName, const char[] cvarValue)
{
	bool mFilter = (0.0 <= StringToFloat(cvarValue) < 1.0)?false:true;
	if(mFilter != g_mFilter[client])
	{
		g_mFilterChangedCount[client]++;
		g_mFilter[client] = mFilter;

		if(g_mFilterChangedCount[client] > 1)
		{
			PrintToAdmins("%N changed their m_filter ConVar to %d", client, mFilter);
				//AnticheatLog("%L changed their m_filter ConVar to %d", client, mFilter);
		}
	}

	g_mFilterCheckedCount[client]++;
}

public void OnCustomAccelRetrieved(QueryCookie cookie, int client, ConVarQueryResult result, const char[] cvarName, const char[] cvarValue)
{
	int mCustomAccel = StringToInt(cvarValue);

	if(mCustomAccel != g_mCustomAccel[client])
	{
		g_mCustomAccel[client] = mCustomAccel;
		g_mCustomAccelChangedCount[client]++;

		if(g_mCustomAccelChangedCount[client] > 1)
		{
			PrintToAdmins("%N changed their m_customaccel ConVar to %d", client, mCustomAccel);
				//AnticheatLog("%L changed their m_customaccel ConVar to %d", client, mCustomAccel);
		}
	}

	g_mCustomAccelCheckedCount[client]++;
}

public void OnCustomAccelMaxRetrieved(QueryCookie cookie, int client, ConVarQueryResult result, const char[] cvarName, const char[] cvarValue)
{
	float mCustomAccelMax = StringToFloat(cvarValue);

	if(mCustomAccelMax != g_mCustomAccelMax[client])
	{
		g_mCustomAccelMax[client] = mCustomAccelMax;
		g_mCustomAccelMaxChangedCount[client]++;

		if(g_mCustomAccelMaxChangedCount[client] > 1)
		{
			PrintToAdmins("%N changed their m_customaccel_max ConVar to %f", client, mCustomAccelMax);
		}
	}

	g_mCustomAccelMaxCheckedCount[client]++;
}

public void OnCustomAccelScaleRetrieved(QueryCookie cookie, int client, ConVarQueryResult result, const char[] cvarName, const char[] cvarValue)
{
	float mCustomAccelScale = StringToFloat(cvarValue);

	if(mCustomAccelScale != g_mCustomAccelScale[client])
	{
		g_mCustomAccelScale[client] = mCustomAccelScale;
		g_mCustomAccelScaleChangedCount[client]++;

		if(g_mCustomAccelScaleChangedCount[client] > 1)
		{
			PrintToAdmins("%N changed their m_customaccel_scale ConVar to %f", client, mCustomAccelScale);
				//AnticheatLog("%L changed their m_customaccel ConVar to %d", client, mCustomAccel);
		}
	}

	g_mCustomAccelScaleCheckedCount[client]++;
}

public void OnCustomAccelExRetrieved(QueryCookie cookie, int client, ConVarQueryResult result, const char[] cvarName, const char[] cvarValue)
{
	float mCustomAccelExponent = StringToFloat(cvarValue);

	if(mCustomAccelExponent != g_mCustomAccelExponent[client])
	{
		g_mCustomAccelExponent[client] = mCustomAccelExponent;
		g_mCustomAccelExponentChangedCount[client]++;

		if(g_mCustomAccelExponentChangedCount[client] > 1)
		{
			PrintToAdmins("%N changed their m_customaccel_exponent ConVar to %f", client, mCustomAccelExponent);
				//AnticheatLog("%L changed their m_customaccel ConVar to %d", client, mCustomAccel);
		}
	}

	g_mCustomAccelExponentCheckedCount[client]++;
}

public void OnRawInputRetrieved(QueryCookie cookie, int client, ConVarQueryResult result, const char[] cvarName, const char[] cvarValue)
{
	bool mRawInput = (0.0 <= StringToFloat(cvarValue) < 1.0)?false:true;
	if(mRawInput != g_mRawInput[client])
	{
		g_mRawInputChangedCount[client]++;
		g_mRawInput[client] = mRawInput;

		if(g_mRawInputChangedCount[client] > 1)
		{
			PrintToAdmins("%N changed their m_rawinput ConVar to %d", client, mRawInput);
			//AnticheatLog(client, "%L changed their m_rawinput ConVar to %d", mRawInput);
		}
	}

	g_mRawInputCheckedCount[client]++;
}

public void OnSensitivityRetrieved(QueryCookie cookie, int client, ConVarQueryResult result, const char[] cvarName, const char[] cvarValue)
{
	float sensitivity = StringToFloat(cvarValue);
	if(sensitivity != g_Sensitivity[client])
	{
		g_Sensitivity[client] = sensitivity;
		g_SensitivityChangedCount[client]++;

		if(g_SensitivityChangedCount[client] > 1)
		{
			PrintToAdmins("%N changed their sensitivity ConVar to %.2f", client, sensitivity);
				//AnticheatLog("%L changed their sensitivity ConVar to %.2f", client, sensitivity);
		}
	}

	g_SensitivityCheckedCount[client]++;
}

public void OnYawSensitivityRetrieved(QueryCookie cookie, int client, ConVarQueryResult result, const char[] cvarName, const char[] cvarValue)
{
	float sensitivity = StringToFloat(cvarValue);
	if(sensitivity != g_JoySensitivity[client])
	{
		g_JoySensitivity[client] = sensitivity;
		g_JoySensitivityChangedCount[client]++;

		if(g_JoySensitivityChangedCount[client] > 1)
		{
			PrintToAdmins("%N changed their joy_yawsensitivity ConVar to %.2f", client, sensitivity);
				//AnticheatLog("%L changed their joy_yawsensitivity ConVar to %.2f", client, sensitivity);
		}
	}

	g_JoySensitivityCheckedCount[client]++;
}

public void OnZoomSensitivityRetrieved(QueryCookie cookie, int client, ConVarQueryResult result, const char[] cvarName, const char[] cvarValue)
{
	float sensitivity = StringToFloat(cvarValue);
	if(sensitivity != g_ZoomSensitivity[client])
	{
		g_ZoomSensitivity[client] = sensitivity;
		g_ZoomSensitivityChangedCount[client]++;

		if(g_ZoomSensitivityChangedCount[client] > 1)
		{
			PrintToAdmins("%N changed their %s ConVar to %.2f", client, cvarName, sensitivity);
				//AnticheatLog("%L changed their joy_yawsensitivity ConVar to %.2f", client, sensitivity);
		}
	}

	g_ZoomSensitivityCheckedCount[client]++;
}

public void OnJoystickRetrieved(QueryCookie cookie, int client, ConVarQueryResult result, const char[] cvarName, const char[] cvarValue)
{
	bool joyStick = (0.0 <= StringToFloat(cvarValue) < 1.0)?false:true;
	if(joyStick != g_JoyStick[client])
	{
		g_JoyStickChangedCount[client]++;
		g_JoyStick[client] = joyStick;

		if(g_JoyStickChangedCount[client] > 1)
		{
			PrintToAdmins("%N changed their joystick ConVar to %d", client, joyStick);
				//AnticheatLog("%L changed their joystick ConVar to %d", client, joyStick);
		}
	}

	g_JoyStickCheckedCount[client]++;
}


public Action Hook_OnTouch(int client, int entity)
{
	if(entity == 0)
	{
		g_bTouchesWall[client] = true;
	}

	char sClassname[64];
	GetEntityClassname(entity, sClassname, sizeof(sClassname));
	if(StrEqual(sClassname, "func_rotating"))
	{
		g_bTouchesFuncRotating[client] = true;
	}

}

public Action Bash_Stats(int client, int args)
{
	if(args == 0)
	{
		int target;
		if(IsPlayerAlive(client))
		{
			target = client;
		}
		else
		{
			target = GetEntPropEnt(client, Prop_Send, "m_hObserverTarget");
		}

		if(0 < target <= MaxClients)
		{
			ShowBashStats(client, GetClientUserId(target));
		}
	}
	else
	{
		char sArg[MAX_NAME_LENGTH];
		GetCmdArgString(sArg, MAX_NAME_LENGTH);

		if(sArg[0] == '#')
		{
			ReplaceString(sArg, MAX_NAME_LENGTH, "#", "", true);
			int target = GetClientOfUserId(StringToInt(sArg, 10));
			if(target)
			{
				ShowBashStats(client, GetClientUserId(target));
			}
			else
			{
				ReplyToCommand(client, "[BASH] No player with userid '%s'.", sArg);
			}
		}

		char sName[MAX_NAME_LENGTH];
		bool bFoundTarget;
		for(int target = 1; target <= MaxClients; target++)
		{
			if(IsClientInGame(target))
			{
				GetClientName(target, sName, MAX_NAME_LENGTH);
				if(StrContains(sName, sArg, false) != -1)
				{
					bFoundTarget = true;
					ShowBashStats(client, GetClientUserId(target));
				}
			}
		}

		if(!bFoundTarget)
		{
			ReplyToCommand(client, "[BASH] No player found with '%s' in their name.", sArg);
		}
	}

	return Plugin_Handled;
}

public Action Bash_AdminMode(int client, int args)
{
	if(g_bAdminMode[client])
	{
		g_bAdminMode[client] = !g_bAdminMode[client];
		ReplyToCommand(client, "[BASH] You are no longer in admin mode.");
	} else {
		g_bAdminMode[client] = !g_bAdminMode[client]
		ReplyToCommand(client, "[BASH] You are now in admin mode.");
	}
	return Plugin_Handled;
}

public Action Bash_Test(int client, int args)
{
	if (client == 0)
	{
		for (int i = 1; i<= MaxClients; i++)
		{
			if (IsClientConnected(i) && IsClientInGame(i))
			{
				client = i;
				break;
			}
		}
	}

	if (client == 0)
	{
		PrintToServer("No client to use for test log... :|");
	}
	else
	{
		AnticheatLog(client, "bash2_test log. plz ignore :)");
	}

	return Plugin_Handled;
}

void ShowBashStats(int client, int userid)
{
	int target = GetClientOfUserId(userid);
	if(target == 0)
	{
		PrintToChat(client, "[BASH] Selected player no longer ingame.");
		return;
	}

	g_iTarget[client] = userid;
	Menu menu = new Menu(BashStats_MainMenu);
	char sName[MAX_NAME_LENGTH];
	GetClientName(target, sName, sizeof(sName));
	menu.SetTitle("[BASH] - Select stats for %N", target);

	menu.AddItem("start",      "Start Strafe (Original)");
	menu.AddItem("end",        "End Strafe");
	menu.AddItem("keys",       "Key Switch");

	char sGain[32];
	FormatEx(sGain, 32, "Current gains: %.2f", GetGainPercent(target));
	menu.AddItem("gain", sGain);
	/*if(IsBlacky(client))
	{
		menu.AddItem("man1",       "Manual Test (MOTD)");
		menu.AddItem("man2",       "Manual Test (Angle)");
		menu.AddItem("flags",      "Player flags", ITEMDRAW_DISABLED);
	}*/

	menu.Display(client, MENU_TIME_FOREVER);
}

public int BashStats_MainMenu(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		char sInfo[32];
		menu.GetItem(param2, sInfo, sizeof(sInfo));

		if(StrEqual(sInfo, "start"))
		{
			ShowBashStats_StartStrafes(param1);
		}
		else if(StrEqual(sInfo, "end"))
		{
			ShowBashStats_EndStrafes(param1);
		}
		else if(StrEqual(sInfo, "keys"))
		{
			ShowBashStats_KeySwitches(param1);
		}
		else if(StrEqual(sInfo, "gain"))
		{
			ShowBashStats(param1, g_iTarget[param1]);
		}
		else if(StrEqual(sInfo, "man1"))
		{
			PerformMOTDTest(param1);
		}
		else if(StrEqual(sInfo, "man2"))
		{
			PerformAngleTest(param1);
		}
		else if(StrEqual(sInfo, "flags"))
		{

		}
	}

	if (action & MenuAction_End)
	{
		delete menu;
	}
}

void PerformMOTDTest(int client)
{
	int target = GetClientOfUserId(g_iTarget[client]);
	if(target == 0)
	{
		return;
	}

	//void ShowVGUIPanel(int client, const char[] name, Handle Kv, bool show)
	//MotdChanger_SendClientMotd(client, "Welcome", "text", "Welcome to KawaiiClan!");
	g_bMOTDTest[target] = true;
	if(g_Engine == Engine_CSGO)
	{
		ShowMOTDPanel(target, "Welcome", "http://kawaiiclan.com/welcome.html", MOTDPANEL_TYPE_URL);
	}
	else if(g_Engine == Engine_CSS)
	{
		ShowMOTDPanel(target, "Welcome", "http://kawaiiclan.com/", MOTDPANEL_TYPE_URL);
	}
}

stock void PerformAngleTest(int client)
{

}

void ShowBashStats_StartStrafes(int client)
{
	int target = GetClientOfUserId(g_iTarget[client]);
	if(target == 0)
	{
		PrintToChat(client, "[BASH] Selected player no longer ingame.");
		return;
	}

	int array[MAX_FRAMES];
	int buttons[4];
	int size;
	for(int idx; idx < MAX_FRAMES; idx++)
	{
		if(g_bStartStrafe_IsRecorded[target][idx] == true)
		{
			array[idx] = g_iStartStrafe_Stats[target][StrafeData_Difference][idx];
			buttons[g_iStartStrafe_Stats[target][StrafeData_Button][idx]]++;
			size++;
		}
	}

	if(size == 0)
	{
		PrintToChat(client, "[BASH] Player '%N' has no start strafe stats.", target);
	}
	float startStrafeMean = GetAverage(array, size);
	float startStrafeSD   = StandardDeviation(array, size, startStrafeMean);

	Menu menu = new Menu(BashStats_StartStrafesMenu);
	menu.SetTitle("[BASH] Start Strafe stats for %N\nAverage: %.2f | Deviation: %.2f\nA: %d, D: %d, W: %d, S: %d\n ",
		target, startStrafeMean, startStrafeSD,
		buttons[2], buttons[3], buttons[0], buttons[1]);

	char sDisplay[128];
	for(int idx; idx < size; idx++)
	{
		Format(sDisplay, sizeof(sDisplay), "%s%d ", sDisplay, array[idx]);

		if((idx + 1) % 10 == 0  || size - idx == 1)
		{
			menu.AddItem("", sDisplay, ITEMDRAW_DISABLED);
			FormatEx(sDisplay, sizeof(sDisplay), "");
		}
	}

	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int BashStats_StartStrafesMenu(Menu menu, MenuAction action, int param1, int param2)
{
	/*
	if(action == MenuAction_Select)
	{

	}
	*/
	if(action == MenuAction_Cancel)
	{
		if(param2 == MenuCancel_ExitBack)
			ShowBashStats(param1, g_iTarget[param1]);
	}

	if (action & MenuAction_End)
	{
		delete menu;
	}
}

void ShowBashStats_EndStrafes(int client)
{
	int target = GetClientOfUserId(g_iTarget[client]);
	if(target == 0)
	{
		PrintToChat(client, "[BASH] Selected player no longer ingame.");
		return;
	}

	int array[MAX_FRAMES];
	int buttons[4];
	int size;
	for(int idx; idx < MAX_FRAMES; idx++)
	{
		if(g_bEndStrafe_IsRecorded[target][idx] == true)
		{
			array[idx] = g_iEndStrafe_Stats[target][StrafeData_Difference][idx];
			buttons[g_iEndStrafe_Stats[target][StrafeData_Button][idx]]++;
			size++;
		}
	}

	if(size == 0)
	{
		PrintToChat(client, "[BASH] Player '%N' has no end strafe stats.", target);
	}

	float mean = GetAverage(array, size);
	float sd   = StandardDeviation(array, size, mean);

	Menu menu = new Menu(BashStats_EndStrafesMenu);
	menu.SetTitle("[BASH] End Strafe stats for %N\nAverage: %.2f | Deviation: %.2f\nA: %d, D: %d, W: %d, S: %d\n ",
		target, mean, sd,
		buttons[2], buttons[3], buttons[0], buttons[1]);

	char sDisplay[128];
	for(int idx; idx < size; idx++)
	{
		Format(sDisplay, sizeof(sDisplay), "%s%d ", sDisplay, array[idx]);

		if((idx + 1) % 10 == 0  || (size - idx == 1))
		{
			menu.AddItem("", sDisplay, ITEMDRAW_DISABLED);
			FormatEx(sDisplay, sizeof(sDisplay), "");
		}
	}

	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int BashStats_EndStrafesMenu(Menu menu, MenuAction action, int param1, int param2)
{
	/*
	if(action == MenuAction_Select)
	{

	}
	*/
	if(action == MenuAction_Cancel)
	{
		if(param2 == MenuCancel_ExitBack)
			ShowBashStats(param1, g_iTarget[param1]);
	}

	if (action & MenuAction_End)
	{
		delete menu;
	}
}

void ShowBashStats_KeySwitches(int client)
{
	int target = GetClientOfUserId(g_iTarget[client]);
	if(target == 0)
	{
		PrintToChat(client, "[BASH] Selected player no longer ingame.");
		return;
	}

	Menu menu = new Menu(BashStats_KeySwitchesMenu);
	menu.SetTitle("[BASH] Select key switch type");
	menu.AddItem("move", "Movement");
	menu.AddItem("key",  "Buttons");
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int BashStats_KeySwitchesMenu(Menu menu, MenuAction action, int param1, int param2)
{
	if(action & MenuAction_Select)
	{
		char sInfo[32];
		menu.GetItem(param2, sInfo, sizeof(sInfo));

		if(StrEqual(sInfo, "move"))
		{
			ShowBashStats_KeySwitches_Move(param1);
		}
		else if(StrEqual(sInfo, "key"))
		{
			ShowBashStats_KeySwitches_Keys(param1);
		}
	}
	if(action == MenuAction_Cancel)
	{
		if(param2 == MenuCancel_ExitBack)
			ShowBashStats(param1, g_iTarget[param1]);
	}

	if (action & MenuAction_End)
	{
		delete menu;
	}
}

void ShowBashStats_KeySwitches_Move(int client)
{
	int target = GetClientOfUserId(g_iTarget[client]);
	if(target == 0)
	{
		PrintToChat(client, "[BASH] Selected player no longer ingame.");
		return;
	}

	int array[MAX_FRAMES_KEYSWITCH];
	int size;
	for(int idx; idx < MAX_FRAMES_KEYSWITCH; idx++)
	{
		if(g_bKeySwitch_IsRecorded[target][BT_Move][idx] == true)
		{
			array[idx] = g_iKeySwitch_Stats[target][KeySwitchData_Difference][BT_Move][idx];
			size++;
		}
	}
	float mean = GetAverage(array, size);
	float sd   = StandardDeviation(array, size, mean);

	Menu menu = new Menu(BashStats_KeySwitchesMenu_Move);
	menu.SetTitle("[BASH] Sidemove Switch stats for %N\nAverage: %.2f | Deviation: %.2f\n ", target, mean, sd);

	char sDisplay[128];
	for(int idx; idx < size; idx++)
	{
		Format(sDisplay, sizeof(sDisplay), "%s%d ", sDisplay, array[idx]);

		if((idx + 1) % 10 == 0  || (size - idx == 1))
		{
			menu.AddItem("", sDisplay, ITEMDRAW_DISABLED);
			FormatEx(sDisplay, sizeof(sDisplay), "");
		}
	}

	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

void ShowBashStats_KeySwitches_Keys(int client)
{
	int target = GetClientOfUserId(g_iTarget[client]);
	if(target == 0)
	{
		PrintToChat(client, "[BASH] Selected player no longer ingame.");
		return;
	}

	int array[MAX_FRAMES_KEYSWITCH];
	int size, positiveCount;
	for(int idx; idx < MAX_FRAMES_KEYSWITCH; idx++)
	{
		if(g_bKeySwitch_IsRecorded[target][BT_Key][idx] == true)
		{
			array[idx] = g_iKeySwitch_Stats[target][KeySwitchData_Difference][BT_Key][idx];
			size++;

			if(g_iKeySwitch_Stats[target][KeySwitchData_Difference][BT_Key][idx] >= 0)
			{
				positiveCount++;
			}
		}
	}

	float mean = GetAverage(array, size);
	float sd   = StandardDeviation(array, size, mean);
	float pctPositive = float(positiveCount) / float(size);
	Menu menu = new Menu(BashStats_KeySwitchesMenu_Move);
	menu.SetTitle("[BASH] Key Switch stats for %N\nAverage: %.2f | Deviation: %.2f | Positive: %.2f\n ", target, mean, sd, pctPositive);

	char sDisplay[128];
	for(int idx; idx < size; idx++)
	{
		Format(sDisplay, sizeof(sDisplay), "%s%d ", sDisplay, array[idx]);

		if((idx + 1) % 10 == 0  || (size - idx == 1))
		{
			menu.AddItem("", sDisplay, ITEMDRAW_DISABLED);
			FormatEx(sDisplay, sizeof(sDisplay), "");
		}
	}

	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int BashStats_KeySwitchesMenu_Move(Menu menu, MenuAction action, int param1, int param2)
{
	/*
	if(action == MenuAction_Select)
	{

	}
	*/
	if(action == MenuAction_Cancel)
	{
		if(param2 == MenuCancel_ExitBack)
			ShowBashStats_KeySwitches(param1);
	}

	if (action & MenuAction_End)
	{
		delete menu;
	}
}

float StandardDeviation(int[] array, int size, float mean, bool countZeroes = true)
{
	float sd;

	for(int idx; idx < size; idx++)
	{
		if(countZeroes || array[idx] != 0)
		{
			sd += Pow(float(array[idx]) - mean, 2.0);
		}
	}

	return SquareRoot(sd/size);
}

float GetAverage(int[] array, int size, bool countZeroes = true)
{
	int total;

	for(int idx; idx < size; idx++)
	{
		if(countZeroes || array[idx] != 0)
		{
			total += array[idx];
		}

	}

	return float(total) / float(size);
}

int g_iRunCmdsPerSecond[MAXPLAYERS + 1];
int g_iBadSeconds[MAXPLAYERS + 1];
float g_fLastCheckTime[MAXPLAYERS + 1];
MoveType g_mLastMoveType[MAXPLAYERS + 1];

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	if(!IsFakeClient(client) && IsPlayerAlive(client))
	{
		g_iRealButtons[client] = buttons;
		// Update all information this tick
		bool bCheck = true;

		#if defined TIMER

		g_bIsBeingTimed[client] = false;
		if(Shavit_GetTimerStatus(client) == Timer_Running) {
			g_bIsBeingTimed[client] = true;
		}

		//if(TimerInfo(client).Paused == true)
		if(Shavit_GetTimerStatus(client) == Timer_Paused)
		{
			bCheck = false;
		}

		char sSpecial[128];
		int style = Shavit_GetBhopStyle(client);
		Shavit_GetStyleStrings(style, sSpecialString, sSpecial, 128);
		if(StrContains(sSpecial, "bash_bypass", false) != -1)
		{
			 	bCheck = false;
		}

		#endif

		UpdateButtons(client, vel, buttons);
		UpdateAngles(client, angles);

		if(bCheck == true)
		{
			if(g_bCheckedYet[client] == false)
			{
				g_bCheckedYet[client] = true;
				g_fLastCheckTime[client] = GetEngineTime();
			}

			if(GetEntityMoveType(client) != MOVETYPE_NONE)
			{
				g_mLastMoveType[client] = GetEntityMoveType(client);
			}

			float tickRate = 1.0 / GetTickInterval();
			g_iRunCmdsPerSecond[client]++;
			if(GetEngineTime() - g_fLastCheckTime[client] >= 1.0)
			{
				if(float(g_iRunCmdsPerSecond[client]) / tickRate <= 0.95)
				{
					if(++g_iBadSeconds[client] >= 3)
					{
						//PrintToAdmins("%N has had %d bad seconds", client, g_iBadSeconds[client]);
						SetEntityMoveType(client, MOVETYPE_NONE);
					}
				}
				else
				{
					if(GetEntityMoveType(client) == MOVETYPE_NONE)
					{
						SetEntityMoveType(client, g_mLastMoveType[client]);
					}
					g_iBadSeconds[client] = 0;
				}

				g_fLastCheckTime[client] = GetEngineTime();
				g_iRunCmdsPerSecond[client] = 0;
			}
		}

		if(!g_bDhooksLoaded) CheckForTeleport(client);
		CheckForEndKey(client);
		CheckForTurn(client);
		CheckForStartKey(client);

		// After we have all the information we can get, do stuff with it
		if(!(GetEntityFlags(client) & (FL_ONGROUND|FL_INWATER)) && GetEntityMoveType(client) == MOVETYPE_WALK && bCheck)
		{
			for(int idx; idx < 4; idx++)
			{
				if(g_iLastReleaseTick[client][idx][BT_Move] == g_iCmdNum[client])
				{
					ClientReleasedKey(client, idx, BT_Move);
				}

				if(g_iLastReleaseTick[client][idx][BT_Key] == g_iCmdNum[client])
				{
					ClientReleasedKey(client, idx, BT_Key);
				}
			}

			if(g_iLastTurnTick[client] == g_iCmdNum[client])
			{
				ClientTurned(client, g_iLastTurnDir[client]);
			}

			if(g_iLastStopTurnTick[client] == g_iCmdNum[client])
			{
				ClientStoppedTurning(client);
			}

			for(int idx; idx < 4; idx++)
			{
				if(g_iLastPressTick[client][idx][BT_Move] == g_iCmdNum[client])
				{
					ClientPressedKey(client, idx, BT_Move);
				}

				if(g_iLastPressTick[client][idx][BT_Key] == g_iCmdNum[client])
				{
					ClientPressedKey(client, idx, BT_Key);
				}
			}
		}

		if(bCheck)
		{
			CheckForIllegalMovement(client, vel, buttons);
			CheckForIllegalTurning(client, vel);
			UpdateGains(client, vel, angles, buttons);
		}

		g_fLastMove[client][0]   = vel[0];
		g_fLastMove[client][1]   = vel[1];
		g_fLastMove[client][2]   = vel[2];
		g_fLastAngles[client][0] = angles[0];
		g_fLastAngles[client][1] = angles[1];
		g_fLastAngles[client][2] = angles[2];
		GetClientAbsOrigin(client, g_fLastPosition[client]);
		g_fLastAngleDifference[client][0] = g_fAngleDifference[client][0];
		g_fLastAngleDifference[client][1] = g_fAngleDifference[client][1];
		g_iCmdNum[client]++;
		g_bTouchesFuncRotating[client] = false;
		g_bTouchesWall[client] = false;
	}
}

int g_iIllegalYawCount[MAXPLAYERS + 1];
int g_iPlusLeftCount[MAXPLAYERS + 1];

/* float MAX(float a, float b)
{
	return (a > b)?a:b;
} */

int g_iCurrentIFrame[MAXPLAYERS + 1];
float g_fIList[MAXPLAYERS + 1][100];

void CheckForIllegalTurning(int client, float vel[3])
{
	if(GetClientButtons(client) & (IN_LEFT|IN_RIGHT))
	{
		g_iPlusLeftCount[client]++;
	}

	if(g_iCmdNum[client] % 100 == 0)
	{
		if(g_iIllegalYawCount[client] > 30 && g_iPlusLeftCount[client] == 0)
		{
			AnticheatLog(client, "is turning with illegal yaw values (m_yaw: %f, sens: %f, m_customaccel: %d, count: %d, m_yaw changes: %d, Joystick: %d)", g_mYaw[client], g_Sensitivity[client], g_mCustomAccel[client], g_iIllegalYawCount[client], g_mYawChangedCount[client], g_JoyStick[client]);

			char sValues[256];
			for(int idx; idx < 20; idx++)
			{
				Format(sValues, 256, "%s %.3f", sValues, g_fIList[idx]);
			}

			//AnticheatLog(client, sValues);
		}

		g_iIllegalYawCount[client] = 0;
		g_iPlusLeftCount[client]   = 0;
	}


	// Don't bother checking if they arent turning
	if(FloatAbs(g_fAngleDifference[client][1]) < 0.01)
	{
		return;
	}

	// Only calculate illegal turns when player cvars have been checked
	if(g_mCustomAccelCheckedCount[client] == 0 || g_mFilterCheckedCount[client] == 0 || g_mYawCheckedCount[client] == 0 || g_SensitivityCheckedCount[client] == 0)
	{
		return;
	}

	// Check for teleporting because teleporting can cause illegal turn values
	if(g_iCmdNum[client] - g_iLastTeleportTick[client] < 100)
	{
		return;
	}

	// Prevent incredibly high sensitivity from causing detections
	if(FloatAbs(g_fAngleDifference[client][1]) > 20.0 || FloatAbs(g_Sensitivity[client] * g_mYaw[client]) > 0.8)
	{
		return;
	}

	// Prevent players who are zooming with a weapon to trigger the anticheat
	if(GetEntProp(client, Prop_Send, "m_iFOVStart") != 90)
	{
		return;
	}

	// Prevent false positives with players touching rotating blocks that will change their angles
	if(g_bTouchesFuncRotating[client] == true)
	{
		return;
	}

	if(g_iIllegalSidemoveCount[client] > 0)
	{
		return;
	}

	// Attempt to prevent players who are using xbox controllers from triggering the anticheat, because they can't use controller and have legal sidemove values at the same time
	float fMaxMove;
	if(g_Engine == Engine_CSS) fMaxMove = 400.0;
	else if(g_Engine == Engine_CSGO) fMaxMove = 450.0;

	if(FloatAbs(vel[0]) != fMaxMove && FloatAbs(vel[1]) != fMaxMove)
	{
		return;
	}

	float my = g_fAngleDifference[client][0];
	float mx = g_fAngleDifference[client][1];
	float fCoeff;

	// Player should not be able to turn at all with sensitivity or m_yaw equal to 0 so detect them if they are
	if((g_mYaw[client] == 0.0 || g_Sensitivity[client] == 0.0) && !(GetClientButtons(client) & (IN_LEFT|IN_RIGHT)))
	{
		g_iIllegalYawCount[client]++;
	}
	else if(g_mCustomAccel[client] <= 0 || g_mCustomAccel[client] > 3)
	{
		//fCoeff = mx / (g_mYaw[client] * g_Sensitivity[client]);
		fCoeff = g_Sensitivity[client];
	}
	else if(g_mCustomAccel[client] == 1 || g_mCustomAccel[client] == 2)
	{
		float raw_mouse_movement_distance      = SquareRoot(mx * mx + my * my);
		float acceleration_scale               = g_mCustomAccelScale[client];
		float accelerated_sensitivity_max      = g_mCustomAccelMax[client];
		float accelerated_sensitivity_exponent = g_mCustomAccelExponent[client];
		float accelerated_sensitivity          = Pow(raw_mouse_movement_distance, accelerated_sensitivity_exponent) * acceleration_scale + g_Sensitivity[client];

		if (accelerated_sensitivity_max > 0.0001 && accelerated_sensitivity > accelerated_sensitivity_max)
		{
			accelerated_sensitivity = accelerated_sensitivity_max;
		}

		fCoeff = accelerated_sensitivity;

		if(g_mCustomAccel[client] == 2)
		{
			fCoeff *= g_mYaw[client];
		}
	}
	else if(g_mCustomAccel[client] == 3)
	{
		//float raw_mouse_movement_distance_squared = (mx * mx) + (my * my);
		//float fExp = MAX(0.0, (g_mCustomAccelExponent[client] - 1.0) / 2.0);
		//float accelerated_sensitivity = Pow(raw_mouse_movement_distance_squared, fExp) * g_Sensitivity[client];

		//PrintToChat(client, "%f %f", raw_mouse_movement_distance_squared, fExp);
		//PrintToChat(client, "%f", accelerated_sensitivity);
		//PrintToChat(client, "%f", mx);

		//fCoeff = accelerated_sensitivity;
		fCoeff = g_Sensitivity[client];

		return;
	}

	if(g_Engine == Engine_CSS && g_mFilter[client] == true)
	{
		fCoeff /= 4;
	}

	float fTurn = mx / (g_mYaw[client] * fCoeff);
	float fRounded = float(RoundFloat(fTurn));

	if(FloatAbs(fRounded - fTurn) > 0.1)
	{
		g_fIList[client][g_iCurrentIFrame[client]] = fTurn;
		g_iCurrentIFrame[client] = (g_iCurrentIFrame[client] + 1) % 20;
		g_iIllegalYawCount[client]++;
	}
}

void CheckForWOnlyHack(int client)
{
	if(FloatAbs(g_fAngleDifference[client][1] - g_fLastAngleDifference[client][1]) > 13 && // Player turned more than 13 degrees in 1 tick
	g_fAngleDifference[client][1] != 0.0 &&
	((g_iCmdNum[client] - g_iLastTeleportTick[client]) > 200// &&
	//g_iButtons[client][BT_Move] & (1 << GetOppositeButton(GetDesiredButton(client, g_iLastTurnDir[client])))// &&
	))
	{
		g_iIllegalTurn[client][g_iIllegalTurn_CurrentFrame[client]] = true;
		//PrintToAdmins("%N: %.1f", client, FloatAbs(g_fAngleDifference[client] - g_fLastAngleDifference[client]));
	}
	else
	{
		g_iIllegalTurn[client][g_iIllegalTurn_CurrentFrame[client]] = false;
		//char sTurn[32];
		//GetTurnDirectionName(g_iLastTurnDir[client], sTurn, sizeof(sTurn));
		//PrintToAdmins("No: Diff: %.1f, Btn: %d, Gain: %.1f", FloatAbs(g_fAngleDifference[client] - g_fLastAngleDifference[client]), g_iButtons[client][BT_Move] & (1 << GetOppositeButton(GetDesiredButton(client, g_iLastTurnDir[client]))), GetGainPercent(client));
	}

	#if defined TIMER

	g_iIllegalTurn_IsTiming[client][g_iIllegalTurn_CurrentFrame[client]] = g_bIsBeingTimed[client];
	#endif

	g_iIllegalTurn_CurrentFrame[client] = (g_iIllegalTurn_CurrentFrame[client] + 1) % MAX_FRAMES;

	if(g_iIllegalTurn_CurrentFrame[client] == 0)
	{
		int illegalCount, timingCount;
		for(int idx; idx < MAX_FRAMES; idx++)
		{
			if(g_iIllegalTurn[client][idx] == true)
			{
				illegalCount++;
			}

			if(g_iIllegalTurn_IsTiming[client][idx] == true)
			{
				timingCount++;
			}
		}

		float illegalPct, timingPct;
		illegalPct = float(illegalCount) / float(MAX_FRAMES);
		timingPct  = float(timingCount) / float(MAX_FRAMES);
		if(illegalPct > 0.6)
		{

			#if defined TIMER
			char sStyle[32];
			int style = Shavit_GetBhopStyle(client);
			Shavit_GetStyleStrings(style, sStyleName, g_sStyleStrings[style].sStyleName, sizeof(stylestrings_t::sStyleName));
			FormatEx(sStyle, sizeof(sStyle), "%s", g_sStyleStrings[style].sStyleName)
			AnticheatLog(client, "angle snap hack, Pct: %.2f％, Timing: %.1f％, Style: %s", illegalPct * 100.0, timingPct * 100.0, sStyle);
			#endif

			#if !defined TIMER
			AnticheatLog(client, "angle snap hack, Pct: %.2f％, Timing: %.1f％", illegalPct * 100.0, timingPct * 100.0);
			#endif
		}
	}

	return;
}

void CheckForStartKey(int client)
{
	for(int idx; idx < 4; idx++)
	{
		if(!(g_iLastButtons[client][BT_Move] & (1 << idx)) && (g_iButtons[client][BT_Move] & (1 << idx)))
		{
			g_iLastPressTick[client][idx][BT_Move] = g_iCmdNum[client];
		}

		if(!(g_iLastButtons[client][BT_Key] & (1 << idx)) && (g_iButtons[client][BT_Key] & (1 << idx)))
		{
			g_iLastPressTick[client][idx][BT_Key] = g_iCmdNum[client];
		}
	}
}

void ClientPressedKey(int client, int button, int btype)
{
	g_iKeyPressesThisStrafe[client][btype]++;
	// Check if player started a strafe
	if(btype == BT_Move)
	{
		g_iStrafesDone[client]++; // player pressed either w,a,s,d. update strafe count

		int turnDir = GetDesiredTurnDir(client, button, false);

		if(g_iLastTurnDir[client] == turnDir &&
		g_iStartStrafe_LastRecordedTick[client] != g_iCmdNum[client] &&
		g_iLastPressTick[client][button][BT_Move] != g_iLastPressTick_Recorded[client][button][BT_Move] &&
		g_iLastTurnTick[client] != g_iLastTurnTick_Recorded_StartStrafe[client])
		{
			int difference = g_iLastTurnTick[client] - g_iLastPressTick[client][button][BT_Move];

			if(-15 <= difference <= 15)
			{
				RecordStartStrafe(client, button, turnDir, "ClientPressedKey");
			}
		}
	}

	// Check if player finished switching their keys
	int oppositeButton = GetOppositeButton(button);
	int difference = g_iLastPressTick[client][button][btype] - g_iLastReleaseTick[client][oppositeButton][btype];
	if(difference <= 15 && g_iKeySwitch_LastRecordedTick[client][btype] != g_iCmdNum[client] &&
	g_iLastReleaseTick[client][oppositeButton][btype] != g_iLastReleaseTick_Recorded_KS[client][oppositeButton][btype] &&
	g_iLastPressTick[client][button][btype] != g_iLastPressTick_Recorded_KS[client][button][btype])
	{
		RecordKeySwitch(client, button, oppositeButton, btype, "ClientPressedKey");
	}
}

void CheckForTeleport(int client)
{
	float vPos[3];
	GetClientAbsOrigin(client, vPos);

	float distance = SquareRoot(Pow(vPos[0] - g_fLastPosition[client][0], 2.0) +
								Pow(vPos[1] - g_fLastPosition[client][1], 2.0) +
								Pow(vPos[2] - g_fLastPosition[client][2], 2.0));

	if(distance > 35.0)
	{
		g_iLastTeleportTick[client] = g_iCmdNum[client];
	}
}

void CheckForEndKey(int client)
{
	for(int idx; idx < 4; idx++)
	{
		if((g_iLastButtons[client][BT_Move] & (1 << idx)) && !(g_iButtons[client][BT_Move] & (1 << idx)))
		{
			g_iLastReleaseTick[client][idx][BT_Move] = g_iCmdNum[client];
		}

		if((g_iLastButtons[client][BT_Key] & (1 << idx)) && !(g_iButtons[client][BT_Key] & (1 << idx)))
		{
			g_iLastReleaseTick[client][idx][BT_Key] = g_iCmdNum[client];
		}
	}
}

void ClientReleasedKey(int client, int button, int btype)
{
	if(btype == BT_Move)
	{
		// Record end strafe if it is actually an end strafe
		int turnDir = GetDesiredTurnDir(client, button, true);

		if((g_iLastTurnDir[client] == turnDir || g_bIsTurning[client] == false) &&
		g_iEndStrafe_LastRecordedTick[client] != g_iCmdNum[client] &&
		g_iLastReleaseTick_Recorded[client][button][BT_Move] != g_iLastReleaseTick[client][button][BT_Move] &&
		g_iLastTurnTick_Recorded_EndStrafe[client] != g_iLastTurnTick[client])
		{
			int difference = g_iLastTurnTick[client] - g_iLastReleaseTick[client][button][BT_Move];

			if(-15 <= difference <= 15)
			{
				RecordEndStrafe(client, button, turnDir, "ClientReleasedKey");
			}
		}
	}

	// Check if we should record a key switch (BT_Key)
	if(btype == BT_Key)
	{
		int oppositeButton = GetOppositeButton(button);

		if(g_iLastReleaseTick[client][button][BT_Key] - g_iLastPressTick[client][oppositeButton][BT_Key] <= 15 &&
		g_iKeySwitch_LastRecordedTick[client][BT_Key] != g_iCmdNum[client] &&
		g_iLastReleaseTick[client][button][btype] != g_iLastReleaseTick_Recorded_KS[client][button][btype] &&
		g_iLastPressTick[client][oppositeButton][btype] != g_iLastPressTick_Recorded_KS[client][oppositeButton][btype])
		{
			RecordKeySwitch(client, oppositeButton, button, btype, "ClientReleasedKey");
		}
	}
}

void CheckForTurn(int client)
{
	if(g_fAngleDifference[client][1] == 0.0 && g_bIsTurning[client] == true)
	{
		g_iLastStopTurnTick[client] = g_iCmdNum[client];
		g_bIsTurning[client]        = false;
	}
	else if(g_fAngleDifference[client][1] > 0)
	{
		if(g_iLastTurnDir[client] == Turn_Right)
		{
			// Turned left
			g_iLastTurnTick[client] = g_iCmdNum[client];
			g_iLastTurnDir[client]  = Turn_Left;
			g_bIsTurning[client]    = true;
		}
	}
	else if(g_fAngleDifference[client][1] < 0)
	{
		if(g_iLastTurnDir[client] == Turn_Left)
		{
			// Turned right
			g_iLastTurnTick[client] = g_iCmdNum[client];
			g_iLastTurnDir[client]  = Turn_Right;
			g_bIsTurning[client]    = true;
		}
	}
}

void ClientTurned(int client, int turnDir)
{
	// Check if client ended a strafe
	int button         = GetDesiredButton(client, turnDir);

	int oppositeButton = GetOppositeButton(button);
	if(!(g_iButtons[client][BT_Move] & (1 << oppositeButton)) &&
		g_iEndStrafe_LastRecordedTick[client] != g_iCmdNum[client] &&
		g_iReleaseTickAtLastEndStrafe[client][oppositeButton] != g_iLastReleaseTick[client][oppositeButton][BT_Move] &&
		g_iLastTurnTick_Recorded_EndStrafe[client] != g_iLastTurnTick[client])
	{
		int difference = g_iLastTurnTick[client] - g_iLastReleaseTick[client][oppositeButton][BT_Move];

		if(-15 <= difference <= 15)
		{
			RecordEndStrafe(client, oppositeButton, turnDir, "ClientTurned");
		}
	}

	// Check if client just started a strafe
	if(g_iButtons[client][BT_Move] & (1 << button) &&
	g_iStartStrafe_LastRecordedTick[client] != g_iCmdNum[client] &&
	g_iLastPressTick_Recorded[client][button][BT_Move] != g_iLastPressTick[client][button][BT_Move] &&
	g_iLastTurnTick_Recorded_StartStrafe[client] != g_iLastTurnTick[client])
	{
		int difference = g_iLastTurnTick[client] - g_iLastPressTick[client][button][BT_Move];

		if(-15 <= difference <= 15)
		{
			RecordStartStrafe(client, button, turnDir, "ClientTurned");
		}
	}

	// Check if client is cheating on w-only
	CheckForWOnlyHack(client);
}

void ClientStoppedTurning(int client)
{
	int turnDir = g_iLastTurnDir[client];
	int button  = GetDesiredButton(client, turnDir);

	// if client already let go of movement button, and end strafe hasn't been recorded this tick and since they released their key
	if(!(g_iButtons[client][BT_Move] & (1 << button)) &&
		g_iEndStrafe_LastRecordedTick[client] != g_iCmdNum[client] &&
		g_iReleaseTickAtLastEndStrafe[client][button] != g_iLastReleaseTick[client][button][BT_Move] &&
		g_iLastTurnTick_Recorded_EndStrafe[client] != g_iLastStopTurnTick[client])
	{
		int difference = g_iLastStopTurnTick[client] - g_iLastReleaseTick[client][button][BT_Move];

		if(-15 <= difference <= 15)
		{
			RecordEndStrafe(client, button, turnDir, "ClientStoppedTurning");
		}
	}
}

stock void RecordStartStrafe(int client, int button, int turnDir, const char[] caller)
{
	g_iLastPressTick_Recorded[client][button][BT_Move] = g_iLastPressTick[client][button][BT_Move];
	g_iLastTurnTick_Recorded_StartStrafe[client]       = g_iLastTurnTick[client];

	int moveDir   = GetDirection(client);
	int currFrame = g_iStartStrafe_CurrentFrame[client];
	g_iStartStrafe_LastRecordedTick[client] = g_iCmdNum[client];
	g_iStartStrafe_Stats[client][StrafeData_Button][currFrame]        = button;
	g_iStartStrafe_Stats[client][StrafeData_TurnDirection][currFrame] = turnDir;
	g_iStartStrafe_Stats[client][StrafeData_MoveDirection][currFrame] = moveDir;
	g_iStartStrafe_Stats[client][StrafeData_Difference][currFrame]    = g_iLastPressTick[client][button][BT_Move] - g_iLastTurnTick[client];
	g_iStartStrafe_Stats[client][StrafeData_Tick][currFrame]          = g_iCmdNum[client];
	#if defined TIMER
	g_iStartStrafe_Stats[client][StrafeData_IsTiming][currFrame]      = g_bIsBeingTimed[client];
	#endif
	g_bStartStrafe_IsRecorded[client][currFrame] = true;
	g_iStartStrafe_CurrentFrame[client] = (g_iStartStrafe_CurrentFrame[client] + 1) % MAX_FRAMES;


	if(g_iStartStrafe_Stats[client][StrafeData_Difference][currFrame] == g_iStartStrafe_LastTickDifference[client] && !IsInLeftRight(client, g_iRealButtons[client]))
	{
		g_iStartStrafe_IdenticalCount[client]++;

		if (g_iStartStrafe_IdenticalCount[client] >= IDENTICAL_STRAFE_MIN)
		{
			AnticheatLog(client, "too many %i strafes in a row (%d)", g_iStartStrafe_LastTickDifference[client], g_iStartStrafe_IdenticalCount[client]);
			AutoBanPlayer(client);
		}
	}
	else
	{
		if (g_iStartStrafe_IdenticalCount[client] >= 15 && g_iStartStrafe_IdenticalCount[client] < IDENTICAL_STRAFE_MIN)
		{
			AnticheatLog(client, "too many %i strafes in a row (%d)", g_iStartStrafe_LastTickDifference[client], g_iStartStrafe_IdenticalCount[client]);
		}

		g_iStartStrafe_LastTickDifference[client] = g_iStartStrafe_Stats[client][StrafeData_Difference][currFrame];
		g_iStartStrafe_IdenticalCount[client] = 0;
	}

	if(g_iStartStrafe_CurrentFrame[client] == 0)
	{
		int array[MAX_FRAMES];
		int size, timingCount;
		for(int idx; idx < MAX_FRAMES; idx++)
		{
			if(g_bStartStrafe_IsRecorded[client][idx] == true)
			{
				array[idx] = g_iStartStrafe_Stats[client][StrafeData_Difference][idx];
				size++;

				if(g_iStartStrafe_Stats[client][StrafeData_IsTiming][idx] == true)
				{
					timingCount++;
				}
			}
		}
		float mean = GetAverage(array, size);
		float sd   = StandardDeviation(array, size, mean);

		if(sd < 0.8)
		{
			char sStyle[32];
			#if defined TIMER
			int style = Shavit_GetBhopStyle(client);
			Shavit_GetStyleStrings(style, sStyleName, g_sStyleStrings[style].sStyleName, sizeof(stylestrings_t::sStyleName));
			FormatEx(sStyle, sizeof(sStyle), "%s", g_sStyleStrings[style].sStyleName)
			#endif
			float timingPct = float(timingCount) / float(MAX_FRAMES);
			AnticheatLog(client, "start strafe, avg: %.2f, dev: %.2f, Timing: %.1f％, style: %s", mean, sd, timingPct * 100, sStyle);

			#if defined TIMER
			if(sd <= 0.4 && timingPct == 1.0)
			#else
			if(sd <= 0.4)
			#endif
			{
				AutoBanPlayer(client);
			}
		}
	}

	//char sOutput[128], sButton[16], sTurn[16], sMove[16];
	//GetTurnDirectionName(turnDir, sTurn, sizeof(sTurn));
	//GetMoveDirectionName(button, sButton, sizeof(sButton));
	//GetMoveDirectionName(moveDir, sMove, sizeof(sMove));

	//PrintToAdmins("Turned %s | Pressed %s | Moving %s | Difference %d",
	//	sTurn,
	//	sButton,
	//	sMove,
	//	g_iStartStrafe_Stats[client][StrafeData_Difference][currFrame]);
}

stock void RecordEndStrafe(int client, int button, int turnDir, const char[] caller)
{
	g_iReleaseTickAtLastEndStrafe[client][button] = g_iLastReleaseTick[client][button][BT_Move];
	g_iLastReleaseTick_Recorded[client][button][BT_Move] = g_iLastReleaseTick[client][button][BT_Move];
	g_iEndStrafe_LastRecordedTick[client] = g_iCmdNum[client];
	int moveDir = GetDirection(client);
	int currFrame = g_iEndStrafe_CurrentFrame[client];
	g_iEndStrafe_Stats[client][StrafeData_Button][currFrame]        = button;
	g_iEndStrafe_Stats[client][StrafeData_TurnDirection][currFrame] = turnDir;
	g_iEndStrafe_Stats[client][StrafeData_MoveDirection][currFrame] = moveDir;
	#if defined TIMER
	g_iEndStrafe_Stats[client][StrafeData_IsTiming][currFrame]      = g_bIsBeingTimed[client];
	#endif

	int difference = g_iLastReleaseTick[client][button][BT_Move] - g_iLastStopTurnTick[client];
	g_iLastTurnTick_Recorded_EndStrafe[client] = g_iLastStopTurnTick[client];

	if(g_iLastTurnTick[client] > g_iLastStopTurnTick[client])
	{
		difference = g_iLastReleaseTick[client][button][BT_Move] - g_iLastTurnTick[client];
		g_iLastTurnTick_Recorded_EndStrafe[client] = g_iLastTurnTick[client];
	}
	g_iEndStrafe_Stats[client][StrafeData_Difference][currFrame] = difference;
	g_bEndStrafe_IsRecorded[client][currFrame]                   = true;
	g_iEndStrafe_Stats[client][StrafeData_Tick][currFrame]       = g_iCmdNum[client];
	g_iEndStrafe_CurrentFrame[client] = (g_iEndStrafe_CurrentFrame[client] + 1) % MAX_FRAMES;

	if(g_iEndStrafe_Stats[client][StrafeData_Difference][currFrame] == g_iEndStrafe_LastTickDifference[client] && !IsInLeftRight(client, g_iRealButtons[client]))
	{
		g_iEndStrafe_IdenticalCount[client]++;

		if (g_iEndStrafe_IdenticalCount[client] >= IDENTICAL_STRAFE_MIN)
		{
			AnticheatLog(client, "too many %i strafes in a row (%d)", g_iEndStrafe_LastTickDifference[client], g_iEndStrafe_IdenticalCount[client]);
			AutoBanPlayer(client);
		}
	}
	else
	{
		if (g_iEndStrafe_IdenticalCount[client] >= 15 && g_iEndStrafe_IdenticalCount[client] < IDENTICAL_STRAFE_MIN)
		{
			AnticheatLog(client, "too many %i strafes in a row (%d)", g_iEndStrafe_LastTickDifference[client], g_iEndStrafe_IdenticalCount[client]);
		}

		g_iEndStrafe_LastTickDifference[client] = g_iEndStrafe_Stats[client][StrafeData_Difference][currFrame];
		g_iEndStrafe_IdenticalCount[client] = 0;
	}

	if(g_iEndStrafe_CurrentFrame[client] == 0)
	{
		int array[MAX_FRAMES];
		int size, timingCount;
		for(int idx; idx < MAX_FRAMES; idx++)
		{
			if(g_bEndStrafe_IsRecorded[client][idx] == true)
			{
				array[idx] = g_iEndStrafe_Stats[client][StrafeData_Difference][idx];
				size++;

				if(g_iEndStrafe_Stats[client][StrafeData_IsTiming][idx] == true)
				{
					timingCount++;
				}
			}
		}
		float mean = GetAverage(array, size);
		float sd   = StandardDeviation(array, size, mean);

		if(sd < 0.8)
		{
			char sStyle[32];
			#if defined TIMER
			int style = Shavit_GetBhopStyle(client);
			Shavit_GetStyleStrings(style, sStyleName, g_sStyleStrings[style].sStyleName, sizeof(stylestrings_t::sStyleName));
			FormatEx(sStyle, sizeof(sStyle), "%s", g_sStyleStrings[style].sStyleName)
			#endif
			float timingPct = float(timingCount) / float(MAX_FRAMES);
			AnticheatLog(client, "end strafe, avg: %.2f, dev: %.2f, Timing: %.1f％, style: %s", mean, sd, timingPct * 100, sStyle);

			#if defined TIMER
			if(sd <= 0.4 && timingPct == 1.0)
			#else
			if(sd <= 0.4)
			#endif
			{
				AutoBanPlayer(client);
			}
		}
	}
	/*
	char sButton[16], sTurn[16], sMove[16];
	GetTurnDirectionName(turnDir, sTurn, sizeof(sTurn));
	GetMoveDirectionName(button, sButton, sizeof(sButton));
	GetMoveDirectionName(moveDir, sMove, sizeof(sMove));

	PrintToAdmins("Turn %s | Press %s | Moving %s | Dif %d | %s",
		sTurn,
		sButton,
		sMove,
		g_iEndStrafe_Stats[client][StrafeData_Difference][currFrame],
		caller);
	*/

	// Check key press count
	//PrintToChat(client, "%d", g_iKeyPressesThisStrafe[client][BT_Move]);
	g_iKeyPressesThisStrafe[client][BT_Move] = 0;
	g_iKeyPressesThisStrafe[client][BT_Key]  = 0;
}

stock void RecordKeySwitch(int client, int button, int oppositeButton, int btype, const char[] caller)
{
	// Record the data
	int currFrame = g_iKeySwitch_CurrentFrame[client][btype];
	g_iKeySwitch_Stats[client][KeySwitchData_Button][btype][currFrame]      = button;
	g_iKeySwitch_Stats[client][KeySwitchData_Difference][btype][currFrame]  = g_iLastPressTick[client][button][btype] - g_iLastReleaseTick[client][oppositeButton][btype];
	#if defined TIMER
	g_iKeySwitch_Stats[client][KeySwitchData_IsTiming][btype][currFrame]    = g_bIsBeingTimed[client];
	#endif
	g_bKeySwitch_IsRecorded[client][btype][currFrame]                       = true;
	g_iKeySwitch_LastRecordedTick[client][btype]                            = g_iCmdNum[client];
	g_iKeySwitch_CurrentFrame[client][btype]                                = (g_iKeySwitch_CurrentFrame[client][btype] + 1) % MAX_FRAMES_KEYSWITCH;
	g_iLastPressTick_Recorded_KS[client][button][btype]                     = g_iLastPressTick[client][button][btype];
	g_iLastReleaseTick_Recorded_KS[client][oppositeButton][btype]           = g_iLastReleaseTick[client][oppositeButton][btype];

	// After we have a new set of data, check to see if they are cheating
	if(g_iKeySwitch_CurrentFrame[client][btype] == 0)
	{
		int array[MAX_FRAMES_KEYSWITCH];
		int size, positiveCount, timingCount, nullCount;
		for(int idx; idx < MAX_FRAMES_KEYSWITCH; idx++)
		{
			if(g_bKeySwitch_IsRecorded[client][btype][idx] == true)
			{
				array[idx] = g_iKeySwitch_Stats[client][KeySwitchData_Difference][btype][idx];
				size++;

				if(btype == BT_Key)
				{
					if(g_iKeySwitch_Stats[client][KeySwitchData_Difference][BT_Key][idx] >= 0)
					{
						positiveCount++;
					}
				}

				if(g_iKeySwitch_Stats[client][KeySwitchData_Difference][BT_Key][idx] == 0)
				{
					nullCount++;
				}

				if(g_iKeySwitch_Stats[client][KeySwitchData_IsTiming][btype][idx] == true)
				{
					timingCount++;
				}
			}
		}

		float mean = GetAverage(array, size);
		float sd   = StandardDeviation(array, size, mean);
		float nullPct = float(nullCount) / float(MAX_FRAMES_KEYSWITCH);
		if(sd <= 0.25 || nullPct >= 0.95)
		{
			if(btype == BT_Key)
			{
				if(positiveCount == MAX_FRAMES_KEYSWITCH)
				{
					//PrintToAdmins("%N key switch positive count every frame", client);
				}
			}

			float timingPct, positivePct;
			positivePct = float(positiveCount) / float(MAX_FRAMES_KEYSWITCH);
			timingPct   = float(timingCount) / float(MAX_FRAMES_KEYSWITCH);


			#if defined TIMER
			char sStyle[32];
			int style = Shavit_GetBhopStyle(client);
			Shavit_GetStyleStrings(style, sStyleName, g_sStyleStrings[style].sStyleName, sizeof(stylestrings_t::sStyleName));
			FormatEx(sStyle, sizeof(sStyle), "%s", g_sStyleStrings[style].sStyleName)
			AnticheatLog(client, "key switch %d, avg: %.2f, dev: %.2f, p: %.2f％, nullPct: %.2f, Timing: %.1f, Style: %s", btype, mean, sd, positivePct * 100, nullPct * 100, timingPct * 100, sStyle);
			#endif

			//AnticheatLog(client, "key switch %d, avg: %.2f, dev: %.2f, p: %.2f％, nullPct: %.2f, Timing: %.1f%%", btype, mean, sd, positivePct * 100, nullPct * 100, timingPct * 100);
			#if !defined TIMER
			AnticheatLog(client, "key switch %d, avg: %.2f, dev: %.2f, p: %.2f％, nullPct: %.2f, Timing: %.1f", btype, mean, sd, positivePct * 100, nullPct * 100, timingPct * 100);
			#endif
			if(IsClientInGame(client) && g_hAntiNull.BoolValue)
			{
				// Add a delay to the kick in case they are using an obvious strafehack that would ban them anyway
				CreateTimer(10.0, Timer_NullKick, GetClientUserId(client));
			}
		}
	}
}

public Action Timer_NullKick(Handle timer, int userid)
{
	int client = GetClientOfUserId(userid);

	if(client != 1)
	{
		KickClient(client, "Kicked for potentional movement config");
	}
}

// If a player triggers this while they are turning and their turning rate is legal from the CheckForIllegalTurning function, then we can probably autoban
void CheckForIllegalMovement(int client, float vel[3], int buttons)
{
	g_iLastInvalidButtonCount[client] = g_InvalidButtonSidemoveCount[client];
	bool bInvalid;
	if(vel[1] > 0 && (buttons & IN_MOVELEFT))
	{
		bInvalid = true;
		g_iLastIllegalReason[client] = 1;
	}
	if(vel[1] > 0 && (buttons & (IN_MOVELEFT|IN_MOVERIGHT) == (IN_MOVELEFT|IN_MOVERIGHT)))
	{
		bInvalid = true;
		g_iLastIllegalReason[client] = 2;
	}
	if(vel[1] < 0 && (buttons & IN_MOVERIGHT))
	{
		bInvalid = true;
		g_iLastIllegalReason[client] = 3;
	}
	if(vel[1] < 0 && (buttons & (IN_MOVELEFT|IN_MOVERIGHT) == (IN_MOVELEFT|IN_MOVERIGHT)))
	{
		bInvalid = true;
		g_iLastIllegalReason[client] = 4;
	}
	if(vel[1] == 0.0 && ((buttons & (IN_MOVELEFT|IN_MOVERIGHT)) == IN_MOVELEFT || (buttons & (IN_MOVELEFT|IN_MOVERIGHT)) == IN_MOVERIGHT))
	{
		bInvalid = true;
		g_iLastIllegalReason[client] = 5;
	}
	if(vel[1] != 0.0 && !(buttons & IN_MOVELEFT|IN_MOVERIGHT))
	{
		bInvalid = true;
		g_iLastIllegalReason[client] = 6;
	}

	if(bInvalid == true)
	{
		g_InvalidButtonSidemoveCount[client]++;
	}
	else
	{
		g_InvalidButtonSidemoveCount[client] = 0;
	}

	if(g_InvalidButtonSidemoveCount[client] >= 4)
	{
		vel[0] = 0.0;
		vel[1] = 0.0;
		vel[2] = 0.0;
	}

	if(g_InvalidButtonSidemoveCount[client] == 0 && g_iLastInvalidButtonCount[client] >= 10)
	{
		AnticheatLog(client, "has invalid buttons and sidemove combination %d %d", g_iLastIllegalReason[client], g_InvalidButtonSidemoveCount[client]);
	}

	/*
	if((vel[0] != float(RoundToFloor(vel[0])) || vel[1] != float(RoundToFloor(vel[1]))) || (RoundFloat(vel[0]) % 25 != 0 || RoundFloat(vel[1]) % 25 != 0))
	{
		// Extra checks for values that the modulo dosent pick up
		if(FloatAbs(vel[0]) != 112.500000 && FloatAbs(vel[1]) != 112.500000)
		{
			vel[0] = 0.0;
			vel[1] = 0.0;
			vel[2] = 0.0;
		}
	}
	*/

	// Prevent 28 velocity exploit
	float fMaxMove;
	if(g_Engine == Engine_CSS)
	{
		fMaxMove = 400.0;
	}
	else if(g_Engine == Engine_CSGO)
	{
		fMaxMove = 450.0;
	}

	if(RoundToFloor(vel[0] * 100.0) % 625 != 0 || RoundToFloor( vel[1] * 100.0 ) % 625 != 0)
	{
		g_iIllegalSidemoveCount[client]++;
		vel[0] = 0.0;
		vel[1] = 0.0;
		vel[2] = 0.0;

		if(FloatAbs(g_fAngleDifference[client][1]) > 0)
		{
			g_iYawChangeCount[client]++;
		}
	}
	else if((FloatAbs(vel[0]) != fMaxMove && vel[0] != 0.0) || (FloatAbs(vel[1]) != fMaxMove && vel[1] != 0.0))
	{
		g_iIllegalSidemoveCount[client]++;

		if(FloatAbs(g_fAngleDifference[client][1]) > 0)
		{
			g_iYawChangeCount[client]++;
		}
	}
	else
	{
		g_iIllegalSidemoveCount[client] = 0;
	}

	if(g_iIllegalSidemoveCount[client] >= 4)
	{
		vel[0] = 0.0;
		vel[1] = 0.0;
		vel[2] = 0.0;
	}

	if(g_iIllegalSidemoveCount[client] == 0)
	{
		if(g_iLastIllegalSidemoveCount[client] >= 10)
		{
			bool bBan;
			if((float(g_iYawChangeCount[client]) / float(g_iLastIllegalSidemoveCount[client])) > 0.3 && g_JoyStick[client] == false) // Rule out xbox controllers, +strafe, and lookstrafe false positives
			{
				bBan = true;
			}

			AnticheatLog(client, "has invalid consecutive movement values, (Joystick = %d, YawChanges = %d/%d) - %s", g_JoyStick[client], g_iYawChangeCount[client], g_iLastIllegalSidemoveCount[client], bBan?"BAN":"SUSPECT");
			//if(bBan) AutoBanPlayer(client);
		}

		g_iYawChangeCount[client] = 0;
	}

	g_iLastIllegalSidemoveCount[client] = g_iIllegalSidemoveCount[client];
}

stock void UpdateButtons(int client, float vel[3], int buttons)
{
	g_iLastButtons[client][BT_Move] = g_iButtons[client][BT_Move];
	g_iButtons[client][BT_Move]     = 0;

	if(vel[0] > 0)
	{
		g_iButtons[client][BT_Move] |= (1 << Button_Forward);
	}
	else if(vel[0] < 0)
	{
		g_iButtons[client][BT_Move] |= (1 << Button_Back);
	}

	if(vel[1] > 0)
	{
		g_iButtons[client][BT_Move] |= (1 << Button_Right);
	}
	else if(vel[1] < 0)
	{
		g_iButtons[client][BT_Move] |= (1 << Button_Left);
	}

	g_iLastButtons[client][BT_Key] = g_iButtons[client][BT_Key];
	g_iButtons[client][BT_Key] = 0;

	if(buttons & IN_MOVELEFT)
	{
		g_iButtons[client][BT_Key] |= (1 << Button_Left);
	}
	if(buttons & IN_MOVERIGHT)
	{
		g_iButtons[client][BT_Key] |= (1 << Button_Right);
	}
	if(buttons & IN_FORWARD)
	{
		g_iButtons[client][BT_Key] |= (1 << Button_Forward);
	}
	if(buttons & IN_BACK)
	{
		g_iButtons[client][BT_Key] |= (1 << Button_Back);
	}
}

void UpdateAngles(int client, float angles[3])
{
	for(int i; i < 2; i++)
	{
		g_fAngleDifference[client][i] = angles[i] - g_fLastAngles[client][i];

		if (g_fAngleDifference[client][i] > 180)
			g_fAngleDifference[client][i] -= 360;
		else if(g_fAngleDifference[client][i] < -180)
			g_fAngleDifference[client][i] += 360;
	}
}

stock float FindDegreeAngleFromVectors(float vOldAngle[3], float vNewAngle[3])
{
	float deltaX = vOldAngle[1] - vNewAngle[1];
	float deltaY = vNewAngle[0] - vOldAngle[0];
	float angleInDegrees = ArcTangent2(deltaX, deltaY) * 180 / FLOAT_PI;

	if(angleInDegrees < 0)
	{
		angleInDegrees += 360;
	}

	return angleInDegrees;
}

void UpdateGains(int client, float vel[3], float angles[3], int buttons)
{
	if(GetEntityFlags(client) & FL_ONGROUND)
	{
		if(g_iTicksOnGround[client] > BHOP_TIME)
		{
			g_iJump[client] = 0;
			g_strafeTick[client] = 0;
			g_flRawGain[client] = 0.0;
			g_iYawTickCount[client] = 0;
			g_iTimingTickCount[client] = 0;
			g_iStrafesDone[client] = 0;
			g_bFirstSixJumps[client] = true;
		}
		g_iTicksOnGround[client]++;
	}
	else
	{
		if(GetEntityMoveType(client) == MOVETYPE_WALK &&
			GetEntProp(client, Prop_Data, "m_nWaterLevel") < 2 &&
			!(GetEntityFlags(client) & FL_ATCONTROLS))
		{
			// prevent false gain while standing still
			if (FloatAbs(vel[0]) < 1.0 && FloatAbs(vel[1]) < 1.0)
				return;

			bool isYawing = false;
			if(buttons & IN_LEFT) isYawing = !isYawing;
			if(buttons & IN_RIGHT) isYawing = !isYawing;
			if(!(g_iYawSpeed[client] < 50.0 || isYawing == false))
			{
				g_iYawTickCount[client]++;
			}

			#if defined TIMER
			if(g_bIsBeingTimed[client])
			{
				g_iTimingTickCount[client]++;
			}
			#endif

			float gaincoeff;
			g_strafeTick[client]++;
			if(g_strafeTick[client] == 1000)
			{
				g_flRawGain[client] *= 998.0 / 999.0;
				g_strafeTick[client]--;
			}

			float velocity[3];
			GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", velocity);

			// skip if player velocity is almost zero (standing still)
			if (FloatAbs(velocity[0]) < 1.0 && FloatAbs(velocity[1]) < 1.0)
				return;

			float fore[3], side[3], wishvel[3], wishdir[3];
			float wishspeed, wishspd, currentgain;

			GetAngleVectors(angles, fore, side, NULL_VECTOR);

			fore[2] = 0.0;
			side[2] = 0.0;
			NormalizeVector(fore, fore);
			NormalizeVector(side, side);

			for(int i = 0; i < 2; i++)
				wishvel[i] = fore[i] * vel[0] + side[i] * vel[1];

			wishspeed = NormalizeVector(wishvel, wishdir);
			if(wishspeed == 0.0)
				return;

			float maxSpeed = GetEntPropFloat(client, Prop_Send, "m_flMaxspeed");
			if(wishspeed > maxSpeed) wishspeed = maxSpeed;

			if(wishspeed)
			{
				wishspd = (wishspeed > 30.0) ? 30.0 : wishspeed;

				currentgain = GetVectorDotProduct(velocity, wishdir);
				if(currentgain < 30.0)
				{
					gaincoeff = (wishspd - FloatAbs(currentgain)) / wishspd;

					if(g_bTouchesWall[client] && gaincoeff > 0.5)
					{
						gaincoeff -= 1;
						gaincoeff = FloatAbs(gaincoeff);
					}

					if(!g_bTouchesFuncRotating[client])
					{
						g_flRawGain[client] += gaincoeff;

						// Only log if gain > small threshold
						if (gaincoeff > 0.01)
						{
							// PrintToServer("Client %d gaincoeff: %f", client, gaincoeff);
						}
					}
				}
			}
		}
		g_iTicksOnGround[client] = 0;
	}
}

bool IsInLeftRight(int client, int buttons)
{
	bool isYawing = false;
	if(buttons & IN_LEFT) isYawing = !isYawing;
	if(buttons & IN_RIGHT) isYawing = !isYawing;
	if(!(g_iYawSpeed[client] < 50.0 || isYawing == false))
	{
		return true;
	}

	return false;
}

float GetGainPercent(int client)
{
	if(g_strafeTick[client] == 0)
	{
		return 0.0;
	}

	float coeffsum = g_flRawGain[client];
	coeffsum /= g_strafeTick[client];
	coeffsum *= 100.0;
	coeffsum = RoundToFloor(coeffsum * 100.0 + 0.5) / 100.0;

	return coeffsum;
}

int GetDesiredTurnDir(int client, int button, bool opposite)
{
	int direction = GetDirection(client);
	int desiredTurnDir = -1;

	// if holding a and going forward then look for left turn
	if(button == Button_Left && direction == Moving_Forward)
	{
		desiredTurnDir = Turn_Left;
	}

	// if holding d and going forward then look for right turn
	else if(button == Button_Right && direction == Moving_Forward)
	{
		desiredTurnDir = Turn_Right;
	}

	// if holding a and going backward then look for right turn
	else if(button == Button_Left && direction == Moving_Back)
	{
		desiredTurnDir = Turn_Right;
	}

	// if holding d and going backward then look for left turn
	else if(button == Button_Right && direction == Moving_Back)
	{
		desiredTurnDir = Turn_Left;
	}

	// if holding w and going left then look for right turn
	else if(button == Button_Forward && direction == Moving_Left)
	{
		desiredTurnDir = Turn_Right;
	}

	// if holding s and going left then look for left turn
	else if(button == Button_Back && direction == Moving_Left)
	{
		desiredTurnDir = Turn_Left;
	}

	// if holding w and going right then look for left turn
	else if(button == Button_Forward && direction == Moving_Right)
	{
		desiredTurnDir = Turn_Left;
	}

	// if holding s and going right then look for right turn
	else if(button == Button_Back && direction == Moving_Right)
	{
		desiredTurnDir = Turn_Right;
	}

	if(opposite == true)
	{
		if(desiredTurnDir == Turn_Right)
		{
			return Turn_Left;
		}
		else
		{
			return Turn_Right;
		}
	}

	return desiredTurnDir;
}

int GetDesiredButton(int client, int dir)
{
	int moveDir = GetDirection(client);
	if(dir == Turn_Left)
	{
		if(moveDir == Moving_Forward)
		{
			return Button_Left;
		}
		else if(moveDir == Moving_Back)
		{
			return Button_Right;
		}
		else if(moveDir == Moving_Left)
		{
			return Button_Back;
		}
		else if(moveDir == Moving_Right)
		{
			return Button_Forward;
		}
	}
	else if(dir == Turn_Right)
	{
		if(moveDir == Moving_Forward)
		{
			return Button_Right;
		}
		else if(moveDir == Moving_Back)
		{
			return Button_Left;
		}
		else if(moveDir == Moving_Left)
		{
			return Button_Forward;
		}
		else if(moveDir == Moving_Right)
		{
			return Button_Back;
		}
	}

	return 0;
}

int GetOppositeButton(int button)
{
	if(button == Button_Forward)
	{
		return Button_Back;
	}
	else if(button == Button_Back)
	{
		return Button_Forward;
	}
	else if(button == Button_Right)
	{
		return Button_Left;
	}
	else if(button == Button_Left)
	{
		return Button_Right;
	}

	return -1;
}

int GetDirection(int client)
{
	float vVel[3];
	GetEntPropVector(client, Prop_Data, "m_vecVelocity", vVel);

	float vAng[3];
	GetClientEyeAngles(client, vAng);

	float movementDiff = ArcTangent(vVel[1] / vVel[0]) * 180.0 / FLOAT_PI;

	if (vVel[0] < 0.0)
	{
		if (vVel[1] > 0.0)
			movementDiff += 180.0;
		else
			movementDiff -= 180.0;
	}

	if(movementDiff < 0.0)
		movementDiff += 360.0;

	if(vAng[1] < 0.0)
		vAng[1] += 360.0;

	movementDiff = movementDiff - vAng[1];

	bool flipped = false;

	if(movementDiff < 0.0)
	{
		flipped = true;
		movementDiff = -movementDiff;
	}

	if(movementDiff > 180.0)
	{
		if(flipped)
			flipped = false;
		else
			flipped = true;

		movementDiff = FloatAbs(movementDiff - 360.0);
	}

	if(-0.1 < movementDiff < 67.5)
	{
		return Moving_Forward; // Forwards
	}
	if(67.5 < movementDiff < 112.5)
	{
		if(flipped)
		{
			return Moving_Right; // Sideways
		}
		else
		{
			return Moving_Left; // Sideways other way
		}
	}
	if(112.5 < movementDiff <= 180.0)
	{
		return Moving_Back; // Backwards
	}
	return 0; // Unknown should never happend
}

stock void GetTurnDirectionName(int direction, char[] buffer, int maxlength)
{
	if(direction == Turn_Left)
	{
		FormatEx(buffer, maxlength, "Left");
	}
	else if(direction == Turn_Right)
	{
		FormatEx(buffer, maxlength, "Right");
	}
	else
	{
		FormatEx(buffer, maxlength, "Unknown");
	}
}

stock void GetMoveDirectionName(int direction, char[] buffer, int maxlength)
{
	if(direction == Moving_Forward)
	{
		FormatEx(buffer, maxlength, "Forward");
	}
	else if(direction == Moving_Back)
	{
		FormatEx(buffer, maxlength, "Backward");
	}
	else if(direction == Moving_Left)
	{
		FormatEx(buffer, maxlength, "Left");
	}
	else if(direction == Moving_Right)
	{
		FormatEx(buffer, maxlength, "Right");
	}
	else
	{
		FormatEx(buffer, maxlength, "Unknown");
	}
}

#if !defined TIMER

/**
* Gets a client's velocity with extra settings to disallow velocity on certain axes
*/
stock float GetClientVelocity(int client, bool UseX, bool UseY, bool UseZ)
{
	float vVel[3];

	if(UseX)
	{
		vVel[0] = GetEntPropFloat(client, Prop_Send, "m_vecVelocity[0]");
	}

	if(UseY)
	{
		vVel[1] = GetEntPropFloat(client, Prop_Send, "m_vecVelocity[1]");
	}

	if(UseZ)
	{
		vVel[2] = GetEntPropFloat(client, Prop_Send, "m_vecVelocity[2]");
	}

	return GetVectorLength(vVel);
}
#endif
