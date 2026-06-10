class_name GridGenerator
extends Node3D

const GROUP_SPAWN_POINTS := "spawn_points"
const TILE_NAME_FORMAT := "HexTile_%s_%d_%d_%d"
const SPAWN_PLAYER_FORMAT := "SpawnPlayer_%d_%d"
const SPAWN_ENEMY_FORMAT := "SpawnEnemy_%d_%d"
const NODE_NAME_SPAWNS := "GeneratedSpawnPoints"

enum MapShape { HEXAGON, RECTANGLE }

@export_category("Dimensions")
@export var map_shape: MapShape = MapShape.HEXAGON
@export var map_radius: int = 12
@export var map_width: int = 15
@export var map_height: int = 10
@export var obstacles: Array[Vector3i] = []

@export_category("Procedural Generation")
## Master seed. Si 0, un seed aléatoire sera utilisé.
@export var base_seed: int = 0
@export var elevation_noise: FastNoiseLite
@export var max_elevation: int = 8

@export_category("Noise Thresholds")
@export var noise_frequency: float = 10.0
@export var special_threshold: float = 0.6
@export var obstacle_threshold: float = 0.6
@export var road_threshold: float = 0.5
@export var moisture_threshold: float = 0.0

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
var _spawn_group_node: Node3D

func _ready() -> void:
	GridEvents.request_grid_generation.connect(generate_grid)

func _exit_tree() -> void:
	hex_tiles.clear()

func generate_grid() -> void:
	# Guard Clause : Vérification stricte des dépendances
	if not is_instance_valid(active_biome):
		push_error("GridGenerator: L'active_biome est manquant ! Impossible de générer la grille.")
		return
		
	_clear_previous_grid()
	
	var coords: Array[Vector3i] = _get_base_coordinates()
	var local_pathfinder: HexPathfinder = HexPathfinder.new()
	var flat_to_3d: Dictionary = {}
	
	# Initialisation du Master Seed
	var current_seed: int = base_seed
	if current_seed == 0:
		current_seed = randi()
		
	_initialize_noises(current_seed)
	
	var temp_heights: Dictionary = {}
	var temp_terrains: Dictionary = {}
	var is_abyss_cache: Dictionary = {}
	
	# OPTIMISATION AAA : O(1) Lookups via Dictionary au lieu de O(N) Array
	var spawn_locations: Dictionary = {}
	var final_t1_spawns: Dictionary = {}
	var final_t2_spawns: Dictionary = {}
	
	var obstacles_cache: Dictionary = {}
	for obs: Vector3i in obstacles:
		obstacles_cache[obs] = true
	
	# Passes de génération
	_pass_1_base_and_height(coords, temp_heights, temp_terrains, is_abyss_cache)
	_pass_2_spawns(temp_heights, temp_terrains, is_abyss_cache, spawn_locations, final_t1_spawns, final_t2_spawns)
	_pass_3_river(coords, temp_heights, temp_terrains, is_abyss_cache, spawn_locations)
	_pass_4_road(temp_heights, temp_terrains, is_abyss_cache, spawn_locations)
	_pass_5_features(temp_heights, temp_terrains, is_abyss_cache, spawn_locations)
	_pass_6_instantiation(temp_heights, temp_terrains, final_t1_spawns, final_t2_spawns, flat_to_3d, local_pathfinder, obstacles_cache)
	
	# Connexion du pathfinding
	for hex_coord: Vector3i in hex_tiles.keys():
		for dir: Vector2i in HexMath.DIRECTIONS:
			var flat_neighbor := Vector2i(hex_coord.x + dir.x, hex_coord.y + dir.y)
			if flat_to_3d.has(flat_neighbor):
				local_pathfinder.connect_hexes(hex_coord, flat_to_3d[flat_neighbor] as Vector3i)

	GridManager.max_elevation = max_elevation
	GridManager.pathfinder = local_pathfinder
	GridEvents.grid_topology_ready.emit(GridManager.terrain_tiles)

func _clear_previous_grid() -> void:
	for tile: Node in hex_tiles.values():
		if is_instance_valid(tile):
			tile.queue_free()
	hex_tiles.clear()
	GridManager.clear_terrain()
	
	if is_instance_valid(_spawn_group_node):
		for child: Node in _spawn_group_node.get_children():
			child.queue_free()
	else:
		_spawn_group_node = Node3D.new()
		_spawn_group_node.name = NODE_NAME_SPAWNS
		add_child(_spawn_group_node)

func _get_base_coordinates() -> Array[Vector3i]:
	var coords: Array[Vector3i] = []
	if map_shape == MapShape.HEXAGON:
		coords = HexMath.get_hexes_in_radius(Vector3i.ZERO, map_radius)
	else:
		coords = HexMath.get_hexes_in_rectangle(Vector3i.ZERO, map_width, map_height)
	return coords

func _initialize_noises(master_seed: int) -> void:
	if elevation_noise: elevation_noise.seed = master_seed + hash("elevation")
	if moisture_noise: moisture_noise.seed = master_seed + hash("moisture")
	if obstacle_noise: obstacle_noise.seed = master_seed + hash("obstacle")
	if road_noise: road_noise.seed = master_seed + hash("road")
	if special_noise: special_noise.seed = master_seed + hash("special")

func _pass_1_base_and_height(coords: Array[Vector3i], temp_heights: Dictionary, temp_terrains: Dictionary, is_abyss_cache: Dictionary) -> void:
	for hex_coord: Vector3i in coords:
		var h2d := Vector2i(hex_coord.x, hex_coord.y)
		var dist_to_center: int = HexMath.distance_2d_flat(Vector2i.ZERO, h2d)
		
		var z: int = 0
		if elevation_noise:
			var noise_val: float = elevation_noise.get_noise_2d(hex_coord.x * noise_frequency, hex_coord.y * noise_frequency)
			z = roundi(remap(noise_val, -1.0, 1.0, 0.0, float(max_elevation)))
		temp_heights[h2d] = z
		
		var is_abyss: bool = false
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
				if special_noise and active_biome.special_terrain and special_noise.get_noise_2d(h2d.x * noise_frequency, h2d.y * noise_frequency) > special_threshold:
					chosen_terrain = active_biome.special_terrain
				else:
					chosen_terrain = active_biome.water_terrain
			else:
				var is_obstacle: bool = false
				if obstacle_noise and active_biome.obstacle_terrain and obstacle_noise.get_noise_2d(h2d.x * noise_frequency, h2d.y * noise_frequency) > obstacle_threshold:
					chosen_terrain = active_biome.obstacle_terrain
					is_obstacle = true
				if not is_obstacle and road_noise and active_biome.road_terrain and road_noise.get_noise_2d(h2d.x * noise_frequency, h2d.y * noise_frequency) > road_threshold:
					chosen_terrain = active_biome.road_terrain
				elif not is_obstacle and moisture_noise and moisture_noise.get_noise_2d(h2d.x * noise_frequency, h2d.y * noise_frequency) > moisture_threshold and active_biome.fertile_terrain:
					chosen_terrain = active_biome.fertile_terrain
		temp_terrains[h2d] = chosen_terrain

func _pass_2_spawns(temp_heights: Dictionary, temp_terrains: Dictionary, is_abyss_cache: Dictionary, spawn_locations: Dictionary, final_t1_spawns: Dictionary, final_t2_spawns: Dictionary) -> void:
	var team1_center := Vector2i(-int(map_radius * 0.7), 0)
	var team2_center := Vector2i(int(map_radius * 0.7), 0)
	if map_shape == MapShape.RECTANGLE:
		team1_center = Vector2i(-map_width + 3, 0)
		team2_center = Vector2i(map_width - 3, 0)

	var team1_spawns: Array = HexMath.get_hexes_in_radius(Vector3i(team1_center.x, team1_center.y, 0), 2)
	var team2_spawns: Array = HexMath.get_hexes_in_radius(Vector3i(team2_center.x, team2_center.y, 0), 2)

	for i: int in range(units_per_team):
		if i < team1_spawns.size():
			var h2d := Vector2i(team1_spawns[i].x, team1_spawns[i].y)
			if not is_abyss_cache.get(h2d, true):
				temp_terrains[h2d] = active_biome.spawn_terrain
				temp_heights[h2d] = maxi(active_biome.water_level + 1, temp_heights[h2d] as int)
				final_t1_spawns[h2d] = true
				spawn_locations[h2d] = true
			
		if i < team2_spawns.size():
			var h2d := Vector2i(team2_spawns[i].x, team2_spawns[i].y)
			if not is_abyss_cache.get(h2d, true):
				temp_terrains[h2d] = active_biome.spawn_terrain
				temp_heights[h2d] = maxi(active_biome.water_level + 1, temp_heights[h2d] as int)
				final_t2_spawns[h2d] = true
				spawn_locations[h2d] = true

func _pass_3_river(coords: Array[Vector3i], temp_heights: Dictionary, temp_terrains: Dictionary, is_abyss_cache: Dictionary, spawn_locations: Dictionary) -> void:
	var edges: Array = HexMath.get_edge_hexes(coords)
	if edges.size() > 10:
		var edge_start: Vector3i = edges[randi() % edges.size()]
		var edge_end: Vector3i = edges[randi() % edges.size()]
		var attempts: int = 0
		while HexMath.distance_2d_flat(Vector2i(edge_start.x, edge_start.y), Vector2i(edge_end.x, edge_end.y)) < map_radius and attempts < 100:
			edge_end = edges[randi() % edges.size()]
			attempts += 1
			
		var river_path: Array = HexMath.draw_line(edge_start, edge_end)
		for rh: Vector3i in river_path:
			var h2d := Vector2i(rh.x, rh.y)
			if temp_terrains.has(h2d) and not is_abyss_cache.get(h2d, true) and not spawn_locations.has(h2d):
				temp_terrains[h2d] = active_biome.water_terrain
				temp_heights[h2d] = active_biome.water_level

func _pass_4_road(temp_heights: Dictionary, temp_terrains: Dictionary, is_abyss_cache: Dictionary, spawn_locations: Dictionary) -> void:
	var team1_center := Vector2i(-int(map_radius * 0.7), 0)
	var team2_center := Vector2i(int(map_radius * 0.7), 0)
	if map_shape == MapShape.RECTANGLE:
		team1_center = Vector2i(-map_width + 3, 0)
		team2_center = Vector2i(map_width - 3, 0)
		
	var road_path: Array = HexMath.draw_line(Vector3i(team1_center.x, team1_center.y, 0), Vector3i(team2_center.x, team2_center.y, 0))
	for rh: Vector3i in road_path:
		var h2d := Vector2i(rh.x, rh.y)
		if temp_terrains.has(h2d) and not is_abyss_cache.get(h2d, true) and not spawn_locations.has(h2d):
			if temp_terrains[h2d] == active_biome.water_terrain:
				temp_terrains[h2d] = active_biome.bridge_terrain
				temp_heights[h2d] = active_biome.water_level + 1
			else:
				temp_terrains[h2d] = active_biome.road_terrain
				temp_heights[h2d] = maxi(active_biome.water_level + 1, temp_heights[h2d] as int)

func _pass_5_features(temp_heights: Dictionary, temp_terrains: Dictionary, is_abyss_cache: Dictionary, spawn_locations: Dictionary) -> void:
	if feature_count <= 0 or features.is_empty():
		return
		
	var valid_keys: Array = temp_terrains.keys()
	var max_attempts := 50
	
	for i: int in range(feature_count):
		var feature: GridFeature = features[randi() % features.size()]
		if not is_instance_valid(feature): continue
		
		var placed := false
		for attempt: int in range(max_attempts):
			var center_h2d: Vector2i = valid_keys[randi() % valid_keys.size()]
			var center_z: int = temp_heights[center_h2d] as int
			
			var can_place := true
			var footprint: Array[Vector2i] = []
			
			# Vérification de l'empreinte totale
			for node: GridFeatureNode in feature.nodes:
				var target_h2d := Vector2i(center_h2d.x + node.relative_q, center_h2d.y + node.relative_r)
				
				# Hors carte ?
				if not temp_terrains.has(target_h2d) or is_abyss_cache.get(target_h2d, true):
					can_place = false
					break
				
				# Zone de spawn ?
				if spawn_locations.has(target_h2d):
					can_place = false
					break
					
				var current_terrain: TerrainData = temp_terrains[target_h2d]
				# Eau ou Route ?
				if current_terrain == active_biome.water_terrain or current_terrain == active_biome.road_terrain or current_terrain == active_biome.bridge_terrain:
					can_place = false
					break
					
				# Variation d'altitude trop abrupte ?
				var target_z: int = temp_heights[target_h2d] as int
				if abs(target_z - center_z) > 1:
					can_place = false
					break
					
				footprint.append(target_h2d)
				
			if can_place:
				# Placement validé
				for node: GridFeatureNode in feature.nodes:
					var target_h2d := Vector2i(center_h2d.x + node.relative_q, center_h2d.y + node.relative_r)
					temp_terrains[target_h2d] = active_biome.get_terrain_by_role(node.role)
					temp_heights[target_h2d] = center_z + node.height_offset
				placed = true
				break
				
		if not placed:
			push_warning("GridGenerator: Impossible de placer la feature '%s' après %d essais." % [feature.feature_name, max_attempts])

func _pass_6_instantiation(temp_heights: Dictionary, temp_terrains: Dictionary, final_t1_spawns: Dictionary, final_t2_spawns: Dictionary, flat_to_3d: Dictionary, local_pathfinder: HexPathfinder, obstacles_cache: Dictionary) -> void:
	for hex_2d: Vector2i in temp_terrains.keys():
		var chosen_terrain: TerrainData = temp_terrains[hex_2d] as TerrainData
		if not is_instance_valid(chosen_terrain) or not is_instance_valid(chosen_terrain.visual_prefab): 
			continue
		
		var z_height: int = temp_heights[hex_2d] as int
		var hex_coord := Vector3i(hex_2d.x, hex_2d.y, z_height)
		var tile: Node3D = chosen_terrain.visual_prefab.instantiate() as Node3D
		var world_pos: Vector3 = HexMath.hex_to_world(hex_coord, GridManager.hex_size, GridManager.elevation_step)
		
		tile.position = world_pos
		tile.name = TILE_NAME_FORMAT % [chosen_terrain.id, hex_coord.x, hex_coord.y, hex_coord.z]

		add_child(tile)
		hex_tiles[hex_coord] = tile
		GridManager.terrain_tiles[hex_coord] = chosen_terrain
		
		if not obstacles_cache.has(hex_coord):
			local_pathfinder.add_hex(hex_coord, world_pos, chosen_terrain.movement_cost)
		flat_to_3d[hex_2d] = hex_coord
		
		# Spawns
		if chosen_terrain == active_biome.spawn_terrain:
			var sp = SpawnPoint.new()
			sp.position = world_pos
			if final_t1_spawns.has(hex_2d):
				sp.faction = 0 # PLAYER
				sp.stats = spawn_player_stats
				sp.name = SPAWN_PLAYER_FORMAT % [hex_2d.x, hex_2d.y]
			else:
				sp.faction = 1 # ENEMY
				sp.stats = spawn_enemy_stats
				sp.name = SPAWN_ENEMY_FORMAT % [hex_2d.x, hex_2d.y]
				
			_spawn_group_node.add_child(sp)
			sp.add_to_group(GROUP_SPAWN_POINTS)