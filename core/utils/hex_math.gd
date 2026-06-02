class_name HexMath
extends RefCounted

# CONSTANTS

const SQRT_3: float = 1.7320508075688772
const SQRT_3_3: float = 0.5773502691896257  # sqrt(3.0) / 3.0
const ONE_THIRD: float = 0.3333333333333333
const TWO_THIRDS: float = 0.6666666666666666

## Constantes pour les 6 directions adjacentes d'un hexagone en coordonnées cubiques (X, Y, Z).
## Règle d'or absolue : La somme de X + Y + Z doit toujours être égale à 0.
const DIRECTIONS: Array[Vector3i] = [
	Vector3i(1, -1, 0),  # Est
	Vector3i(1, 0, -1),  # Nord-Est
	Vector3i(0, 1, -1),  # Nord-Ouest
	Vector3i(-1, 1, 0),  # Ouest
	Vector3i(-1, 0, 1),  # Sud-Ouest
	Vector3i(0, -1, 1)   # Sud-Est
]

## Décalage infinitésimal (nudge) pour éviter les bugs de sélection si une ligne de vue passe exactement sur une bordure.
const NUDGE: Vector3 = Vector3(1e-06, 1e-06, -2e-06)

# PUBLIC FUNCTIONS

## Calcule la distance (en nombre de cases) entre deux hexagones.
## Idéal pour déterminer la portée d'une attaque ou la distance de déplacement.
static func distance(a: Vector3i, b: Vector3i) -> int:
	return (abs(a.x - b.x) + abs(a.y - b.y) + abs(a.z - b.z)) / 2

## Retourne les coordonnées de l'hexagone voisin dans une direction donnée (de 0 à 5).
static func get_neighbor(hex: Vector3i, direction: int) -> Vector3i:
	return hex + DIRECTIONS[direction % DIRECTIONS.size()]

## Retourne les coordonnées des 6 voisins adjacents à la case ciblée.
static func get_all_neighbors(hex: Vector3i) -> Array[Vector3i]:
	var neighbors: Array[Vector3i] = []
	for dir in DIRECTIONS:
		neighbors.append(hex + dir)
	return neighbors

## Arrondit des coordonnées cubiques flottantes (Vector3) vers l'hexagone (Vector3i) le plus proche.
## Crucial pour les lancers de rayons (Raycasting) et les lignes de vue.
static func round_hex(frac: Vector3) -> Vector3i:
	var rx: int = roundi(frac.x)
	var ry: int = roundi(frac.y)
	var rz: int = roundi(frac.z)

	var x_diff: float = abs(rx - frac.x)
	var y_diff: float = abs(ry - frac.y)
	var z_diff: float = abs(rz - frac.z)

	# On ajuste la composante qui a subi le plus grand changement lors de l'arrondi
	# afin de respecter la règle X + Y + Z = 0
	if x_diff > y_diff and x_diff > z_diff:
		rx = -ry - rz
	elif y_diff > z_diff:
		ry = -rx - rz
	else:
		rz = -rx - ry

	return Vector3i(rx, ry, rz)

## Calcule tous les hexagones traversés par une ligne droite de A à B.
static func draw_line(a: Vector3i, b: Vector3i) -> Array[Vector3i]:
	var dist: int = distance(a, b)
	var line: Array[Vector3i] = []
	if dist == 0:
		line.append(a)
		return line

	var a_nudge: Vector3 = Vector3(a) + NUDGE
	var b_nudge: Vector3 = Vector3(b) + NUDGE

	for i in range(dist + 1):
		var t: float = float(i) / dist
		var lerped: Vector3 = a_nudge.lerp(b_nudge, t)
		line.append(round_hex(lerped))

	return line

## Convertit des coordonnées cubiques en position 3D spatiale (Flat Y=0, plan XZ).
## Orientation mathématique : Pointy-Topped (Pointes en haut/bas).
static func hex_to_world(hex: Vector3i, size: float) -> Vector3:
	var x: float = (SQRT_3 * hex.x + (SQRT_3 * 0.5) * hex.z) * size
	var z: float = (1.5 * hex.z) * size
	return Vector3(x, 0.0, z)

## Retourne toutes les coordonnées cubiques contenues dans un rayon donné autour d'un centre.
static func get_hexes_in_radius(center: Vector3i, radius: int) -> Array[Vector3i]:
	var results: Array[Vector3i] = []
	for x in range(-radius, radius + 1):
		for y in range(maxi(-radius, -x - radius), mini(radius, -x + radius) + 1):
			var z: int = -x - y
			results.append(center + Vector3i(x, y, z))
	return results

## Convertit une position 3D spatiale (Flat Y=0, plan XZ) en coordonnées cubiques abstraites.
## Orientation mathématique : Pointy-Topped (Pointes en haut/bas).
static func world_to_hex(world_pos: Vector3, size: float) -> Vector3i:
	var q: float = (SQRT_3_3 * world_pos.x - ONE_THIRD * world_pos.z) / size
	var r: float = (TWO_THIRDS * world_pos.z) / size
	var s: float = -q - r
	return round_hex(Vector3(q, s, r))