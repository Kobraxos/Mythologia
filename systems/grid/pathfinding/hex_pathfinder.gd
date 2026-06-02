class_name HexPathfinder
extends RefCounted

# PRIVATE VARIABLES
var _astar: AStar3D = AStar3D.new()
var _hex_to_id: Dictionary[Vector3i, int] = {}
var _id_to_hex: Dictionary[int, Vector3i] = {}
var _next_id: int = 0

# PUBLIC FUNCTIONS
## Ajoute une case franchissable au graphe de navigation.
func add_hex(hex: Vector3i) -> void:
	if _hex_to_id.has(hex):
		return
		
	var id: int = _next_id
	_next_id += 1
	
	_hex_to_id[hex] = id
	_id_to_hex[id] = hex
	
	# L'A* utilise la position 3D pour la distance heuristique. 
	# Nos coordonnées cubiques (X, Y, Z) fonctionnent parfaitement comme heuristique euclidienne native !
	_astar.add_point(id, Vector3(hex))

func has_hex(hex: Vector3i) -> bool:
	return _hex_to_id.has(hex)

## Connecte deux cases adjacentes (bidirectionnel par défaut).
func connect_hexes(hex_a: Vector3i, hex_b: Vector3i) -> void:
	if _hex_to_id.has(hex_a) and _hex_to_id.has(hex_b):
		_astar.connect_points(_hex_to_id[hex_a], _hex_to_id[hex_b])

## Calcule et retourne le chemin le plus court sous forme de tableau de coordonnées.
func get_hex_path(start: Vector3i, end: Vector3i) -> Array[Vector3i]:
	if not _hex_to_id.has(start) or not _hex_to_id.has(end):
		return []
		
	var id_path: PackedInt64Array = _astar.get_id_path(_hex_to_id[start], _hex_to_id[end])
	var hex_path: Array[Vector3i] = []
	for id: int in id_path:
		hex_path.append(_id_to_hex[id])
	return hex_path

## Retourne toutes les cases accessibles depuis une position avec un coût maximum (Dijkstra/BFS)
func get_reachable_hexes(start: Vector3i, max_movement: int) -> Array[Vector3i]:
	if not _hex_to_id.has(start):
		return []

	var reachable: Array[Vector3i] = []
	var frontier: Array[Vector3i] = [start]
	var cost_so_far: Dictionary[Vector3i, int] = {start: 0}
	var frontier_index: int = 0

	# Simulation d'une Queue O(1) via pointeur de lecture au lieu de pop_front()
	while frontier_index < frontier.size():
		var current: Vector3i = frontier[frontier_index]
		frontier_index += 1
		reachable.append(current)

		var neighbors: Array[Vector3i] = HexMath.get_all_neighbors(current)
		for next_hex: Vector3i in neighbors:
			if not _hex_to_id.has(next_hex):
				continue
			
			var new_cost: int = cost_so_far[current] + 1
			if new_cost <= max_movement:
				if not cost_so_far.has(next_hex) or new_cost < cost_so_far[next_hex]:
					cost_so_far[next_hex] = new_cost
					if not frontier.has(next_hex):
						frontier.append(next_hex)

	return reachable