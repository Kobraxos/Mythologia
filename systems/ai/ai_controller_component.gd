class_name AIControllerComponent
extends Node

# CONSTANTS
const AI_THINK_DELAY: float = 0.5

# EXPORTS
@export var available_actions: Array[AIAction] = []

# PRIVATE VARIABLES
var _unit: Unit

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
	if active_unit == _unit:
		# AAA : Sécurité. L'IA ne prend pas le contrôle des unités du Joueur.
		if _unit.faction != Unit.Faction.ENEMY:
			return
			
		# Léger délai pour le "Juice" (L'IA réfléchit) et éviter un call-stack instantané
		get_tree().create_timer(AI_THINK_DELAY).timeout.connect(_process_turn)