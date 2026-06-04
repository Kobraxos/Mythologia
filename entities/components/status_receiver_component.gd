class_name StatusReceiverComponent
extends Node

# SIGNALS
signal status_applied(status: StatusEffectData)
signal status_removed(status: StatusEffectData)

# EXPORTS
@export_category("Dependencies")
@export var stat_manager: StatManagerComponent
@export var health_component: HealthComponent

# CLASSES
class ActiveStatus extends RefCounted:
	var data: StatusEffectData
	var remaining_turns: int
	var modifier_ids: Array[int] = []
	
	func _init(p_data: StatusEffectData) -> void:
		data = p_data
		remaining_turns = p_data.duration_in_turns

# PRIVATE VARIABLES
var _active_statuses: Array[ActiveStatus] = []

# PUBLIC FUNCTIONS
func apply_status(status_data: StatusEffectData) -> void:
	if not status_data:
		return
		
	var new_status: ActiveStatus = ActiveStatus.new(status_data)
	
	# Si le statut a des altérations de statistiques, on les injecte et on garde la trace (Les IDs).
	if stat_manager:
		for mod_data: StatusModifierData in status_data.modifiers:
			var mod_id: int = stat_manager.add_modifier(mod_data.stat, mod_data.type, mod_data.value)
			new_status.modifier_ids.append(mod_id)
			
	_active_statuses.append(new_status)
	status_applied.emit(status_data)

## TICK ORDER (DÉBUT) : Déclenche les DoT et HoT (Poison, Régénération) avant l'action du joueur.
func apply_start_turn_effects() -> void:
	if not health_component:
		return
		
	for status: ActiveStatus in _active_statuses:
		if status.data.damage_per_turn > 0:
			health_component.take_damage(status.data.damage_per_turn)
		if status.data.healing_per_turn > 0:
			health_component.heal(status.data.healing_per_turn)

## TICK ORDER (FIN) : Réduit les durées et nettoie les effets expirés.
func tick_durations() -> void:
	# Boucle inversée obligatoire (Reverse Loop) pour éviter le décalage d'index lors de la suppression.
	for i: int in range(_active_statuses.size() - 1, -1, -1):
		var status: ActiveStatus = _active_statuses[i]
		status.remaining_turns -= 1
		
		if status.remaining_turns <= 0:
			_remove_status_at(i)

func clear_all_statuses() -> void:
	for i: int in range(_active_statuses.size() - 1, -1, -1):
		_remove_status_at(i)

# PRIVATE FUNCTIONS
func _remove_status_at(index: int) -> void:
	var status: ActiveStatus = _active_statuses[index]
	
	if stat_manager:
		for mod_id: int in status.modifier_ids:
			stat_manager.remove_modifier(mod_id)
			
	_active_statuses.remove_at(index)
	status_removed.emit(status.data)