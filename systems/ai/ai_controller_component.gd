class_name AIControllerComponent
extends Node

# CONSTANTS
const AI_THINK_DELAY: float = 0.5

# EXPORTS
@export var available_actions: Array[AIAction] = []

# PRIVATE VARIABLES
var _unit: Unit
var _consecutive_fails: int = 0
var _last_ap: int = -1
var _last_mp: int = -1

# GODOT BUILT-IN FUNCTIONS
func _ready() -> void:
	_unit = get_parent() as Unit
	if not _unit:
		push_error("AIControllerComponent doit être un enfant direct d'un nœud Unit.")
		return
		
	# L'IA écoute le chef d'orchestre global
	TurnEvents.active_unit_changed.connect(_on_active_unit_changed)

# PRIVATE FUNCTIONS
func _process_turn() -> void:
	# AAA : Garde-fou Anti-Deadlock (State Watchdog)
	var current_ap: int = _unit.action_economy.get_current_ap() if _unit.action_economy else 0
	var current_mp: int = _unit.action_economy.get_current_mp() if _unit.action_economy else 0
	
	if current_ap == _last_ap and current_mp == _last_mp:
		_consecutive_fails += 1
	else:
		_consecutive_fails = 0
		
	_last_ap = current_ap
	_last_mp = current_mp
	
	if _consecutive_fails >= 5:
		push_warning("AI Deadlock détecté sur %s. Fin de tour forcée." % _unit.name)
		_end_turn()
		return

	var context := AIContext.new(_unit)
	var best_action: AIAction = null
	var best_score: float = 0.0 # AAA : Le score DOIT être > 0 pour être exécuté.
	
	# Pattern "Utility AI" - On score chaque action possible
	for action: AIAction in available_actions:
		if action:
			var score: float = action.calculate_score(context)
			if score > best_score:
				best_score = score
				best_action = action
			
	# Exécution
	if best_action:
		if not best_action.finished.is_connected(_on_action_finished):
			best_action.finished.connect(_on_action_finished, CONNECT_ONE_SHOT)
		best_action.execute(context)
	else:
		_end_turn()

func _end_turn() -> void:
	TurnEvents.turn_end_requested.emit()

# SIGNAL HANDLERS
func _on_action_finished() -> void:
	# L'action est terminée, l'IA reprend sa réflexion pour enchaîner ou passer le tour.
	get_tree().create_timer(AI_THINK_DELAY).timeout.connect(_process_turn)

func _on_active_unit_changed(active_unit: Unit) -> void:
	_consecutive_fails = 0
	_last_ap = -1
	_last_mp = -1
	if active_unit == _unit:
		# AAA : Sécurité. L'IA ne prend pas le contrôle des unités du Joueur.
		if _unit.faction != Unit.Faction.ENEMY:
			return
			
		# Léger délai pour le "Juice" (L'IA réfléchit) et éviter un call-stack instantané
		get_tree().create_timer(AI_THINK_DELAY).timeout.connect(_process_turn)