class_name GridDisplacementSystem
extends Node

## Système AAA de gestion des déplacements forcés sur la grille.
## Autorité unique sur les collisions topologiques lors d'un Knockback, Pull ou Dash.

# PUBLIC API
func get_knockback_destination(origin_unit: Unit, target_unit: Unit, distance: int) -> Vector3i:
	return _process_displacement(origin_unit, target_unit, distance, true)

func get_pull_destination(origin_unit: Unit, target_unit: Unit, distance: int) -> Vector3i:
	return _process_displacement(origin_unit, target_unit, distance, false)

# PRIVATE FUNCTIONS
func _process_displacement(origin_unit: Unit, target_unit: Unit, distance: int, is_knockback: bool) -> Vector3i:
	var origin_2d := Vector2i(origin_unit.current_hex.x, origin_unit.current_hex.y)
	var target_2d := Vector2i(target_unit.current_hex.x, target_unit.current_hex.y)
	
	var trajectory_2d: Array[Vector2i] = []
	if is_knockback:
		trajectory_2d = _get_knockback_trajectory_2d(origin_2d, target_2d, distance)
	else:
		trajectory_2d = _get_pull_trajectory_2d(origin_2d, target_2d, distance)
		
	var final_hex: Vector3i = target_unit.current_hex
	if trajectory_2d.is_empty(): return final_hex
	
	var current_hex_3d := target_unit.current_hex
	
	for hex_2d: Vector2i in trajectory_2d:
		var z: int = _get_surface_elevation(hex_2d)
		if z == -999: break # Gouffre ou bord de carte
			
		var next_hex_3d := Vector3i(hex_2d.x, hex_2d.y, z)
		if GridManager.unit_positions.has(next_hex_3d) and GridManager.unit_positions[next_hex_3d] != target_unit: break # Bloqué par une autre unité
		if z - current_hex_3d.z > 1: break # Mur infranchissable
			
		final_hex = next_hex_3d
		current_hex_3d = final_hex
		
	return final_hex

# MATHÉMATIQUES INTERNES
func _get_knockback_trajectory_2d(origin: Vector2i, target: Vector2i, distance: int) -> Array[Vector2i]:
	var line: Array[Vector2i] = []
	if origin == target or distance <= 0: return line
	var dist_to_target := HexAoE.hex_distance_2d(origin, target)
	for i: int in range(1, distance + 1):
		line.append(HexAoE.cubic_to_axial(HexAoE.axial_to_cubic(origin).lerp(HexAoE.axial_to_cubic(target), float(dist_to_target + i) / float(dist_to_target))))
	return line

func _get_pull_trajectory_2d(origin: Vector2i, target: Vector2i, distance: int) -> Array[Vector2i]:
	var line: Array[Vector2i] = []
	if origin == target or distance <= 0: return line
	var dist_to_target := HexAoE.hex_distance_2d(origin, target)
	var actual_distance: int = min(distance, dist_to_target - 1)
	for i: int in range(1, actual_distance + 1):
		line.append(HexAoE.cubic_to_axial(HexAoE.axial_to_cubic(target).lerp(HexAoE.axial_to_cubic(origin), float(i) / float(dist_to_target))))
	return line

func _get_surface_elevation(hex_2d: Vector2i) -> int:
	for z: int in range(GridManager.max_elevation, -1, -1):
		if GridManager.terrain_tiles.has(Vector3i(hex_2d.x, hex_2d.y, z)): return z
	return -999
