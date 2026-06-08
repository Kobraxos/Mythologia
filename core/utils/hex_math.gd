class_name HexMath
extends RefCounted

# CONSTANTS

const SQRT_3: float = 1.7320508075688772
const SQRT_3_3: float = 0.5773502691896257  # sqrt(3.0) / 3.0
const ONE_THIRD: float = 0.3333333333333333
const TWO_THIRDS: float = 0.6666666666666666
const INVALID_HEX := Vector3i(9999, 9999, 9999)

## STANDARD AAA 2.5D : 
## Un Vector3i de grille = (Q, R, Elevation). 
## Q et R sont les coordonnees axiales (plan 2D). Z est la hauteur tactique.
## La coordonnee cubique S n'est pas stockee, elle est deduite (-Q - R).

## Directions adjacentes sur un plan plat (Q, R).
const DIRECTIONS: Array[Vector2i] = [
	Vector2i(1, 0),   # Est
	Vector2i(1, -1),  # Nord-Est
	Vector2i(0, -1),  # Nord-Ouest
	Vector2i(-1, 0),  # Ouest
	Vector2i(-1, 1),  # Sud-Ouest
	Vector2i(0, 1)    # Sud-Est
]

# PUBLIC FUNCTIONS

## Calcule la distance planaire (2D) entre deux hexagones, ignorant la hauteur (Z).
static func distance_2d(a: Vector3i, b: Vector3i) -> int:
	var q_diff: int = a.x - b.x
	var r_diff: int = a.y - b.y
	return (abs(q_diff) + abs(q_diff + r_diff) + abs(r_diff)) / 2

## Retourne les coordonnees de l'hexagone voisin dans une direction donnee (de 0 a 5).
static func get_neighbor(hex: Vector3i, direction: int) -> Vector3i:
	var dir: Vector2i = DIRECTIONS[direction % DIRECTIONS.size()]
	return Vector3i(hex.x + dir.x, hex.y + dir.y, hex.z)

## Retourne les coordonnees des 6 voisins adjacents sur le meme niveau de hauteur.
static func get_all_neighbors(hex: Vector3i) -> Array[Vector3i]:
	var neighbors: Array[Vector3i] = []
	for dir in DIRECTIONS:
		neighbors.append(Vector3i(hex.x + dir.x, hex.y + dir.y, hex.z))
	return neighbors

## Arrondit des fractions axiales (Q, R) vers la coordonnee axiale la plus proche.
static func round_hex(frac_q: float, frac_r: float) -> Vector2i:
	var frac_s: float = -frac_q - frac_r
	var q: int = roundi(frac_q)
	var r: int = roundi(frac_r)
	var s: int = roundi(frac_s)

	var q_diff: float = abs(q - frac_q)
	var r_diff: float = abs(r - frac_r)
	var s_diff: float = abs(s - frac_s)

	if q_diff > r_diff and q_diff > s_diff:
		q = -r - s
	elif r_diff > s_diff:
		r = -q - s
		
	return Vector2i(q, r)

## Calcule les hexagones traverses par une ligne 3D (Bresenham 3D Hexagonal).
static func draw_line(a: Vector3i, b: Vector3i) -> Array[Vector3i]:
	var dist_2d: int = distance_2d(a, b)
	var z_diff: int = abs(a.z - b.z)
	var steps: int = maxi(dist_2d, z_diff)
	
	var line: Array[Vector3i] = []
	if steps == 0:
		line.append(a)
		return line

	var a_q: float = float(a.x) + 1e-06
	var a_r: float = float(a.y) + 1e-06
	var a_z: float = float(a.z)
	
	var b_q: float = float(b.x) + 1e-06
	var b_r: float = float(b.y) + 1e-06
	var b_z: float = float(b.z)

	for i in range(steps + 1):
		var t: float = float(i) / steps
		var flat_hex: Vector2i = round_hex(lerpf(a_q, b_q, t), lerpf(a_r, b_r, t))
		var lerped_z: int = roundi(lerpf(a_z, b_z, t))
		line.append(Vector3i(flat_hex.x, flat_hex.y, lerped_z))

	return line

## Convertit des coordonnees axiales + hauteur en position 3D spatiale (Plan XZ, Hauteur Y).
## Orientation mathematique : Pointy-Topped (Pointes en haut/bas).
static func hex_to_world(hex: Vector3i, hex_size: float, elevation_step: float) -> Vector3:
	var x: float = hex_size * SQRT_3 * (hex.x + 0.5 * hex.y)
	var z: float = hex_size * 1.5 * hex.y
	var y: float = hex.z * elevation_step
	return Vector3(x, y, z)

## Retourne toutes les coordonnees cubiques contenues dans un rayon donne autour d'un centre.
static func get_hexes_in_radius(center: Vector3i, radius: int) -> Array[Vector3i]:
	var results: Array[Vector3i] = []
	for x in range(-radius, radius + 1):
		for y in range(maxi(-radius, -x - radius), mini(radius, -x + radius) + 1):
			results.append(Vector3i(center.x + x, center.y + y, center.z))
	return results

## Convertit une position 3D physique (XYZ) en coordonnees de grille abstraite (Axe Q, Axe R, Elevation).
static func world_to_hex(world_pos: Vector3, hex_size: float, elevation_step: float) -> Vector3i:
	var q: float = (SQRT_3_3 * world_pos.x - ONE_THIRD * world_pos.z) / hex_size
	var r: float = (TWO_THIRDS * world_pos.z) / hex_size
	var hex_2d: Vector2i = round_hex(q, r)
	var elevation: int = roundi(world_pos.y / elevation_step)
	return Vector3i(hex_2d.x, hex_2d.y, elevation)

## Calcule la distance planaire (2D) entre deux hexagones axiaux.
static func distance_2d_flat(a: Vector2i, b: Vector2i) -> int:
	var q_diff: int = a.x - b.x
	var r_diff: int = a.y - b.y
	return (abs(q_diff) + abs(q_diff + r_diff) + abs(r_diff)) / 2

## Convertit une coordonnee axiale 2D (Q, R) en coordonnee cubique (Q, R, S).
static func axial_to_cubic(hex: Vector2i) -> Vector3:
	return Vector3(float(hex.x), float(hex.y), float(-hex.x - hex.y))

## Convertit une coordonnee cubique (Q, R, S) en coordonnee axiale 2D (Q, R).
static func cubic_to_axial(cube: Vector3) -> Vector2i:
	var q: int = roundi(cube.x)
	var r: int = roundi(cube.y)
	var s: int = roundi(cube.z)
	
	var q_diff: float = abs(float(q) - cube.x)
	var r_diff: float = abs(float(r) - cube.y)
	var s_diff: float = abs(float(s) - cube.z)
	
	if q_diff > r_diff and q_diff > s_diff:
		q = -r - s
	elif r_diff > s_diff:
		r = -q - s
		
	return Vector2i(q, r)