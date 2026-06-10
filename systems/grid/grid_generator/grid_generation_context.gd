class_name GridGenerationContext
extends RefCounted
## DTO encapsulant l'état de la génération de la grille et les constantes associées.

const GROUP_SPAWN_POINTS := "spawn_points"
const TILE_NAME_FORMAT := "HexTile_%s_%d_%d_%d"
const SPAWN_PLAYER_FORMAT := "SpawnPlayer_%d_%d"
const SPAWN_ENEMY_FORMAT := "SpawnEnemy_%d_%d"
const NODE_NAME_SPAWNS := "GeneratedSpawnPoints"

var temp_heights: Dictionary = {} # Vector2i -> int
var temp_terrains: Dictionary = {} # Vector2i -> TerrainData
var is_abyss_cache: Dictionary = {} # Vector2i -> bool
var spawn_locations: Dictionary = {} # Vector2i -> bool
var final_t1_spawns: Dictionary = {} # Vector2i -> bool
var final_t2_spawns: Dictionary = {} # Vector2i -> bool
var flat_to_3d: Dictionary = {} # Vector2i -> Vector3i
var active_biome: BiomePalette
var spawn_player_stats: UnitStats
var spawn_enemy_stats: UnitStats
