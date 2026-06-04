class_name HexPathfinder
extends RefCounted

# PRIVATE VARIABLES
## Graphe topologique brut. Clé: Vector3i, Valeur: Dictionnaire { world_pos: Vector3, cost: float, neighbors: Array[Vector3i] }
var _grid_graph: Dictionary[Vector3i, Dictionary] = {}

# PUBLIC FUNCTIONS
## Ajoute une case franchissable au graphe de navigation.
func add_hex(hex: Vector3i, world_pos: Vector3, movement_cost: float = 1.0) -> void:
	if _grid_graph.has(hex):
		return
		
	_grid_graph[hex] = {
		"world_pos": world_pos,
		"cost": movement_cost,
		"neighbors": [] as Array[Vector3i]
	}

func has_hex(hex: Vector3i) -> bool:
	return _grid_graph.has(hex)

## Connecte deux cases adjacentes (bidirectionnel par défaut).
func connect_hexes(hex_a: Vector3i, hex_b: Vector3i) -> void:
	if _grid_graph.has(hex_a) and _grid_graph.has(hex_b):
		if not _grid_graph[hex_a].neighbors.has(hex_b):
			_grid_graph[hex_a].neighbors.append(hex_b)
		if not _grid_graph[hex_b].neighbors.has(hex_a):
			_grid_graph[hex_b].neighbors.append(hex_a)

## Calcule et retourne le chemin le plus court sous forme de tableau de coordonnées.
func get_hex_path(start: Vector3i, end: Vector3i, stats: UnitStats) -> Array[Vector3i]:
	if not _grid_graph.has(start) or not _grid_graph.has(end):
		return []
		
	if stats.movement_type == UnitStats.MovementType.TELEPORTING:
		return [start, end] # Téléportation directe
		
	var frontier: Array[Vector3i] = [start]
	var came_from: Dictionary[Vector3i, Vector3i] = {}
	var g_score: Dictionary[Vector3i, float] = {start: 0.0}
	var f_score: Dictionary[Vector3i, float] = {start: _heuristic(start, end)}

	while not frontier.is_empty():
		var current: Vector3i = frontier[0]
		var current_index: int = 0
		for i in range(1, frontier.size()):
			if f_score.get(frontier[i], INF) < f_score.get(current, INF):
				current = frontier[i]
				current_index = i
		
		frontier.remove_at(current_index)

		if current == end:
			var path: Array[Vector3i] = [current]
			while came_from.has(current):
				current = came_from[current]
				path.push_front(current)
			return path

		for next_hex: Vector3i in _grid_graph[current].neighbors:
			if not _is_traversable(current, next_hex, stats):
				continue
				
			var tentative_g: float = g_score[current] + _get_cost(next_hex, stats)
			
			if tentative_g < g_score.get(next_hex, INF):
				came_from[next_hex] = current
				g_score[next_hex] = tentative_g
				f_score[next_hex] = tentative_g + _heuristic(next_hex, end)
				if not frontier.has(next_hex):
					frontier.append(next_hex)

	return []

## Calcule le coût total en PM d'un chemin donné pour une unité spécifique.
func get_path_cost(path: Array[Vector3i], stats: UnitStats) -> int:
	var total_cost: float = 0.0
	for i in range(1, path.size()):
		total_cost += _get_cost(path[i], stats)
	return ceili(total_cost)

## Retourne toutes les cases accessibles depuis une position avec un coût maximum (Dijkstra/BFS)
func get_reachable_hexes(start: Vector3i, stats: UnitStats, available_mp: int) -> Array[Vector3i]:
	if not _grid_graph.has(start):
		return []

	var reachable: Array[Vector3i] = []
	
	if stats.movement_type == UnitStats.MovementType.TELEPORTING:
		var radius_hexes: Array[Vector3i] = HexMath.get_hexes_in_radius(start, available_mp)
		for h: Vector3i in radius_hexes:
			if _grid_graph.has(h):
				reachable.append(h)
		return reachable

	var frontier: Array[Vector3i] = [start]
	var cost_so_far: Dictionary[Vector3i, float] = {start: 0.0}
	var frontier_index: int = 0

	# Simulation d'une Queue O(1) via pointeur de lecture au lieu de pop_front()
	while frontier_index < frontier.size():
		var current: Vector3i = frontier[frontier_index]
		frontier_index += 1
		reachable.append(current)

		for next_hex: Vector3i in _grid_graph[current].neighbors:
			if not _is_traversable(current, next_hex, stats):
				continue
			
			var new_cost: float = cost_so_far[current] + _get_cost(next_hex, stats)
			
			if new_cost <= available_mp:
				if not cost_so_far.has(next_hex) or new_cost < cost_so_far[next_hex]:
					cost_so_far[next_hex] = new_cost
					if not frontier.has(next_hex):
						frontier.append(next_hex)

	return reachable

# PRIVATE FUNCTIONS
func _heuristic(a: Vector3i, b: Vector3i) -> float:
	return _grid_graph[a].world_pos.distance_to(_grid_graph[b].world_pos)

func _is_traversable(current: Vector3i, next_hex: Vector3i, stats: UnitStats) -> bool:
	if stats.movement_type == UnitStats.MovementType.FLYING:
		return true
	return abs(next_hex.z - current.z) <= stats.max_elevation_jump

func _get_cost(hex: Vector3i, stats: UnitStats) -> float:
	if stats.movement_type == UnitStats.MovementType.FLYING:
		return 1.0 # Le vol ignore les marécages et autres coûts de terrain
	return _grid_graph[hex].cost