extends Node

# EXPORTS
@export_category("Grid Scale")
@export var hex_size: float = 1.0
@export var elevation_step: float = 0.5

# PUBLIC VARIABLES

## Référence globale au pathfinder actuel de la scène.
var pathfinder: HexPathfinder = HexPathfinder.new()

@export_category("Registries")
## Registre des données de terrain de base. Clé: Vector3i (Axial+Z), Valeur: TerrainData
var terrain_tiles: Dictionary = {} # Dictionary[Vector3i, TerrainData]
## Registre des surfaces volatiles (couche supérieure). Clé: Vector3i, Valeur: TerrainData
var surface_tiles: Dictionary = {} # Dictionary[Vector3i, TerrainData]
## Registre de la durée de vie restante des surfaces volatiles. Clé: Vector3i, Valeur: int (tours restants)
var surface_durations: Dictionary[Vector3i, int] = {}
## Registre spatial des unités. Clé: Vector3i, Valeur: Unit
var unit_positions: Dictionary[Vector3i, Unit] = {}

## La hauteur maximale actuelle de la grille générée, utilisée par les systèmes mathématiques (ex: Raycasting).
var max_elevation: int = 0

## Cache d'élévation pour une résolution rapide 2D -> hauteur en O(1). Clé: Vector2i, Valeur: int
var _elevation_map: Dictionary = {} # Dictionary[Vector2i, int]

func _ready() -> void:
	# Invalidation du cache dynamique via des lambdas (sécurité de signature AAA face aux Event Bus)
	if CombatEvents.has_signal("unit_died"):
		CombatEvents.unit_died.connect(func(_unit): clear_pathfinding_cache())
		
	if TurnEvents.has_signal("active_unit_changed"):
		TurnEvents.active_unit_changed.connect(func(_unit): clear_pathfinding_cache())
		
	if GridEvents.has_signal("grid_topology_ready"):
		GridEvents.grid_topology_ready.connect(_build_elevation_cache)
		
	# S'il existe un événement lié aux mouvements complétés, le relier ici :
	if GridEvents.has_signal("movement_completed"):
		GridEvents.movement_completed.connect(func(_unit): clear_pathfinding_cache())

## Purgation manuelle à déclencher après toute altération de l'état du plateau (mouvement, mort, spawn)
func clear_pathfinding_cache() -> void:
	pathfinder.clear_dynamic_cache()

func _build_elevation_cache(_topology: Dictionary) -> void:
	_elevation_map.clear()
	for hex: Vector3i in terrain_tiles.keys():
		_elevation_map[Vector2i(hex.x, hex.y)] = hex.z

func clear_terrain() -> void:
	terrain_tiles.clear()
	surface_tiles.clear()
	surface_durations.clear()
	_elevation_map.clear()
	pathfinder = HexPathfinder.new()
	max_elevation = 0

func clear_units() -> void:
	unit_positions.clear()

# --- SURFACE CRUD ---

## Ajoute une surface sur l'hexagone. Remplace la surface existante.
func add_surface(hex: Vector3i, surface_data: Resource) -> void: # surface_data is TerrainData
	if not surface_data.get("is_surface"):
		push_error("GridManager: Tentative d'ajouter un TerrainData non marqué comme is_surface !")
		return
		
	# Si une surface est déjà là, on la nettoie virtuellement
	if surface_tiles.has(hex):
		GridEvents.surface_removed.emit(hex)
		
	surface_tiles[hex] = surface_data
	surface_durations[hex] = surface_data.get("duration_turns")
	
	GridEvents.surface_spawned.emit(hex, surface_data)

## Retire la surface de l'hexagone.
func remove_surface(hex: Vector3i) -> void:
	if surface_tiles.has(hex):
		surface_tiles.erase(hex)
		surface_durations.erase(hex)
		GridEvents.surface_removed.emit(hex)

## Retourne le terrain actif sur la case (la Surface prioritairement, sinon le Terrain de base).
func get_active_terrain(hex: Vector3i) -> Resource: # Returns TerrainData
	if surface_tiles.has(hex):
		return surface_tiles[hex]
	if terrain_tiles.has(hex):
		return terrain_tiles[hex]
	return null

## Récupère l'élévation (Z) d'une coordonnée 2D en O(1).
func get_elevation(q: int, r: int) -> int:
	var hex2d := Vector2i(q, r)
	if _elevation_map.has(hex2d):
		return _elevation_map[hex2d]
	return 0
