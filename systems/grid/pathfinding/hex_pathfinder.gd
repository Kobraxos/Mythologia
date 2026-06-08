class_name HexPathfinder
extends RefCounted

# PRIVATE VARIABLES
## Graphe topologique brut. Clé: Vector3i, Valeur: Dictionnaire { world_pos: Vector3, cost: float, neighbors: Array[Vector3i] }
var _grid_graph: Dictionary[Vector3i, Dictionary] = {}

const MAX_PATH_CACHE_SIZE: int = 3
## Cache LRU O(1). Clé: Array, Valeur: Array[Vector3i] (Chemin copié)
var _path_cache: Dictionary = {}

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
	_path_cache.clear()

func has_hex(hex: Vector3i) -> bool:
	return _grid_graph.has(hex)

## Connecte deux cases adjacentes (bidirectionnel par défaut).
func connect_hexes(hex_a: Vector3i, hex_b: Vector3i) -> void:
	if _grid_graph.has(hex_a) and _grid_graph.has(hex_b):
		var changed: bool = false
		if not _grid_graph[hex_a].neighbors.has(hex_b):
			_grid_graph[hex_a].neighbors.append(hex_b)
			changed = true
		if not _grid_graph[hex_b].neighbors.has(hex_a):
			_grid_graph[hex_b].neighbors.append(hex_a)
			changed = true
		if changed:
			_path_cache.clear()

## Vide le cache des chemins (à appeler lors d'un mouvement ou de la mort d'une unité)
func clear_dynamic_cache() -> void:
	_path_cache.clear()

## Calcule et retourne le chemin le plus court sous forme de tableau de coordonnées.
func get_hex_path(start: Vector3i, end: Vector3i, stats: UnitStats, unit_faction: int, occupied_hexes: Dictionary) -> Array[Vector3i]:
	if not _grid_graph.has(start) or not _grid_graph.has(end):
		return []
		
	# L'Array sert directement de clé de hachage au Dictionnaire
	var cache_key: Array = [start, end, stats.movement_type, stats.max_elevation_jump]
	
	if _path_cache.has(cache_key):
		var cached_path: Array[Vector3i] = _path_cache[cache_key]
		# Maintien du LRU : Godot 4 conserve l'ordre d'insertion des Dictionnaires
		_path_cache.erase(cache_key)
		_path_cache[cache_key] = cached_path
		return cached_path.duplicate()

	# Règle d'arrêt : On ne peut pas terminer son mouvement sur une case occupée
	if end != start and occupied_hexes.has(end):
		return []
			
	if stats.movement_type == UnitStats.MovementType.TELEPORTING:
		var path: Array[Vector3i] = [start, end]
		_add_to_cache(cache_key, path)
		return path
		
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
			_add_to_cache(cache_key, path)
			return path

		for next_hex: Vector3i in _grid_graph[current].neighbors:
			if not _is_traversable(current, next_hex, stats, unit_faction, occupied_hexes):
				continue
				
			var tentative_g: float = g_score[current] + _get_cost(next_hex, stats)
			
			if tentative_g < g_score.get(next_hex, INF):
				came_from[next_hex] = current
				g_score[next_hex] = tentative_g
				f_score[next_hex] = tentative_g + _heuristic(next_hex, end)
				if not frontier.has(next_hex):
					frontier.append(next_hex)

	_add_to_cache(cache_key, [])
	return []

## Calcule le coût total en PM d'un chemin donné pour une unité spécifique.
func get_path_cost(path: Array[Vector3i], stats: UnitStats) -> int:
	var total_cost: float = 0.0
	for i in range(1, path.size()):
		total_cost += _get_cost(path[i], stats)
	return ceili(total_cost)

## Retourne toutes les cases accessibles depuis une position avec un coût maximum (Dijkstra/BFS)
func get_reachable_hexes(start: Vector3i, stats: UnitStats, available_mp: int, unit_faction: int, occupied_hexes: Dictionary) -> Array[Vector3i]:
	if not _grid_graph.has(start):
		return []

	var reachable: Array[Vector3i] = []
	
	if stats.movement_type == UnitStats.MovementType.TELEPORTING:
		var radius_hexes: Array[Vector3i] = HexMath.get_hexes_in_radius(start, available_mp)
		for h: Vector3i in radius_hexes:
			if _grid_graph.has(h) and not occupied_hexes.has(h):
				reachable.append(h)
		return reachable

	var frontier: Array[Vector3i] = [start]
	var cost_so_far: Dictionary[Vector3i, float] = {start: 0.0}
	var frontier_index: int = 0

	# Simulation d'une Queue O(1) via pointeur de lecture au lieu de pop_front()
	while frontier_index < frontier.size():
		var current: Vector3i = frontier[frontier_index]
		frontier_index += 1
		
		# Règle d'arrêt : Ne pas exposer une case occupée comme atteignable (sauf la sienne)
		if current == start or not occupied_hexes.has(current):
			reachable.append(current)

		for next_hex: Vector3i in _grid_graph[current].neighbors:
			if not _is_traversable(current, next_hex, stats, unit_faction, occupied_hexes):
				continue
			
			var new_cost: float = cost_so_far[current] + _get_cost(next_hex, stats)
			
			if new_cost <= available_mp:
				if not cost_so_far.has(next_hex) or new_cost < cost_so_far[next_hex]:
					cost_so_far[next_hex] = new_cost
					if not frontier.has(next_hex):
						frontier.append(next_hex)

	return reachable

# PRIVATE FUNCTIONS
func _add_to_cache(key: Array, path: Array[Vector3i]) -> void:
	_path_cache[key] = path.duplicate()
	if _path_cache.size() > MAX_PATH_CACHE_SIZE:
		# Supprime la clé la plus ancienne (Least Recently Used)
		_path_cache.erase(_path_cache.keys()[0])

func _heuristic(a: Vector3i, b: Vector3i) -> float:
	return _grid_graph[a].world_pos.distance_to(_grid_graph[b].world_pos)

func _is_traversable(current: Vector3i, next_hex: Vector3i, stats: UnitStats, unit_faction: int, occupied_hexes: Dictionary) -> bool:
	# 1. Résolution dynamique : Les unités bloquent-elles le passage ?
	if occupied_hexes.has(next_hex):
		var occupant := occupied_hexes[next_hex] as Unit
		if occupant and occupant.faction != unit_faction:
			return false # Les ennemis bloquent toujours

	# 2. Résolution topologique mathématique
	if stats.movement_type == UnitStats.MovementType.FLYING:
		return true
	return abs(next_hex.z - current.z) <= stats.max_elevation_jump

func _get_cost(hex: Vector3i, stats: UnitStats) -> float:
	if stats.movement_type == UnitStats.MovementType.FLYING:
		return 1.0 # Le vol ignore les marécages et autres coûts de terrain
	return _grid_graph[hex].cost