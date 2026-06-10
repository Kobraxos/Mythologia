class_name CoreEnums
extends RefCounted

## Éléments magiques pour les réactions avec l'environnement (Terrain/Surfaces).
enum Element { NONE, FIRE, WATER, ICE, LIGHTNING, EARTH, POISON, LIGHT, SHADOW }

## Événements déclencheurs pour les statuts.
enum StatusTriggerEvent {
	ON_APPLIED,
	ON_REMOVED,
	ON_TURN_START,
	ON_TURN_END,
	ON_DAMAGE_TAKEN,
	ON_DEATH_PREVENTED,
	ON_ACTION_USED,
	ON_MOVED
}

## Conditions contextuelles pour les statuts.
enum StatusTriggerCondition {
	ALWAYS,
	ELEVATION_GREATER_THAN_ZERO,
	TARGET_HP_BELOW_HALF,
	SOURCE_HAS_LINE_OF_SIGHT
}

## Types d'effets visuels pour l'Object Pooling.
enum VfxType {
	NONE,
	IMPACT_HIT,
	HEAL_EFFECT,
	SHIELD_GRANTED,
	DODGE_DUST,
	DASH_TRAIL,
	LEAP_TRAIL,
	TELEPORT_OUT,
	TELEPORT_IN
}

## Types de textes flottants pour le retour visuel.
enum FloatingTextType {
	DAMAGE,
	CRIT,
	HEAL,
	DODGE,
	SHIELD,
	IMMUNE,
	MISS
}

## Factions pour les unités et points de spawn.
enum Faction { PLAYER, ENEMY }

