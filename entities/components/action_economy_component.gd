class_name ActionEconomyComponent
extends Node

# SIGNALS
signal ap_changed(current_ap: int, max_ap: int)
signal mp_changed(current_mp: int, max_mp: int)
signal turn_started()
signal turn_ended()

# PRIVATE VARIABLES
var _stats: UnitStats
var _current_ap: int = 0
var _current_mp: int = 0
var _max_ap: int = 0
var _max_mp: int = 0

# PUBLIC FUNCTIONS
func initialize(stats: UnitStats) -> void:
	_stats = stats
	_max_ap = _stats.action_points
	_max_mp = _stats.movement_points
	_current_ap = _max_ap
	_current_mp = _max_mp

## Appelé par le TurnManager au début du tour de cette unité.
func start_turn() -> void:
	if not _stats:
		return
		
	# Note AAA : Plus tard, ces valeurs max seront potentiellement demandées au StatManagerComponent
	# pour inclure les buffs/debuffs (ex: statut "Hâte" ou "Vertige des hauteurs").
	_max_ap = _stats.action_points
	_max_mp = _stats.movement_points
	
	_current_ap = _max_ap
	_current_mp = _max_mp
	
	ap_changed.emit(_current_ap, _max_ap)
	mp_changed.emit(_current_mp, _max_mp)
	turn_started.emit()

## Appelé par le TurnManager à la fin du tour de cette unité.
func end_turn() -> void:
	_current_ap = 0
	_current_mp = 0
	
	ap_changed.emit(_current_ap, _max_ap)
	mp_changed.emit(_current_mp, _max_mp)
	turn_ended.emit()

func has_enough_ap(amount: int) -> bool:
	return _current_ap >= amount

func has_enough_mp(amount: int) -> bool:
	return _current_mp >= amount

func consume_ap(amount: int) -> void:
	if amount <= 0 or not has_enough_ap(amount):
		return
		
	_current_ap -= amount
	ap_changed.emit(_current_ap, _max_ap)

func consume_mp(amount: int) -> void:
	if amount <= 0 or not has_enough_mp(amount):
		return
		
	_current_mp -= amount
	mp_changed.emit(_current_mp, _max_mp)

func get_current_ap() -> int:
	return _current_ap

func get_current_mp() -> int:
	return _current_mp