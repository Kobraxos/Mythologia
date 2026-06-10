class_name GridVisualBuilder
extends Node3D
## Composant responsable de l'instanciation des ressources visuelles (Tuiles, Spawns) 
## en fonction des données logiques calculées par le GridGenerator.

var hex_tiles: Dictionary = {}
var _spawn_group_node: Node3D

func _ready() -> void:
	GridEvents.grid_generation_logic_done.connect(_on_grid_logic_done)
	
	_spawn_group_node = Node3D.new()
	_spawn_group_node.name = GridGenerationContext.NODE_NAME_SPAWNS
	add_child(_spawn_group_node)

func _exit_tree() -> void:
	_clear_previous_grid()

func _clear_previous_grid() -> void:
	for tile: Node in hex_tiles.values():
		if is_instance_valid(tile):
			tile.queue_free()
	hex_tiles.clear()
	
	for child: Node in _spawn_group_node.get_children():
		if is_instance_valid(child):
			child.queue_free()

## Construit la grille 3D lors de la réception du signal de fin de logique.
func _on_grid_logic_done(ctx: GridGenerationContext) -> void:
	_clear_previous_grid()
	
	for hex_2d: Vector2i in ctx.temp_terrains.keys():
		var chosen_terrain: TerrainData = ctx.temp_terrains[hex_2d] as TerrainData
		if not is_instance_valid(chosen_terrain) or not is_instance_valid(chosen_terrain.visual_prefab): 
			continue
		
		var hex_coord: Vector3i = ctx.flat_to_3d[hex_2d] as Vector3i
		var tile: Node3D = chosen_terrain.visual_prefab.instantiate() as Node3D
		var world_pos: Vector3 = HexMath.hex_to_world(hex_coord, GridManager.hex_size, GridManager.elevation_step)
		
		tile.position = world_pos
		tile.name = GridGenerationContext.TILE_NAME_FORMAT % [chosen_terrain.id, hex_coord.x, hex_coord.y, hex_coord.z]

		add_child(tile)
		hex_tiles[hex_coord] = tile
		
		# Spawns
		if is_instance_valid(ctx.active_biome) and chosen_terrain == ctx.active_biome.spawn_terrain:
			var sp = SpawnPoint.new()
			sp.position = world_pos
			if ctx.final_t1_spawns.has(hex_2d):
				sp.faction = CoreEnums.Faction.PLAYER
				sp.stats = ctx.spawn_player_stats
				sp.name = GridGenerationContext.SPAWN_PLAYER_FORMAT % [hex_2d.x, hex_2d.y]
			else:
				sp.faction = CoreEnums.Faction.ENEMY
				sp.stats = ctx.spawn_enemy_stats
				sp.name = GridGenerationContext.SPAWN_ENEMY_FORMAT % [hex_2d.x, hex_2d.y]
				
			_spawn_group_node.add_child(sp)
			sp.add_to_group(GridGenerationContext.GROUP_SPAWN_POINTS)
