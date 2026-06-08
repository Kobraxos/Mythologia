class_name AIUtils
extends RefCounted

## Utilitaire statique pour centraliser les calculs récurrents de l'IA (Ciblage, Distances, Alignement)

# CONSTANTS
const MAX_DISTANCE: int = 10000
const INVALID_HEX: Vector3i = Vector3i(-999, -999, -999)

# PUBLIC STATIC FUNCTIONS
## Vérifie si la cible correspond à l'alignement requis par la compétence (Allié/Ennemi/N'importe).
static func is_valid_alignment(caster: Unit, target: Unit, alignment: SkillData.TargetAlignment) -> bool:
	var is_enemy: bool = target.faction != caster.faction
	
	match alignment:
		SkillData.TargetAlignment.ENEMY:
			return is_enemy
		SkillData.TargetAlignment.ALLY:
			return not is_enemy
		SkillData.TargetAlignment.ANY:
			return true
			
	return false

## Retourne l'unité ennemie la plus proche de la position de départ.
static func get_closest_enemy(start_hex: Vector3i, caster_faction: Unit.Faction, unit_positions: Dictionary[Vector3i, Unit]) -> Unit:
	var best_target: Unit = null
	var min_dist: int = MAX_DISTANCE
	
	for hex: Vector3i in unit_positions:
		var target_unit: Unit = unit_positions[hex]
		if not is_instance_valid(target_unit) or target_unit.faction == caster_faction:
			continue
			
		var dist: int = HexMath.distance_2d(start_hex, hex)
		if dist < min_dist:
			min_dist = dist
			best_target = target_unit
			
	return best_target
