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

#define PLUGIN_VERSION "0.1.0"
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

public void OnPluginStart() {
	for (int i = MaxClients; i > 0; --i) {
		if (IsClientInGame(i)) {
			OnClientPutInServer(i);
		}
	}
}

public void OnClientPutInServer(int client) {
	SDKHook(client, SDKHook_WeaponEquipPost, OnWeaponEquipPost);
}

public void OnWeaponEquipPost(int client, int weapon) {
	int weaponAccountID = GetEntProp(weapon, Prop_Send, "m_iAccountID");
	
	/**
	 * Stock weapons on a human player also use their SteamID.
	 * The one problem is that bot-spawned weapons may have non-zero (positive) iAccountID
	 * values.
	 * 
	 * Since bots can't pick up weapons, we'll just ignore that for now and fix it later.
	 * 
	 * There's also the rare case where a player with a low account ID joins and a bot's
	 * using the same accountid.  TODO fix?
	 */ 
	if (!IsFakeClient(client) && GetSteamAccountID(client) != weaponAccountID) {
		TF2_OnWeaponPickup(client, weapon);
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
 * Unfortunately, there's no builtin way to figure out what grade a specific item is.
 * 
 * I don't want to force people to choose a TF2 item support library so for now I'll just use a
 * lookup table for the sake of laziness.
 * 
 * We stop iterating through the array once the value read is 0.
 */
int g_ItemRarityLookup[][] = {
	{	/* Common loot */
		/* basically everything not in this list, so we don't really care */
		0
	},
	
	{	/* Rare loot */
	
		/* Assassin-grade weapons */
		15009, 15011, 15007, /* Concealed Killer Collection */
		15052, 15053, 15048, /* Powerhouse Collection */
		15089, 15111, 15113, 15092, /* Pyroland Collection */
		15141, 15142, 15152, /* Warbird Collection */
		
		30666, // C.A.P.P.E.R
		30668, // Giger Counter
		
		0
	},
	
	{	/* Ultra-rare loot */
		
		/* Elite-grade weapons */
		15013, 15014, /* Concealed Killer Collection */
		15059, 15045, /* Powerhouse Collection */
		15090, 15091, 15112, /* Pyroland Collection */
		15141, 15151, /* Warbird Collection */
		
		30667, // Batsaber
		169, // Golden Wrench
		423, // Saxxy
		
		0
	},
};

/**
 * Determines the perceived "rarity" of a weapon.
 */
WeaponRarity GetWeaponPerceivedRarity(int weapon) {
	int iEntityQuality = GetEntProp(weapon, Prop_Send, "m_iEntityQuality");
	int iDefIndex = GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex");
	
	// unusual quality or australium?  rare as fuck
	if (iEntityQuality == QUALITY_UNUSUAL || TF2_IsWeaponAustralium(weapon)) {
		return Weapon_UltraRare;
	} else if (iDefIndex) {
		// look up the rarity by defindex
		for (int r = 0; r < view_as<int>(WeaponRarity); r++) {
			int i;
			do {
				int lookup = g_ItemRarityLookup[r][i];
				
				if (lookup == iDefIndex) {
					return view_as<WeaponRarity>(r);
				}
			} while (g_ItemRarityLookup[r][++i] != 0);
		}
	}
	
	// just a standard weapon pickup
	return Weapon_Common;
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
