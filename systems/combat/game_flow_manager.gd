class_name GameFlowManager
extends Node

## Le GameFlowManager est l'orchestrateur de haut niveau. 
## Il déclenche les séquences asynchrones sans connaître l'implémentation interne des sous-systèmes.

# GODOT BUILT-IN FUNCTIONS
func _ready() -> void:
	# L'arbre est verrouillé pendant le _ready. 
	# On demande l'initialisation asynchrone de la boucle de jeu à la frame suivante.
	call_deferred("_start_battle_sequence")

# PRIVATE FUNCTIONS
func _start_battle_sequence() -> void:
	# Étape 1 : Demande de génération de la grille (captée par GridGenerator)
	GridEvents.request_grid_generation.emit()
	
	# Note sur le flux de la séquence :
	# - GridGenerator génère et émet GridEvents.grid_topology_ready
	# - BattleManager capte grid_topology_ready, place les unités et émet CombatEvents.units_spawned
	# - TurnManager capte units_spawned et lance le combat (TurnEvents.battle_started)
