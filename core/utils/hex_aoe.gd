class_name HexAoE
extends RefCounted

## Utilitaire AAA de résolution géométrique hexagonale (Target Data Pattern).
## Ne gère aucune logique de combat, uniquement des mathématiques vectorielles.

# PUBLIC FUNCTIONS
## Calcule la portée valide d'une compétence (anneau entre min_range et max_range).
static func get_valid_casting_range(caster_hex: Vector3i, skill: SkillData, ignored_hex: Vector3i = Vector3i(0, 0, -999)) -> Array[Vector3i]:
	var valid_hexes: Array[Vector3i] = []
	var center_2d := Vector2i(caster_hex.x, caster_hex.y)
	
	# Si la portée est 0, on cible uniquement le lanceur
	if skill.max_range == 0:
		if _is_hex_traversable(caster_hex):
			return [caster_hex]
		return []

	for q: int in range(-skill.max_range, skill.max_range + 1):
		for r: int in range(max(-skill.max_range, -q - skill.max_range), min(skill.max_range, -q + skill.max_range) + 1):
			var dist: int = (abs(q) + abs(q + r) + abs(r)) / 2
			
			if dist >= skill.min_range and dist <= skill.max_range:
				var current_2d := Vector2i(center_2d.x + q, center_2d.y + r)
				var actual_hex := _get_surface_hex(current_2d)
				
				if actual_hex.z != -999:
					# Vérification des contraintes d'élévation
					var elevation_diff: int = actual_hex.z - caster_hex.z
					if elevation_diff > skill.max_elevation_up or elevation_diff < -skill.max_elevation_down:
						continue
						
					# Vérification de la Ligne de Vue si exigé
					if skill.requires_line_of_sight and not has_line_of_sight(caster_hex, actual_hex, ignored_hex):
						continue
						
					valid_hexes.append(actual_hex)
					
	return valid_hexes

## Calcule et retourne toutes les cases affectées par une compétence (Wrapper Principal).
static func get_affected_hexes(caster_hex: Vector3i, target_hex: Vector3i, skill: SkillData, ignored_hex: Vector3i = Vector3i(0, 0, -999)) -> Array[Vector3i]:
	var shape: SkillData.AreaShape = skill.aoe_shape
	var radius: int = skill.aoe_radius
	var pierces: bool = skill.pierces_obstacles

	match shape:
		SkillData.AreaShape.CIRCLE:
			return _get_circle(target_hex, radius, pierces, ignored_hex)
		SkillData.AreaShape.LINE:
			return _get_line(caster_hex, target_hex, radius, pierces, ignored_hex)
		SkillData.AreaShape.CONE:
			return _get_cone(caster_hex, target_hex, radius, pierces, ignored_hex)
		_: # SINGLE_TARGET (ou autres non implémentés comme RING)
			return [target_hex]

## Calcule une ligne de vue (Bresenham hexagonal) pour vérifier les obstacles mathématiques.
static func has_line_of_sight(start_hex: Vector3i, target_hex: Vector3i, ignored_hex: Vector3i = Vector3i(0, 0, -999)) -> bool:
	var start_2d := Vector2i(start_hex.x, start_hex.y)
	var target_2d := Vector2i(target_hex.x, target_hex.y)
	var dist: int = _hex_distance(start_2d, target_2d)

	if dist <= 1:
		return true

	var start_cube := _axial_to_cubic(start_2d)
	var target_cube := _axial_to_cubic(target_2d)

	# On parcourt les cases intermédiaires (1 à dist - 1)
	for i: int in range(1, dist):
		var t: float = float(i) / float(dist)
		var current_cube := start_cube.lerp(target_cube, t)
		var current_2d := _cubic_to_axial(current_cube)
		var actual_hex := _get_surface_hex(current_2d)

		if not _is_hex_traversable(actual_hex):
			return false # Bloqué par un trou ou un mur pur
			
		# AAA : Paradoxe de Ligne de Vue - Les unités bloquent la ligne de vue, sauf l'origine ignorée
		if actual_hex != ignored_hex and GridManager.unit_positions.has(actual_hex):
			return false
			
		# Contrainte Topologique 2.5D : Bloqué si la colline intermédiaire est plus haute 
		# que la position du lanceur ET de la cible.
		var max_z: int = max(start_hex.z, target_hex.z)
		if actual_hex.z > max_z:
			return false

	return true

# PRIVATE FUNCTIONS (SHAPES)
static func _get_line(start_hex: Vector3i, target_hex: Vector3i, length: int, pierces_obstacles: bool, ignored_hex: Vector3i) -> Array[Vector3i]:
	var line: Array[Vector3i] = []
	var start_2d := Vector2i(start_hex.x, start_hex.y)
	var target_2d := Vector2i(target_hex.x, target_hex.y)
	var dist: int = _hex_distance(start_2d, target_2d)

	if dist == 0:
		return [start_hex]

	var start_cube := _axial_to_cubic(start_2d)
	var target_cube := _axial_to_cubic(target_2d)

	# Interpolation pour projeter la ligne sur la distance voulue
	for i: int in range(1, length + 1):
		var t: float = float(i) / float(dist)
		var current_cube := start_cube.lerp(target_cube, t)
		var current_2d := _cubic_to_axial(current_cube)
		var actual_hex := _get_surface_hex(current_2d)

		var is_blocked: bool = not _is_hex_traversable(actual_hex) or (actual_hex != ignored_hex and GridManager.unit_positions.has(actual_hex))
		if not pierces_obstacles and is_blocked:
			break # Arrête net la ligne de dégâts
			
		if actual_hex.z != -999 and not line.has(actual_hex):
			line.append(actual_hex)

	return line

static func _get_circle(center_hex: Vector3i, radius: int, pierces_obstacles: bool, ignored_hex: Vector3i) -> Array[Vector3i]:
	var circle: Array[Vector3i] = []
	var center_2d := Vector2i(center_hex.x, center_hex.y)

	for q: int in range(-radius, radius + 1):
		for r: int in range(max(-radius, -q - radius), min(radius, -q + radius) + 1):
			var current_2d := Vector2i(center_2d.x + q, center_2d.y + r)
			var actual_hex := _get_surface_hex(current_2d)
			
			if actual_hex.z != -999:
				if not pierces_obstacles and not has_line_of_sight(center_hex, actual_hex, ignored_hex):
					continue
				circle.append(actual_hex)
				
	return circle

static func _get_cone(start_hex: Vector3i, target_hex: Vector3i, length: int, pierces_obstacles: bool, ignored_hex: Vector3i) -> Array[Vector3i]:
	var cone: Array[Vector3i] = []
	var start_2d := Vector2i(start_hex.x, start_hex.y)
	var target_2d := Vector2i(target_hex.x, target_hex.y)
	
	if start_2d == target_2d:
		return []
		
	var start_cube := _axial_to_cubic(start_2d)
	var target_cube := _axial_to_cubic(target_2d)
	var dir_cube := (target_cube - start_cube).normalized()

	for q: int in range(-length, length + 1):
		for r: int in range(max(-length, -q - length), min(length, -q + length) + 1):
			if q == 0 and r == 0: continue
			
			var current_2d := Vector2i(start_2d.x + q, start_2d.y + r)
			var current_cube := _axial_to_cubic(current_2d)
			var current_dir := (current_cube - start_cube).normalized()
			
			# Cône de 60 degrés (Dot product >= 0.5)
			if dir_cube.dot(current_dir) >= 0.5:
				var actual_hex := _get_surface_hex(current_2d)
				if actual_hex.z != -999:
					if not pierces_obstacles and not has_line_of_sight(start_hex, actual_hex, ignored_hex):
						continue
					cone.append(actual_hex)
	return cone

# PRIVATE FUNCTIONS (MATH HELPERS)
static func _hex_distance(a: Vector2i, b: Vector2i) -> int:
	return (abs(a.x - b.x) + abs(a.x + a.y - b.x - b.y) + abs(a.y - b.y)) / 2

static func _axial_to_cubic(hex: Vector2i) -> Vector3:
	return Vector3(float(hex.x), float(hex.y), float(-hex.x - hex.y))

static func _cubic_to_axial(cube: Vector3) -> Vector2i:
	var q: int = roundi(cube.x)
	var r: int = roundi(cube.y)
	var s: int = roundi(cube.z)
	var q_diff: float = absf(float(q) - cube.x)
	var r_diff: float = absf(float(r) - cube.y)
	var s_diff: float = absf(float(s) - cube.z)
	if q_diff > r_diff and q_diff > s_diff: q = -r - s
	elif r_diff > s_diff: r = -q - s
	return Vector2i(q, r)

static func _get_surface_hex(hex_2d: Vector2i) -> Vector3i:
	for h: Vector3i in GridManager.terrain_tiles.keys():
		if h.x == hex_2d.x and h.y == hex_2d.y: return h
	return Vector3i(hex_2d.x, hex_2d.y, -999)

static func _is_hex_traversable(hex: Vector3i) -> bool:
	return GridManager.terrain_tiles.has(hex)