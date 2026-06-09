class_name BiomePalette
extends Resource

@export_category("Biome Definition")
@export var biome_name: String = "Nouveau Biome"

@export_category("Topography Rules")
## Niveau Z en dessous duquel l'eau apparait automatiquement
@export var water_level: int = 1

@export_category("Terrain Palette")
## Terrain par défaut (terre)
@export var base_terrain: TerrainData
## Terrain fertile (herbe)
@export var fertile_terrain: TerrainData
## Terrain liquide (eau)
@export var water_terrain: TerrainData
## Obstacles infranchissables (piliers)
@export var obstacle_terrain: TerrainData
