class_name AIActionMoveToEnemy
extends AIAction

# PUBLIC FUNCTIONS
func execute(context: AIContext) -> void:
	var unit: Unit = context.unit
	var start_hex: Vector3i = context.current_hex
	
	# 1. Recherche de la cible ennemie la plus proche
	var best_target: Unit = AIUtils.get_closest_enemy(start_hex, unit.faction, GridManager.unit_positions)
			
	if not best_target or not GridManager.pathfinder:
		_end_action()
		return
		
	# 2. Pathfinding complet vers la cible
	# AAA FIX : Le pathfinder est désormais strict et refuse les chemins finissant sur une case occupée.
	# On lui fournit donc une copie de l'état de la grille où la case de l'ennemi est virtuellement libre.
	var sim_occupied: Dictionary = GridManager.unit_positions.duplicate()
	sim_occupied.erase(best_target.current_hex)
	var path: Array[Vector3i] = GridManager.pathfinder.get_hex_path(start_hex, best_target.current_hex, unit.stats, unit.faction, sim_occupied)
	
	# Si aucun chemin ou déjà au contact
	if path.is_empty() or path.size() <= 1:
		_end_action()
		return
		
	# 3. On tronque la dernière case (on s'arrête à côté de l'ennemi, pas SUR lui)
	path.pop_back()
	
	# 4. Troncature selon les Points de Mouvement (ActionEconomy)
	var final_path: Array[Vector3i] = [path[0]]
	var current_cost: int = 0
	var available_mp: int = unit.stats.movement_points
	
	if unit.action_economy:
		available_mp = unit.action_economy.get_current_mp()
		
	for i: int in range(1, path.size()):
		var step_path: Array[Vector3i] = [path[i-1], path[i]]
		var step_cost: int = GridManager.pathfinder.get_path_cost(step_path, unit.stats)
		
		if current_cost + step_cost > available_mp:
			break
			
		current_cost += step_cost
		final_path.append(path[i])
		
	if final_path.size() <= 1:
		_end_action()
		return
		
	# 5. Paiement et Exécution
	if unit.action_economy:
		unit.action_economy.consume_mp(current_cost)
		
	unit.movement_finished.connect(_end_action, CONNECT_ONE_SHOT)
	unit.execute_path(final_path)

# PRIVATE FUNCTIONS
func _end_action() -> void:
	finished.emit()