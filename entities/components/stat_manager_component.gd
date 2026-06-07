class_name StatManagerComponent
extends Node

# SIGNALS
## Émis lorsqu'une statistique est modifiée (par un buff, debuff, ou retrait d'effet).
signal stat_changed(stat: StatType, new_value: float)

# ENUMS
enum StatType {
	MAX_HEALTH,
	MAX_MANA,
	HP_REGEN,
	MANA_REGEN,
	ACTION_POINTS,
	MOVEMENT_POINTS,
	INITIATIVE
}

enum ModifierType {
	FLAT,
	PERCENT
}

# CLASSES
class StatModifier extends RefCounted:
	var id: int
	var stat: StatType
	var type: ModifierType
	var value: float
	
	func _init(p_id: int, p_stat: StatType, p_type: ModifierType, p_value: float) -> void:
		id = p_id
		stat = p_stat
		type = p_type
		value = p_value

# PRIVATE VARIABLES
var _base_stats: UnitStats
var _modifiers: Array[StatModifier] = []
var _next_mod_id: int = 1

# PUBLIC FUNCTIONS
func initialize(stats: UnitStats) -> void:
	_base_stats = stats

## Retourne la valeur finale d'une statistique (Base + Flat) * (1.0 + Percent).
func get_stat(stat: StatType) -> float:
	if not _base_stats:
		return 0.0
		
	var base_value: float = _get_base_value(stat)
	var flat_bonus: float = 0.0
	var percent_bonus: float = 0.0
	
	for mod: StatModifier in _modifiers:
		if mod.stat == stat:
			if mod.type == ModifierType.FLAT:
				flat_bonus += mod.value
			elif mod.type == ModifierType.PERCENT:
				percent_bonus += mod.value
				
	# Formule AAA standard : L'addition s'applique avant la multiplication
	return (base_value + flat_bonus) * (1.0 + percent_bonus)

## Ajoute un modificateur et retourne son ID unique pour traçabilité.
func add_modifier(stat: StatType, type: ModifierType, value: float) -> int:
	var mod: StatModifier = StatModifier.new(_next_mod_id, stat, type, value)
	_next_mod_id += 1
	_modifiers.append(mod)
	
	stat_changed.emit(stat, get_stat(stat))
	return mod.id

## Retire un modificateur via son ID unique.
func remove_modifier(id: int) -> void:
	for i: int in range(_modifiers.size()):
		if _modifiers[i].id == id:
			var stat_affected: StatType = _modifiers[i].stat
			_modifiers.remove_at(i)
			stat_changed.emit(stat_affected, get_stat(stat_affected))
			return

# PRIVATE FUNCTIONS
func _get_base_value(stat: StatType) -> float:
	match stat:
		StatType.MAX_HEALTH:
			return float(_base_stats.max_health)
		StatType.MAX_MANA:
			return float(_base_stats.max_mana)
		StatType.HP_REGEN:
			return float(_base_stats.hp_regen_per_turn)
		StatType.MANA_REGEN:
			return float(_base_stats.mana_regen_per_turn)
		StatType.ACTION_POINTS:
			return float(_base_stats.action_points)
		StatType.MOVEMENT_POINTS:
			return float(_base_stats.movement_points)
		StatType.INITIATIVE:
			return float(_base_stats.initiative)
	return 0.0