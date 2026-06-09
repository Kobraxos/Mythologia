class_name GridGenerator
extends Node3D

enum MapShape { HEXAGON, RECTANGLE }

@export_category("Dimensions")
@export var map_shape: MapShape = MapShape.HEXAGON
@export var map_radius: int = 12
@export var map_width: int = 15
@export var map_height: int = 10
@export var obstacles: Array[Vector3i] = []

@export_category("Procedural Generation")
@export var elevation_noise: FastNoiseLite
@export var max_elevation: int = 8

@export_category("Biome Generation")
@export var active_biome: BiomePalette
@export var moisture_noise: FastNoiseLite
@export var obstacle_noise: FastNoiseLite
@export var road_noise: FastNoiseLite
@export var special_noise: FastNoiseLite

@export_category("Procedural Features")
@export var features: Array[GridFeature] = []
@export var feature_count: int = 0

@export_category("AAA Spawns")
@export var spawn_player_stats: UnitStats
@export var spawn_enemy_stats: UnitStats
@export var units_per_team: int = 5

var hex_tiles: Dictionary = {}

func _ready() -> void:
	GridEvents.request_grid_generation.connect(generate_grid)

func _exit_tree() -> void:
	hex_tiles.clear()

func generate_grid() -> void:
	for tile: Node3D in hex_tiles.values():
		if is_instance_valid(tile):
			tile.queue_free()
	hex_tiles.clear()
	
	GridManager.clear_terrain()

	var coords: Array[Vector3i] = []
	if map_shape == MapShape.HEXAGON:
		coords = HexMath.get_hexes_in_radius(Vector3i.ZERO, map_radius)
	else:
		coords = HexMath.get_hexes_in_rectangle(Vector3i.ZERO, map_width, map_height)
		
	var local_pathfinder: HexPathfinder = HexPathfinder.new()
	var flat_to_3d: Dictionary[Vector2i, Vector3i] = {}

	var grid_seed: int = randi()
	if elevation_noise: elevation_noise.seed = grid_seed
	if moisture_noise: moisture_noise.seed = grid_seed + 1000
	if obstacle_noise: obstacle_noise.seed = grid_seed + 2000
	if road_noise: road_noise.seed = grid_seed + 3000
	if special_noise: special_noise.seed = grid_seed + 4000

	var temp_heights: Dictionary[Vector2i, int] = {}
	var temp_terrains: Dictionary[Vector2i, TerrainData] = {}
	var is_abyss_cache: Dictionary[Vector2i, bool] = {}

	# --- PASS 1 : HEIGHT & BASE ---
	for hex_coord in coords:
		var h2d = Vector2i(hex_coord.x, hex_coord.y)
		var dist_to_center = HexMath.distance_2d_flat(Vector2i.ZERO, h2d)
		
		var z = 0
		if elevation_noise:
			var noise_val: float = elevation_noise.get_noise_2d(hex_coord.x * 10.0, hex_coord.y * 10.0)
			z = roundi(remap(noise_val, -1.0, 1.0, 0, max_elevation))
		temp_heights[h2d] = z
		
		var is_abyss = false
		if map_shape == MapShape.HEXAGON and dist_to_center >= map_radius:
			is_abyss = true
		elif map_shape == MapShape.RECTANGLE and (abs(h2d.x) >= map_width or abs(h2d.y) >= map_height):
			is_abyss = true
			
		is_abyss_cache[h2d] = is_abyss
			
		var chosen_terrain: TerrainData = active_biome.base_terrain
		if is_abyss and active_biome.abyss_terrain:
			chosen_terrain = active_biome.abyss_terrain
		else:
			if z <= active_biome.water_level:
				if special_noise and active_biome.special_terrain and special_noise.get_noise_2d(h2d.x * 10.0, h2d.y * 10.0) > 0.6:
					chosen_terrain = active_biome.special_terrain
				else:
					chosen_terrain = active_biome.water_terrain
			else:
				var is_obstacle: bool = false
				if obstacle_noise and active_biome.obstacle_terrain and obstacle_noise.get_noise_2d(h2d.x * 10.0, h2d.y * 10.0) > 0.6:
					chosen_terrain = active_biome.obstacle_terrain
					is_obstacle = true
				if not is_obstacle and road_noise and active_biome.road_terrain and road_noise.get_noise_2d(h2d.x * 10.0, h2d.y * 10.0) > 0.5:
					chosen_terrain = active_biome.road_terrain
				elif not is_obstacle and moisture_noise and moisture_noise.get_noise_2d(h2d.x * 10.0, h2d.y * 10.0) > 0.0 and active_biome.fertile_terrain:
					chosen_terrain = active_biome.fertile_terrain
		temp_terrains[h2d] = chosen_terrain

	# --- PASS 2 : SPAWNS ---
	var spawn_locations: Array[Vector2i] = []
	var team1_center = Vector2i(-int(map_radius * 0.7), 0)
	var team2_center = Vector2i(int(map_radius * 0.7), 0)
	if map_shape == MapShape.RECTANGLE:
		team1_center = Vector2i(-map_width + 3, 0)
		team2_center = Vector2i(map_width - 3, 0)

	var team1_spawns = HexMath.get_hexes_in_radius(Vector3i(team1_center.x, team1_center.y, 0), 2)
	var team2_spawns = HexMath.get_hexes_in_radius(Vector3i(team2_center.x, team2_center.y, 0), 2)
	
	var final_t1_spawns: Array[Vector2i] = []
	var final_t2_spawns: Array[Vector2i] = []

	for i in range(units_per_team):
		if i < team1_spawns.size() and not is_abyss_cache.get(Vector2i(team1_spawns[i].x, team1_spawns[i].y), true):
			var h2d = Vector2i(team1_spawns[i].x, team1_spawns[i].y)
			temp_terrains[h2d] = active_biome.spawn_terrain
			temp_heights[h2d] = maxi(active_biome.water_level + 1, temp_heights[h2d])
			final_t1_spawns.append(h2d)
			spawn_locations.append(h2d)
			
		if i < team2_spawns.size() and not is_abyss_cache.get(Vector2i(team2_spawns[i].x, team2_spawns[i].y), true):
			var h2d = Vector2i(team2_spawns[i].x, team2_spawns[i].y)
			temp_terrains[h2d] = active_biome.spawn_terrain
			temp_heights[h2d] = maxi(active_biome.water_level + 1, temp_heights[h2d])
			final_t2_spawns.append(h2d)
			spawn_locations.append(h2d)

	# --- PASS 3 : RIVER (A*) ---
	var edges = HexMath.get_edge_hexes(coords)
	if edges.size() > 10:
		var edge_start = edges[randi() % edges.size()]
		var edge_end = edges[randi() % edges.size()]
		while HexMath.distance_2d_flat(Vector2i(edge_start.x, edge_start.y), Vector2i(edge_end.x, edge_end.y)) < map_radius:
			edge_end = edges[randi() % edges.size()]
			
		var river_path = HexMath.draw_line(edge_start, edge_end)
		for rh in river_path:
			var h2d = Vector2i(rh.x, rh.y)
			if temp_terrains.has(h2d) and not is_abyss_cache.get(h2d, true) and not spawn_locations.has(h2d):
				temp_terrains[h2d] = active_biome.water_terrain
				temp_heights[h2d] = active_biome.water_level

	# --- PASS 4 : MAIN ROAD (A*) ---
	var road_path = HexMath.draw_line(Vector3i(team1_center.x, team1_center.y, 0), Vector3i(team2_center.x, team2_center.y, 0))
	for rh in road_path:
		var h2d = Vector2i(rh.x, rh.y)
		if temp_terrains.has(h2d) and not is_abyss_cache.get(h2d, true) and not spawn_locations.has(h2d):
			if temp_terrains[h2d] == active_biome.water_terrain:
				temp_terrains[h2d] = active_biome.bridge_terrain
				temp_heights[h2d] = active_biome.water_level + 1
			else:
				temp_terrains[h2d] = active_biome.road_terrain
				temp_heights[h2d] = maxi(active_biome.water_level + 1, temp_heights[h2d])

	# --- PASS 5 : INSTANTIATION & SPAWN POINTS ---
	var spawn_group_nodes = get_tree().get_nodes_in_group("spawn_points")
	var spawn_group_node: Node = null
	if spawn_group_nodes.is_empty():
		spawn_group_node = Node3D.new()
		spawn_group_node.name = "GeneratedSpawnPoints"
		add_child(spawn_group_node)
	else:
		spawn_group_node = spawn_group_nodes[0]
		for child in spawn_group_node.get_children():
			child.queue_free()

	for hex_2d in temp_terrains.keys():
		var chosen_terrain = temp_terrains[hex_2d]
		if not chosen_terrain or not chosen_terrain.visual_prefab: continue
		
		var hex_coord = Vector3i(hex_2d.x, hex_2d.y, temp_heights[hex_2d])
		var tile: Node3D = chosen_terrain.visual_prefab.instantiate() as Node3D
		var world_pos: Vector3 = HexMath.hex_to_world(hex_coord, GridManager.hex_size, GridManager.elevation_step)
		tile.position = world_pos
		tile.name = "HexTile_%s_%d_%d_%d" % [chosen_terrain.id, hex_coord.x, hex_coord.y, hex_coord.z]

		add_child(tile)
		hex_tiles[hex_coord] = tile
		GridManager.terrain_tiles[hex_coord] = chosen_terrain
		if not obstacles.has(hex_coord):
			local_pathfinder.add_hex(hex_coord, world_pos, chosen_terrain.movement_cost)
		flat_to_3d[hex_2d] = hex_coord
		
		if chosen_terrain == active_biome.spawn_terrain:
			var sp = SpawnPoint.new()
			sp.position = world_pos
			if final_t1_spawns.has(hex_2d):
				sp.faction = 0 # PLAYER
				sp.stats = spawn_player_stats
				sp.name = "SpawnPlayer_%d_%d" % [hex_2d.x, hex_2d.y]
			else:
				sp.faction = 1 # ENEMY
				sp.stats = spawn_enemy_stats
				sp.name = "SpawnEnemy_%d_%d" % [hex_2d.x, hex_2d.y]
			spawn_group_node.add_child(sp)
			sp.add_to_group("spawn_points")

	for hex_coord: Vector3i in hex_tiles.keys():
		for dir: Vector2i in HexMath.DIRECTIONS:
			var flat_neighbor: Vector2i = Vector2i(hex_coord.x + dir.x, hex_coord.y + dir.y)
			if flat_to_3d.has(flat_neighbor):
				local_pathfinder.connect_hexes(hex_coord, flat_to_3d[flat_neighbor])

	GridManager.max_elevation = max_elevation
	GridManager.pathfinder = local_pathfinder
	GridEvents.grid_topology_ready.emit(GridManager.terrain_tiles)