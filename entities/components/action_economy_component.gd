class_name ActionEconomyComponent
extends Node

# SIGNALS
signal ap_changed(current_ap: int, max_ap: int)
signal mp_changed(current_mp: int, max_mp: int)
signal mana_changed(current_mana: int, max_mana: int)

# EXPORTS
## Référence au gestionnaire de statistiques pour obtenir les valeurs en temps réel.
@export var stat_manager: StatManagerComponent

# PRIVATE VARIABLES
var _current_ap: int = 0
var _current_mp: int = 0
var _current_mana: int = 0
var _max_ap: int = 0
var _max_mp: int = 0
var _max_mana: int = 0

# PUBLIC FUNCTIONS
func initialize() -> void:
	if not stat_manager:
		push_error("ActionEconomyComponent: 'stat_manager' manquant.")
		return
		
	_max_ap = roundi(stat_manager.get_stat(StatManagerComponent.StatType.ACTION_POINTS))
	_max_mp = roundi(stat_manager.get_stat(StatManagerComponent.StatType.MOVEMENT_POINTS))
	_max_mana = roundi(stat_manager.get_stat(StatManagerComponent.StatType.MAX_MANA))
	
	_current_ap = _max_ap
	_current_mp = _max_mp
	_current_mana = _max_mana
	
	ap_changed.emit(_current_ap, _max_ap)
	mp_changed.emit(_current_mp, _max_mp)
	mana_changed.emit(_current_mana, _max_mana)

## Appelé par le TurnManager au début du tour de cette unité.
func start_turn() -> void:
	if not stat_manager:
		return
		
	# Interrogation dynamique des statistiques modifiées (Cast float -> int)
	_max_ap = roundi(stat_manager.get_stat(StatManagerComponent.StatType.ACTION_POINTS))
	_max_mp = roundi(stat_manager.get_stat(StatManagerComponent.StatType.MOVEMENT_POINTS))
	_max_mana = roundi(stat_manager.get_stat(StatManagerComponent.StatType.MAX_MANA))
	
	_current_ap = _max_ap
	_current_mp = _max_mp
	
	# Régénération du mana
	var mana_regen: int = roundi(stat_manager.get_stat(StatManagerComponent.StatType.MANA_REGEN))
	_current_mana = clampi(_current_mana + mana_regen, 0, _max_mana)
	
	ap_changed.emit(_current_ap, _max_ap)
	mp_changed.emit(_current_mp, _max_mp)
	mana_changed.emit(_current_mana, _max_mana)

## Appelé par le TurnManager à la fin du tour de cette unité.
func end_turn() -> void:
	_current_ap = 0
	_current_mp = 0
	
	ap_changed.emit(_current_ap, _max_ap)
	mp_changed.emit(_current_mp, _max_mp)

func has_enough_ap(amount: int) -> bool:
	return _current_ap >= amount

func has_enough_mp(amount: int) -> bool:
	return _current_mp >= amount

func has_enough_mana(amount: int) -> bool:
	return _current_mana >= amount

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

func consume_mana(amount: int) -> void:
	if amount <= 0 or not has_enough_mana(amount):
		return
		
	_current_mana -= amount
	mana_changed.emit(_current_mana, _max_mana)

func get_current_ap() -> int:
	return _current_ap

func get_current_mp() -> int:
	return _current_mp

func get_current_mana() -> int:
	return _current_mana

func get_max_ap() -> int:
	return _max_ap

func get_max_mp() -> int:
	return _max_mp

func get_max_mana() -> int:
	return _max_mana