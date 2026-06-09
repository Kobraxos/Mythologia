class_name BiomePalette
extends Resource

@export_category("Biome Definition")
@export var biome_name: String = "Nouveau Biome"

enum TerrainRole { BASE, FERTILE, WATER, OBSTACLE, SPECIAL, ROAD, ABYSS }

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
## Terrain spécial (Nectar, Lave, etc.)
@export var special_terrain: TerrainData
## Terrain de route (Marbre, Pavés)
@export var road_terrain: TerrainData
## Terrain des gouffres aux bords de la carte (Abysse)
@export var abyss_terrain: TerrainData

func get_terrain_by_role(role: TerrainRole) -> TerrainData:
	match role:
		TerrainRole.BASE: return base_terrain
		TerrainRole.FERTILE: return fertile_terrain
		TerrainRole.WATER: return water_terrain
		TerrainRole.OBSTACLE: return obstacle_terrain
		TerrainRole.SPECIAL: return special_terrain
		TerrainRole.ROAD: return road_terrain
		TerrainRole.ABYSS: return abyss_terrain
	return base_terrain
