/**
 * [TF2] Weapon Pickup Responses
 * 
 * Players use their MvM loot responses when picking up rare weapons.
 * 
 * Thanks to Tomato and FlaminSarge for notifying and fixing some issue with Australiums!
 */
#pragma semicolon 1
#include <sourcemod>

#include <sdkhooks>
#include <sdktools>

#undef REQUIRE_PLUGIN
#tryinclude <tf2attributes>
#define REQUIRE_PLUGIN

#pragma newdecls required

#define PLUGIN_VERSION "0.1.8"
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

bool g_bAttribsSupported;

public void OnPluginStart() {
	for (int i = MaxClients; i > 0; --i) {
		if (IsClientInGame(i)) {
			OnClientPutInServer(i);
		}
	}
	
	#if !defined _tf2attributes_included
		LogMessage("Plugin was not compiled with TF2Attributes support.");
	#endif
}

public void OnClientPutInServer(int client) {
	SDKHook(client, SDKHook_WeaponEquipPost, OnWeaponEquipPost);
}

public void OnWeaponEquipPost(int client, int weapon) {
//This breaks first bot weapon equip, so don't do it
//	if (IsFakeClient(client)) {
//		SetEntProp(weapon, Prop_Send, "m_iAccountID", 0);
//	}
	
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
 * Called when a weapon not owned by the specified client is picked up.
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
 * We stop iterating through the array once the value read is -1.
 */
int g_ItemRarityLookup[][] = {
	{	/* Common loot */
		/* basically everything not in this list, so we don't really care */
		-1
	},
	
	{	/* Rare loot */
	
		/* Assassin-grade weapons */
		15009, 15011, 15007, /* Concealed Killer Collection */
		15052, 15053, 15048, /* Powerhouse Collection */
		15089, 15111, 15113, 15092, /* Pyroland Collection */
		15141, 15142, 15152, /* Warbird Collection */
		
		30666, // C.A.P.P.E.R
		30668, // Giger Counter
		
		-1
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
		
		-1
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
	} else {
		// look up the rarity by defindex
		for (int r = 0; r < view_as<int>(WeaponRarity); r++) {
			int i;
			do {
				int lookup = g_ItemRarityLookup[r][i];
				
				if (lookup == iDefIndex) {
					return view_as<WeaponRarity>(r);
				}
			} while (g_ItemRarityLookup[r][++i] != -1);
		}
	}
	
	// just a standard weapon pickup
	return Weapon_Common;
}

bool TF2_IsWeaponAustralium(int weapon) {
	// If TF2Attributes doesn't exist, that's too bad.
	#if defined _tf2attributes_included
		if (g_bAttribsSupported) {
			// you can tell it's Australium because of the way it is
			if (TF2Attrib_GetByName(weapon, "is australium item") != Address_Null) {
				return true;
			} else {
				// item server-specific value? uhhhhhh
				int iAttribIndices[16];
				float flAttribValues[16];
				
				int nAttribs = TF2Attrib_GetSOCAttribs(weapon, iAttribIndices, flAttribValues);
				
				for (int i = 0; i < nAttribs; i++) {
					if (iAttribIndices[i] == 2027) {
						return true;
					}
				}
			}
		}
	#endif
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
