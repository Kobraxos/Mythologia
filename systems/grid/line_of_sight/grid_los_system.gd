class_name GridLosSystem
extends Node

## Système AAA de gestion de Ligne de Vue (LoS) par Raycasting Data-Oriented 2.5D.
## Élimine les accès Node3D en maintenant une topologie plate O(1).

const INVALID_ELEVATION: int = -999
const INVALID_HEX: Vector3i = Vector3i(0, 0, INVALID_ELEVATION)
const HEX_DIRECTIONS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1),
	Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1)
]

# ÉTATS MATHÉMATIQUES INTERNES (Data-Oriented)
var _static_heights: Dictionary = {}
var _dynamic_blockers: Dictionary = {}

# CACHE
var _aoe_visibility_cache: Dictionary = {}

func _ready() -> void:
	_connect_to_events()

# PUBLIC API
## Calcule toutes les cases affectées par un sort (Shape pur + Interprétation DOD).
func get_affected_hexes(caster_hex: Vector3i, target_hex: Vector3i, skill: SkillData, ignored_hex: Vector3i = INVALID_HEX) -> Array[Vector3i]:
	var shape: SkillData.AreaShape = skill.aoe_shape
	var radius: int = skill.aoe_radius
	var pierces: bool = skill.pierces_obstacles
	
	var caster_2d := Vector2i(caster_hex.x, caster_hex.y)
	var target_2d := Vector2i(target_hex.x, target_hex.y)
	var raw_hexes_2d: Array[Vector2i] = []

	match shape:
		SkillData.AreaShape.CIRCLE: raw_hexes_2d = HexAoE.get_circle_2d(target_2d, radius)
		SkillData.AreaShape.LINE: raw_hexes_2d = HexAoE.get_line_2d(caster_2d, target_2d, radius)
		SkillData.AreaShape.CONE: raw_hexes_2d = HexAoE.get_cone_2d(caster_2d, target_2d, radius)
		SkillData.AreaShape.RING: raw_hexes_2d = HexAoE.get_ring_2d(target_2d, radius, radius)
		SkillData.AreaShape.FLOOD_FILL:
			var target_z: int = _get_elevation(target_2d)
			if target_z != INVALID_ELEVATION:
				return _get_flood_fill(Vector3i(target_2d.x, target_2d.y, target_z), radius, pierces, ignored_hex, skill)
			return []
		_: raw_hexes_2d = [target_2d]

	var valid_3d: Array[Vector3i] = []
	for hex_2d: Vector2i in raw_hexes_2d:
		var z: int = _get_elevation(hex_2d)
		if z == INVALID_ELEVATION:
			if shape == SkillData.AreaShape.LINE and not pierces: break # La ligne s'arrête net dans le vide
			continue
			
		var current_3d := Vector3i(hex_2d.x, hex_2d.y, z)
		
		if not pierces:
			if shape == SkillData.AreaShape.LINE:
				# 1. Vérifie si le chemin pour atteindre cette case est déjà bloqué en amont
				if not has_line_of_sight(caster_hex, current_3d, ignored_hex):
					break
					
				# 2. La case est atteinte (on l'ajoute à la zone d'effet)
				valid_3d.append(current_3d)
				
				# 3. Si cette case est elle-même un obstacle, elle encaisse mais bloque la suite
				if current_3d != ignored_hex and _has_dynamic_blocker(current_3d):
					break
					
				# AAA : Le blocage topologique doit respecter les contraintes verticales du sort
				var elevation_diff: int = current_3d.z - caster_hex.z
				if elevation_diff > skill.max_elevation_up or elevation_diff < -skill.max_elevation_down:
					break
					
				continue # Case validée et ajoutée, on passe à la suivante
			else:
				var los_origin: Vector3i = target_hex if (shape == SkillData.AreaShape.CIRCLE or shape == SkillData.AreaShape.RING) else caster_hex
				if not has_line_of_sight(los_origin, current_3d, ignored_hex):
					continue
				
		valid_3d.append(current_3d)
		
	return valid_3d

## Calcule les cases d'où le sort peut être lancé (Ring pur + Interprétation DOD).
func get_valid_casting_range(caster_hex: Vector3i, skill: SkillData, ignored_hex: Vector3i = INVALID_HEX) -> Array[Vector3i]:
	if skill.max_range == 0:
		return [caster_hex]
		
	var caster_2d := Vector2i(caster_hex.x, caster_hex.y)
	var raw_ring: Array[Vector2i] = []
	
	if skill.is_linear_only:
		raw_ring = HexAoE.get_linear_range_2d(caster_2d, skill.min_range, skill.max_range)
	else:
		raw_ring = HexAoE.get_ring_2d(caster_2d, skill.min_range, skill.max_range)
		
	var valid_hexes: Array[Vector3i] = []
	
	for hex_2d: Vector2i in raw_ring:
		var z: int = _get_elevation(hex_2d)
		if z == INVALID_ELEVATION: continue
			
		var elevation_diff: int = z - caster_hex.z
		if elevation_diff > skill.max_elevation_up or elevation_diff < -skill.max_elevation_down: continue
			
		var target_3d := Vector3i(hex_2d.x, hex_2d.y, z)
		if skill.requires_line_of_sight and not has_line_of_sight(caster_hex, target_3d, ignored_hex): continue
			
		valid_hexes.append(target_3d)
	return valid_hexes

## Calcule tous les hexagones visibles depuis l'origine dans un rayon donné.
func get_visible_hexes(origin: Vector3i, radius: int, ignored_hex: Vector3i = INVALID_HEX) -> Array[Vector3i]:
	var cache_key: String = "%s_%d_%s" % [origin, radius, ignored_hex]
	if _aoe_visibility_cache.has(cache_key):
		return _aoe_visibility_cache[cache_key]
		
	var visible_hexes: Array[Vector3i] = [] 
	var center_2d := Vector2i(origin.x, origin.y)
	
	# Génération radiale mathématique
	for q: int in range(-radius, radius + 1):
		for r: int in range(max(-radius, -q - radius), min(radius, -q + radius) + 1):
			var current_2d := Vector2i(center_2d.x + q, center_2d.y + r)
			var z: int = _get_elevation(current_2d)
			
			if z != INVALID_ELEVATION:
				var target_3d := Vector3i(current_2d.x, current_2d.y, z)
				if has_line_of_sight(origin, target_3d, ignored_hex):
					visible_hexes.append(target_3d)
	
	_aoe_visibility_cache[cache_key] = visible_hexes
	return visible_hexes

## Lancer de Rayon O(1) avec Bresenham Hexagonal (Shadowcasting linéaire).
func has_line_of_sight(start_hex: Vector3i, target_hex: Vector3i, ignored_hex: Vector3i = INVALID_HEX) -> bool:
	var start_2d := Vector2i(start_hex.x, start_hex.y)
	var target_2d := Vector2i(target_hex.x, target_hex.y)
	var dist: int = HexMath.distance_2d_flat(start_2d, target_2d)

	if dist <= 1:
		return true

	var start_cube := HexMath.axial_to_cubic(start_2d)
	var target_cube := HexMath.axial_to_cubic(target_2d)

	for i: int in range(1, dist):
		var t: float = float(i) / float(dist)
		var current_cube := start_cube.lerp(target_cube, t)
		var current_2d := HexMath.cubic_to_axial(current_cube)
		
		var current_z: int = _get_elevation(current_2d)
		if current_z == INVALID_ELEVATION:
			return false # Traversée du vide interdite
			
		var current_3d := Vector3i(current_2d.x, current_2d.y, current_z)
		
		# AAA : Paradoxe du bloqueur dynamique O(1)
		if current_3d != ignored_hex and _has_dynamic_blocker(current_3d):
			return false
			
		# AAA : Topologie 2.5D O(1)
		var max_z: int = max(start_hex.z, target_hex.z)
		if current_z > max_z:
			return false

	return true

# PRIVATE FUNCTIONS (Event Listeners & Cache Invalidation)
func _connect_to_events() -> void:
	GridEvents.grid_topology_ready.connect(_on_grid_topology_ready)
	GridEvents.unit_moved.connect(_on_dynamic_blocker_changed)
	# Respect des domaines : la mort appartient à CombatEvents
	CombatEvents.unit_died.connect(_on_unit_died)

func _on_grid_topology_ready(topology: Dictionary) -> void:
	_static_heights.clear()
	for hex_3d: Vector3i in topology.keys():
		var hex_2d := Vector2i(hex_3d.x, hex_3d.y)
		_static_heights[hex_2d] = hex_3d.z
	_invalidate_los_cache()

func _on_dynamic_blocker_changed(_unit: Node, from_hex: Vector3i, to_hex: Vector3i) -> void:
	if _dynamic_blockers.has(from_hex):
		_dynamic_blockers.erase(from_hex)
	if to_hex.z != INVALID_ELEVATION:
		_dynamic_blockers[to_hex] = true
	_invalidate_los_cache()

func _on_unit_died(unit: Unit) -> void:
	if _dynamic_blockers.has(unit.current_hex):
		_dynamic_blockers.erase(unit.current_hex)
		_invalidate_los_cache()

func _invalidate_los_cache() -> void:
	_aoe_visibility_cache.clear()
	
# UTILS DOD (Formes Topologiques)
## Algorithme de propagation BFS (Breadth-First Search) pour la forme FLOOD_FILL.
func _get_flood_fill(start_3d: Vector3i, radius: int, pierces: bool, ignored_hex: Vector3i, skill: SkillData) -> Array[Vector3i]:
	var visited: Dictionary = {}
	var queue: Array[Vector3i] = [start_3d]
	visited[start_3d] = 0

	while not queue.is_empty():
		var current_3d: Vector3i = queue.pop_front()
		var current_dist: int = visited[current_3d]

		if current_dist >= radius:
			continue

		var current_2d := Vector2i(current_3d.x, current_3d.y)

		for dir: Vector2i in HEX_DIRECTIONS:
			var neighbor_2d := current_2d + dir
			var z: int = _get_elevation(neighbor_2d)
			if z == INVALID_ELEVATION: continue

			var neighbor_3d := Vector3i(neighbor_2d.x, neighbor_2d.y, z)
			if visited.has(neighbor_3d): continue

			# Propagation 2.5D : Respecte les limites d'élévation définies par le sort !
			var elevation_diff: int = z - current_3d.z
			if elevation_diff > skill.max_elevation_up or elevation_diff < -skill.max_elevation_down: continue
			
			visited[neighbor_3d] = current_dist + 1
			if not pierces and neighbor_3d != ignored_hex and _has_dynamic_blocker(neighbor_3d): continue
			queue.append(neighbor_3d)

	var result: Array[Vector3i] = []
	result.assign(visited.keys())
	return result

# UTILS MATHÉMATIQUES DOD
func _get_elevation(hex_2d: Vector2i) -> int:
	return _static_heights.get(hex_2d, INVALID_ELEVATION)

func _has_dynamic_blocker(hex_3d: Vector3i) -> bool:
	return _dynamic_blockers.has(hex_3d)
