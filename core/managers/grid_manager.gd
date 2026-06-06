extends Node

# EXPORTS
@export_category("Grid Scale")
@export var hex_size: float = 1.0
@export var elevation_step: float = 0.5

# PUBLIC VARIABLES

## Référence globale au pathfinder actuel de la scène.
var pathfinder: HexPathfinder = HexPathfinder.new()

@export_category("Registries")
## Registre des données de terrain. Clé: Vector3i (Axial+Z), Valeur: TerrainData
var terrain_tiles: Dictionary[Vector3i, TerrainData] = {}
## Registre spatial des unités. Clé: Vector3i, Valeur: Unit
var unit_positions: Dictionary[Vector3i, Unit] = {}

## La hauteur maximale actuelle de la grille générée, utilisée par les systèmes mathématiques (ex: Raycasting).
var max_elevation: int = 0

func _ready() -> void:
	# Invalidation du cache dynamique via des lambdas (sécurité de signature AAA face aux Event Bus)
	if CombatEvents.has_signal("unit_died"):
		CombatEvents.unit_died.connect(func(_unit): clear_pathfinding_cache())
		
	if TurnEvents.has_signal("active_unit_changed"):
		TurnEvents.active_unit_changed.connect(func(_unit): clear_pathfinding_cache())
		
	# S'il existe un événement lié aux mouvements complétés, le relier ici :
	if GridEvents.has_signal("movement_completed"):
		GridEvents.movement_completed.connect(func(_unit): clear_pathfinding_cache())

## Purgation manuelle à déclencher après toute altération de l'état du plateau (mouvement, mort, spawn)
func clear_pathfinding_cache() -> void:
	pathfinder.clear_dynamic_cache()

func clear_terrain() -> void:
	terrain_tiles.clear()
	pathfinder = HexPathfinder.new()
	max_elevation = 0

func clear_units() -> void:
	unit_positions.clear()
