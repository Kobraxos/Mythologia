class_name GridDisplacementSystem
extends Node

## Système AAA de gestion des déplacements forcés sur la grille.
## Autorité unique sur les collisions topologiques lors d'un Knockback, Pull ou Dash.

const MAX_ELEVATION_DIFF: int = 1
const MAX_DISTANCE: int = 9999

# PUBLIC API
func get_knockback_destination(origin_unit: Unit, target_unit: Unit, distance: int) -> Vector3i:
	if not is_instance_valid(origin_unit) or not is_instance_valid(target_unit):
		push_error("GridDisplacement: origin_unit ou target_unit est null ou libéré.")
		return HexMath.INVALID_HEX
	return _process_displacement(origin_unit, target_unit, distance, true)

func get_pull_destination(origin_unit: Unit, target_unit: Unit, distance: int) -> Vector3i:
	if not is_instance_valid(origin_unit) or not is_instance_valid(target_unit):
		push_error("GridDisplacement: origin_unit ou target_unit est null ou libéré.")
		return HexMath.INVALID_HEX
	return _process_displacement(origin_unit, target_unit, distance, false)

func get_dash_destination(caster: Unit, target_hex: Vector3i) -> Vector3i:
	if not is_instance_valid(caster):
		push_error("GridDisplacement: caster est null ou libéré.")
		return HexMath.INVALID_HEX
	return _resolve_caster_destination(caster, target_hex, true)

func get_leap_destination(caster: Unit, target_hex: Vector3i) -> Vector3i:
	if not is_instance_valid(caster):
		push_error("GridDisplacement: caster est null ou libéré.")
		return HexMath.INVALID_HEX
	return _resolve_caster_destination(caster, target_hex, false)

func get_teleport_destination(caster: Unit, target_hex: Vector3i) -> Vector3i:
	if not is_instance_valid(caster):
		push_error("GridDisplacement: caster est null ou libéré.")
		return HexMath.INVALID_HEX
	return _resolve_caster_destination(caster, target_hex, false)

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
		var z: int = GridManager.get_hex_elevation(Vector3i(hex_2d.x, hex_2d.y, 0))
		if z == GridManager.INVALID_ELEVATION: break # Gouffre ou bord de carte
			
		var next_hex_3d := Vector3i(hex_2d.x, hex_2d.y, z)
		if GridManager.unit_positions.has(next_hex_3d) and GridManager.unit_positions[next_hex_3d] != target_unit: break # Bloqué par une autre unité
		if z - current_hex_3d.z > MAX_ELEVATION_DIFF: break # Mur infranchissable
			
		final_hex = next_hex_3d
		current_hex_3d = final_hex
		
	return final_hex

func _resolve_caster_destination(caster: Unit, target_hex: Vector3i, check_path: bool) -> Vector3i:
	# AAA 1 : Si la case cible est libre (ex: ciblage au sol), on atterrit dessus directement.
	var target_z: int = GridManager.get_hex_elevation(target_hex)
	if target_z != GridManager.INVALID_ELEVATION:
		var target_3d := Vector3i(target_hex.x, target_hex.y, target_z)
		var is_free: bool = not GridManager.unit_positions.has(target_3d) or GridManager.unit_positions[target_3d] == caster
		
		if is_free:
			if not check_path or _check_dash_path(caster.current_hex, target_3d):
				return target_3d
				
	# AAA 2 : Si la case est occupée (ex: attaque sur un ennemi), on s'arrête sur la case adjacente la plus proche pour frapper en mêlée.
	return _find_best_adjacent_hex(caster, target_hex, check_path)

func _find_best_adjacent_hex(caster: Unit, target_hex: Vector3i, check_path: bool) -> Vector3i:
	var origin_hex := caster.current_hex
	var candidates: Array[Vector3i] = HexMath.get_all_neighbors(target_hex)
	var best_hex := origin_hex
	var min_dist := MAX_DISTANCE
	
	for candidate_hex: Vector3i in candidates:
		var z: int = GridManager.get_hex_elevation(candidate_hex)
		if z == GridManager.INVALID_ELEVATION: continue
		var hex_3d := Vector3i(candidate_hex.x, candidate_hex.y, z)
		
		if GridManager.unit_positions.has(hex_3d) and GridManager.unit_positions[hex_3d] != caster:
			continue
			
		if abs(z - target_hex.z) > MAX_ELEVATION_DIFF:
			continue
			
		if check_path and not _check_dash_path(origin_hex, hex_3d):
			continue
			
		var dist: int = HexMath.distance_2d(origin_hex, hex_3d)
		if dist < min_dist:
			min_dist = dist
			best_hex = hex_3d
			
	return best_hex

func _check_dash_path(origin_hex: Vector3i, target_hex: Vector3i) -> bool:
	var origin_2d := Vector2i(origin_hex.x, origin_hex.y)
	var dest_2d := Vector2i(target_hex.x, target_hex.y)
	var dist: int = HexMath.distance_2d_flat(origin_2d, dest_2d)
	var line: Array[Vector2i] = []
	
	if dist > 0:
		for i: int in range(1, dist + 1):
			line.append(HexMath.cubic_to_axial(HexMath.axial_to_cubic(origin_2d).lerp(HexMath.axial_to_cubic(dest_2d), float(i) / float(dist))))
			
	var current_hex_3d := origin_hex
	for p_2d: Vector2i in line:
		var p_z: int = GridManager.get_hex_elevation(Vector3i(p_2d.x, p_2d.y, 0))
		if p_z == GridManager.INVALID_ELEVATION or abs(p_z - current_hex_3d.z) > MAX_ELEVATION_DIFF:
			return false
		
		# Vérifier que la case traversée n'est pas un obstacle ou une unité bloquante
		var p_3d := Vector3i(p_2d.x, p_2d.y, p_z)
		if GridManager.unit_positions.has(p_3d) and p_3d != target_hex:
			return false
			
		current_hex_3d = p_3d
		
	return true

# MATHÉMATIQUES INTERNES
func _get_knockback_trajectory_2d(origin: Vector2i, target: Vector2i, distance: int) -> Array[Vector2i]:
	var line: Array[Vector2i] = []
	if origin == target or distance <= 0: return line
	var dist_to_target: int = HexMath.distance_2d_flat(origin, target)
	for i: int in range(1, distance + 1):
		line.append(HexMath.cubic_to_axial(HexMath.axial_to_cubic(origin).lerp(HexMath.axial_to_cubic(target), float(dist_to_target + i) / float(dist_to_target))))
	return line

func _get_pull_trajectory_2d(origin: Vector2i, target: Vector2i, distance: int) -> Array[Vector2i]:
	var line: Array[Vector2i] = []
	if origin == target or distance <= 0: return line
	var dist_to_target: int = HexMath.distance_2d_flat(origin, target)
	var actual_distance: int = min(distance, dist_to_target - 1)
	for i: int in range(1, actual_distance + 1):
		line.append(HexMath.cubic_to_axial(HexMath.axial_to_cubic(target).lerp(HexMath.axial_to_cubic(origin), float(i) / float(dist_to_target))))
	return line
