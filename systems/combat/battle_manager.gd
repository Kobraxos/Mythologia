class_name BattleManager
extends Node

@export_category("Dependencies")
@export var grid_generator: GridGenerator
## Référence au système de tour qui gérera les acteurs instanciés.
@export var turn_manager: TurnManager

@export_category("Spawns")
## Le préfabriqué de l'unité à faire apparaître.
@export var player_unit_prefab: PackedScene
## Les données du Héros 1 à injecter.
@export var hero_stats: UnitStats
## Les données du Monstre 1 à injecter.
@export var enemy_stats: UnitStats

# GODOT BUILT-IN FUNCTIONS
func _ready() -> void:
	if not grid_generator or not player_unit_prefab or not turn_manager:
		push_error("BattleManager: Dépendances manquantes ('grid_generator', 'player_unit_prefab' ou 'turn_manager').")
		return
		
	# L'arbre de scène Godot est verrouillé pendant le _ready(). On décale l'assemblage procédural à la frame suivante.
	call_deferred("_initialize_battle")

func _initialize_battle() -> void:
	# Phase 1 : Le monde est construit (la montagne se dresse)
	grid_generator.generate_grid()
	
	# Phase 2 : Les acteurs entrent en scène (Spawn procédural)
	if hero_stats and enemy_stats:
		_spawn_unit_at_axial(0, 0, hero_stats)
		_spawn_unit_at_axial(1, -1, enemy_stats)
		
	# Phase 3 : Le temps s'écoule
	turn_manager.start_battle()

# PRIVATE FUNCTIONS
func _spawn_unit_at_axial(q: int, r: int, stats: UnitStats) -> void:
	var target_hex: Vector3i = _get_surface_hex(q, r)
	
	var unit: Unit = player_unit_prefab.instantiate() as Unit
	# L'astuce AAA : On donne la position 3D AVANT le add_child. 
	# Ainsi, quand l'unité exécutera son _ready(), elle lira sa hauteur exacte !
	unit.position = HexMath.hex_to_world(target_hex, GridManager.hex_size, GridManager.elevation_step)
	add_child(unit)
	unit.initialize(stats)
	turn_manager.register_unit(unit)

## Scanne la grille pour trouver la case (et surtout sa hauteur Z) correspondant à une coordonnée 2D.
func _get_surface_hex(q: int, r: int) -> Vector3i:
	for hex: Vector3i in GridManager.terrain_tiles.keys():
		if hex.x == q and hex.y == r:
			return hex
	return Vector3i(q, r, 0) # Fallback de sécurité