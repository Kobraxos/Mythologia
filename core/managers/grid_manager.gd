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

func clear_terrain() -> void:
	terrain_tiles.clear()
	pathfinder = HexPathfinder.new()

func clear_units() -> void:
	unit_positions.clear()
