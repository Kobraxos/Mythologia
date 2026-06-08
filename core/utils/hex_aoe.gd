class_name HexAoE
extends RefCounted

## Utilitaire AAA de génération mathématique pure (2D).
## Ne gère aucune logique de combat ni topologie 3D. Zéro dépendance spatiale.

# PUBLIC FUNCTIONS
static func get_ring_2d(center: Vector2i, min_radius: int, max_radius: int) -> Array[Vector2i]:
	var ring: Array[Vector2i] = []
	if max_radius == 0:
		return [center]

	for q: int in range(-max_radius, max_radius + 1):
		for r: int in range(max(-max_radius, -q - max_radius), min(max_radius, -q + max_radius) + 1):
			var dist: int = (abs(q) + abs(q + r) + abs(r)) / 2
			if dist >= min_radius and dist <= max_radius:
				ring.append(Vector2i(center.x + q, center.y + r))
	return ring

static func get_linear_range_2d(center: Vector2i, min_radius: int, max_radius: int) -> Array[Vector2i]:
	var hexes: Array[Vector2i] = []
	if max_radius == 0:
		return [center]
		
	if min_radius <= 0:
		hexes.append(center)
		
	var directions: Array[Vector2i] = [
		Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1),
		Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1)
	]
	
	for dist: int in range(max(1, min_radius), max_radius + 1):
		for dir: Vector2i in directions:
			hexes.append(center + dir * dist)
			
	return hexes

static func get_circle_2d(center: Vector2i, radius: int) -> Array[Vector2i]:
	return get_ring_2d(center, 0, radius)

static func get_line_2d(start: Vector2i, target: Vector2i, length: int) -> Array[Vector2i]:
	var line: Array[Vector2i] = []
	var dist: int = HexMath.distance_2d_flat(start, target)
	if dist == 0:
		return [start]

	var start_cube := HexMath.axial_to_cubic(start)
	var target_cube := HexMath.axial_to_cubic(target)

	for i: int in range(1, length + 1):
		var t: float = float(i) / float(dist)
		var current_cube := start_cube.lerp(target_cube, t)
		line.append(HexMath.cubic_to_axial(current_cube))
	return line

static func get_cone_2d(start: Vector2i, target: Vector2i, length: int) -> Array[Vector2i]:
	var cone: Array[Vector2i] = []
	if start == target:
		return []
		
	var start_cube := HexMath.axial_to_cubic(start)
	var target_cube := HexMath.axial_to_cubic(target)
	var dir_cube := (target_cube - start_cube).normalized()

	for q: int in range(-length, length + 1):
		for r: int in range(max(-length, -q - length), min(length, -q + length) + 1):
			if q == 0 and r == 0: continue
			var current_2d := Vector2i(start.x + q, start.y + r)
			var current_cube := HexMath.axial_to_cubic(current_2d)
			var current_dir := (current_cube - start_cube).normalized()
			
			if dir_cube.dot(current_dir) >= 0.5:
				cone.append(current_2d)
	return cone