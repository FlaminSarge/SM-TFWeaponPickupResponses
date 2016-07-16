/**
 * [TF2] Weapon Pickup Responses
 * 
 * Players use their MvM loot responses when picking up rare weapons.
 */
#pragma semicolon 1
#include <sourcemod>

#include <sdkhooks>
#include <sdktools>

#undef REQUIRE_PLUGIN
#include <tf2attributes>
#define REQUIRE_PLUGIN

#pragma newdecls required

#define PLUGIN_VERSION "0.0.1"
public Plugin myinfo = {
    name = "[TF2] Weapon Pickup Responses",
    author = "nosoop",
    description = "Use MvM loot responses when picking up rare weapons.",
    version = PLUGIN_VERSION,
    url = "https://github.com/nosoop/"
}

enum WeaponRarity {
	Weapon_Common = 0,
	Weapon_Rare,
	Weapon_UltraRare
};

enum ItemGrade {
	Grade_None = -1,
	Grade_Civilian = 0,
	Grade_Freelance,
	Grade_Mercenary,
	Grade_Commando,
	Grade_Assassin,
	Grade_Elite
};

bool g_bAttribsSupported;

// Stores the most recent weapon picked up in one frame.
int g_NewWeaponEquipped[MAXPLAYERS+1];

public void OnPluginStart() {
	for (int i = MaxClients; i > 0; --i) {
		if (IsClientInGame(i)) {
			OnClientPutInServer(i);
		}
	}
}

public void OnClientPutInServer(int client) {
	g_NewWeaponEquipped[client] = 0;
	SDKHook(client, SDKHook_WeaponEquipPost, OnWeaponEquipPost);
}

public void OnWeaponEquipPost(int client, int weapon) {
	g_NewWeaponEquipped[client] = weapon;
	RequestFrame(OnWeaponEquipPostFrame, client);
}

public void OnWeaponEquipPostFrame(int client) {
	// we're just modifying an array, doesn't matter if the client d/c's beforehand
	g_NewWeaponEquipped[client] = 0;
}

/**
 * Checks if the command called was +use_action_slot_item_server.  If a weapon was picked up
 * this frame, assume the player called the weapon pickup command.
 */
public void OnClientCommandKeyValues_Post(int client, KeyValues kv) {
	char command[128];
	kv.GetSectionName(command, sizeof(command));
	
	if (StrEqual(command, "+use_action_slot_item_server") && g_NewWeaponEquipped[client]) {
		TF2_OnWeaponPickup(client, g_NewWeaponEquipped[client]);
	}
}

/**
 * Called when a client presses +use_action_slot_item on the same frame an WeaponEquipPost
 * callback is fired.  Speaks a specific voice response depending on the perceived rarity of a
 * weapon.
 * 
 * Can't think of any other way to specifically detect weapon pickups that don't involve
 * lower-level hooks (via CTFPlayer::PickupWeaponFromOther or CTFPlayer::CanPickupDroppedWeapon)
 */
void TF2_OnWeaponPickup(int client, int weapon) {
	WeaponRarity rarity = GetWeaponPerceivedRarity(weapon);
	
	switch (rarity) {
		case Weapon_Rare: {
			SpeakResponseConcept(client, "TLK_MVM_LOOT_RARE");
		}
		case Weapon_UltraRare: {
			SpeakResponseConcept(client, "TLK_MVM_LOOT_ULTRARARE");
		}
		case Weapon_Common: {
			// nobody cares about commons
		}
		default: {
			// okay what did you do
			ThrowError("Unexpected rarity value %d", rarity);
		}
	}
}

#define QUALITY_UNUSUAL 5

/**
 * Determines the perceived "rarity" of a weapon.
 */
WeaponRarity GetWeaponPerceivedRarity(int weapon) {
	int iEntityQuality = GetEntProp(weapon, Prop_Send, "m_iEntityQuality");
	
	ItemGrade weaponGrade = TF2_GetWeaponItemGrade(weapon);
	
	// unusual quality, elite grade, or australium?  rare as fuck
	if (iEntityQuality == QUALITY_UNUSUAL || weaponGrade == Grade_Elite
			|| TF2_IsWeaponAustralium(weapon)) {
		return Weapon_UltraRare;
	} else if (weaponGrade == Grade_Assassin) {
		return Weapon_Rare;
	}
	
	// just a standard weapon pickup
	return Weapon_Common;
}

/**
 * Unfortunately, there's no builtin way to figure out what grade a specific item is.
 * 
 * I don't want to force people to choose a TF2 item support library so for now I'll just use a
 * lookup table for the sake of laziness.
 */
int g_ItemGradeLookup[][] = {
	{ /* we don't care for civilian */ },
	{ /* or for freelance */ },
	{ /* or for mercenary */ },
	{ /* ooooor for commando */ },
	{ 15009, 15011, 15007, 15052, 15053, 15048, 20668, 30666, 15089, 15111, 15113, 15092, 15141,
		15142, 15152 },
	{ 15013, 15014, 15059, 15045, 20667, 15090, 15091, 15112, 15141, 15151 },
};

int g_ItemGradeTableLengths[] = {
	0, 0, 0, 0, 15, 10
};

ItemGrade TF2_GetWeaponItemGrade(int weapon) {
	int iDefIndex = GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex");
	for (int g = 0; g < view_as<int>(ItemGrade); g++) {
		for (int d = 0; d < g_ItemGradeTableLengths[g]; d++) {
			if (iDefIndex == g_ItemGradeLookup[g][d]) {
				return view_as<ItemGrade>(g);
			}
		}
	}
	return Grade_None;
}

bool TF2_IsWeaponAustralium(int weapon) {
	if (g_bAttribsSupported) {
		Address pAttrib;
		if ((pAttrib = TF2Attrib_GetByName(weapon, "is australium item")) != Address_Null) {
			return TF2Attrib_GetValue(pAttrib) != 0;
		}
	}
	return false;
}

// function stocks

stock void SpeakResponseConcept(int client, const char[] concept) {
	SetVariantString(concept);
	AcceptEntityInput(client, "SpeakResponseConcept");
}

/* plugin include boilerplate */
public void OnAllPluginsLoaded() {
	g_bAttribsSupported = LibraryExists("tf2attributes");
}
 
public void OnLibraryRemoved(const char[] name) {
	if (StrEqual(name, "tf2attributes")) {
		g_bAttribsSupported = false;
	}
}
 
public void OnLibraryAdded(const char[] name) {
	if (StrEqual(name, "tf2attributes")) {
		g_bAttribsSupported = true;
	}
}
