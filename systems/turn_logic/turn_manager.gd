class_name TurnManager
extends Node

# PRIVATE VARIABLES
var _units: Array[Unit] = []
var _active_unit_index: int = -1
var _current_round: int = 0

# GODOT BUILT-IN FUNCTIONS
func _ready() -> void:
	# Le manager écoute le mégaphone, il se fiche de savoir qui a pressé le bouton.
	TurnEvents.turn_end_requested.connect(_on_turn_end_requested)

# PUBLIC FUNCTIONS
func register_unit(unit: Unit) -> void:
	if not _units.has(unit):
		_units.append(unit)

func start_battle() -> void:
	if _units.is_empty():
		return
		
	# DDD : Tri du tableau par Initiative (ordre décroissant)
	_units.sort_custom(func(a: Unit, b: Unit) -> bool:
		var init_a: int = a.stats.initiative if a.stats else 0
		var init_b: int = b.stats.initiative if b.stats else 0
		return init_a > init_b
	)
	
	_current_round = 1
	TurnEvents.battle_started.emit()
	TurnEvents.round_changed.emit(_current_round)
	
	_active_unit_index = -1
	next_turn()

func next_turn() -> void:
	if _units.is_empty():
		return
		
	if _active_unit_index >= 0 and _active_unit_index < _units.size():
		var previous: Unit = _units[_active_unit_index]
		if is_instance_valid(previous):
			previous.end_turn()
			TurnEvents.turn_ended.emit(previous)
			
	_active_unit_index += 1
	if _active_unit_index >= _units.size():
		_active_unit_index = 0
		_current_round += 1
		TurnEvents.round_changed.emit(_current_round)
		
	var active: Unit = _units[_active_unit_index]
	if is_instance_valid(active):
		active.start_turn()
		TurnEvents.active_unit_changed.emit(active)

# SIGNAL HANDLERS
func _on_turn_end_requested() -> void:
	next_turn()