class_name GridGenerator
extends Node3D

# EXPORTS
@export var map_radius: int = 5
@export var obstacles: Array[Vector3i] = []

@export_category("Procedural Generation")
## Bruit utilisé pour générer le relief de la carte (Laisser vide pour une carte plate).
@export var elevation_noise: FastNoiseLite
## Hauteur maximale (Z) que la génération procédurale peut atteindre.
@export var max_elevation: int = 3

@export_category("Biome Generation")
## Palette contenant tous les terrains pour ce niveau
@export var active_biome: BiomePalette
## Bruit déterminant l'humidité/fertilité de chaque case
@export var moisture_noise: FastNoiseLite
## Bruit déterminant l'apparition d'obstacles
@export var obstacle_noise: FastNoiseLite
## Bruit déterminant l'apparition des routes de marbre
@export var road_noise: FastNoiseLite
## Bruit déterminant l'apparition des éléments spéciaux (Nectar)
@export var special_noise: FastNoiseLite

@export_category("Procedural Features")
## Les structures préfabriquées à tamponner sur la carte.
@export var features: Array[GridFeature] = []
## Le nombre de tampons que l'on essaie de placer par défaut.
@export var feature_count: int = 0

# PUBLIC VARIABLES
## Dictionnaire contenant toutes les tuiles instanciées sur le plateau.
## Clé : Vector3i (Coordonnées hexagonales abstraites, ex: (0, 0, 0))
## Valeur : Node3D (Le modèle 3D physique instancié dans la scène)
var hex_tiles: Dictionary[Vector3i, Node3D] = {}

# GODOT BUILT-IN FUNCTIONS
func _ready() -> void:
	# Le DDD exige que l'Orchestrateur (ex: GameFlowManager) contrôle le moment de la génération.
	GridEvents.request_grid_generation.connect(generate_grid)

# PUBLIC FUNCTIONS
## Fonction principale qui assemble le plateau en traduisant les mathématiques en 3D.
func generate_grid() -> void:
	# Nettoyage de sécurité ciblé : on ne supprime QUE les tuiles générées précédemment
	for tile: Node3D in hex_tiles.values():
		if is_instance_valid(tile):
			tile.queue_free()
	hex_tiles.clear()
	
	# Synchronisation absolue avec la Couche 2 (Modèle de données)
	GridManager.clear_terrain()

	# Le rayon génère par défaut à Z=0 (Sol). Les obstacles peuvent avoir des Z différents.
	var coords: Array[Vector3i] = HexMath.get_hexes_in_radius(Vector3i.ZERO, map_radius)
	var local_pathfinder: HexPathfinder = HexPathfinder.new()

	# Dictionnaire temporaire pour trouver rapidement le vrai Z d'une coordonnée 2D (Q, R)
	var flat_to_3d: Dictionary[Vector2i, Vector3i] = {}

	# Optionnel : On change la graine (seed) à chaque génération pour avoir une carte unique
	var grid_seed: int = randi()
	if elevation_noise:
		elevation_noise.seed = grid_seed
	if moisture_noise:
		moisture_noise.seed = grid_seed + 1000 # Graine décalée
	if obstacle_noise:
		obstacle_noise.seed = grid_seed + 2000 # Graine décalée
	if road_noise:
		road_noise.seed = grid_seed + 3000
	if special_noise:
		special_noise.seed = grid_seed + 4000
		
	# --- PASSE DE STAMPING (Features) ---
	var stamped_hexes: Dictionary[Vector2i, GridFeatureNode] = {}
	var stamped_heights: Dictionary[Vector2i, int] = {}
	var invalid_centers: Dictionary[Vector2i, bool] = {}
	
	if feature_count > 0 and features.size() > 0:
		for i in range(feature_count):
			var feature: GridFeature = features.pick_random()
			if not feature or feature.nodes.is_empty(): continue
			
			var valid_centers = coords.filter(func(c): return not invalid_centers.has(Vector2i(c.x, c.y)))
			if valid_centers.is_empty(): break
			
			var center: Vector3i = valid_centers.pick_random()
			var center_2d := Vector2i(center.x, center.y)
			
			var base_z: int = 0
			if elevation_noise:
				base_z = roundi(remap(elevation_noise.get_noise_2d(center.x * 10.0, center.y * 10.0), -1.0, 1.0, 0, max_elevation))
				
			for node in feature.nodes:
				var abs_2d = Vector2i(center_2d.x + node.relative_q, center_2d.y + node.relative_r)
				stamped_hexes[abs_2d] = node
				stamped_heights[abs_2d] = base_z + node.height_offset
				invalid_centers[abs_2d] = true

	# --- PASSE PRINCIPALE ---
	for hex_coord: Vector3i in coords:
		var hex_2d := Vector2i(hex_coord.x, hex_coord.y)
		var dist_to_center: int = HexMath.distance_2d_flat(Vector2i.ZERO, hex_2d)
		
		# Application du relief procédural via le bruit (Noise)
		if elevation_noise:
			var noise_val: float = elevation_noise.get_noise_2d(hex_coord.x * 10.0, hex_coord.y * 10.0)
			# Remappe la valeur du bruit [-1.0, 1.0] vers un niveau de hauteur entier [0, max_elevation]
			hex_coord.z = roundi(remap(noise_val, -1.0, 1.0, 0, max_elevation))
			
		# AAA : Priorité au Tampon (Override de la génération procédurale)
		if stamped_hexes.has(hex_2d):
			var node: GridFeatureNode = stamped_hexes[hex_2d]
			hex_coord.z = stamped_heights[hex_2d]
			
			if active_biome:
				var chosen_terrain = active_biome.get_terrain_by_role(node.role)
				if chosen_terrain and chosen_terrain.visual_prefab:
					var tile: Node3D = chosen_terrain.visual_prefab.instantiate() as Node3D
					var world_pos: Vector3 = HexMath.hex_to_world(hex_coord, GridManager.hex_size, GridManager.elevation_step)
					tile.position = world_pos
					tile.name = "HexTile_Feature_%s_%d_%d_%d" % [chosen_terrain.id, hex_coord.x, hex_coord.y, hex_coord.z]
					add_child(tile)
					hex_tiles[hex_coord] = tile
					GridManager.terrain_tiles[hex_coord] = chosen_terrain
					local_pathfinder.add_hex(hex_coord, world_pos, chosen_terrain.movement_cost)
					flat_to_3d[hex_2d] = hex_coord
			continue

		# Si la coordonnée est déclarée comme obstacle, on l'ignore : elle n'aura ni tuile, ni pathfinding.
		if obstacles.has(hex_coord):
			continue
			
		# --- BIOME SELECTION ---
		if not active_biome:
			push_error("GridGenerator: Aucune BiomePalette assignée !")
			continue

		var chosen_terrain: TerrainData = active_biome.base_terrain
		
		# 0. Abyss Logic (Bords de la carte)
		if dist_to_center >= map_radius and active_biome.abyss_terrain:
			chosen_terrain = active_biome.abyss_terrain
		else:
			# 1. Vérification de l'eau/liquide (Altitude)
			if hex_coord.z <= active_biome.water_level:
				if special_noise and active_biome.special_terrain:
					var special_val: float = special_noise.get_noise_2d(hex_coord.x * 10.0, hex_coord.y * 10.0)
					if special_val > 0.6:
						chosen_terrain = active_biome.special_terrain
					elif active_biome.water_terrain:
						chosen_terrain = active_biome.water_terrain
				elif active_biome.water_terrain:
					chosen_terrain = active_biome.water_terrain
			else:
				# 2. Vérification des obstacles (Bruit haute fréquence)
				var is_obstacle: bool = false
				if obstacle_noise and active_biome.obstacle_terrain:
					var obs_val: float = obstacle_noise.get_noise_2d(hex_coord.x * 10.0, hex_coord.y * 10.0)
					if obs_val > 0.6:
						chosen_terrain = active_biome.obstacle_terrain
						is_obstacle = true
						
				# 3. Logique de route (Marbre)
				var is_road: bool = false
				if not is_obstacle and road_noise and active_biome.road_terrain:
					var road_val: float = road_noise.get_noise_2d(hex_coord.x * 10.0, hex_coord.y * 10.0)
					if road_val > 0.5:
						chosen_terrain = active_biome.road_terrain
						is_road = true
						
				# 4. Logique d'humidité (Moisture)
				if not is_obstacle and not is_road:
					if moisture_noise:
						var moisture_val: float = moisture_noise.get_noise_2d(hex_coord.x * 10.0, hex_coord.y * 10.0)
						if moisture_val > 0.0 and active_biome.fertile_terrain:
							chosen_terrain = active_biome.fertile_terrain
						elif active_biome.base_terrain:
							chosen_terrain = active_biome.base_terrain
					else:
						if active_biome.base_terrain: chosen_terrain = active_biome.base_terrain
			
		if not chosen_terrain:
			push_error("GridGenerator: Aucun TerrainData valide trouvé dans la palette.")
			continue
			
		if not chosen_terrain.visual_prefab:
			push_error("GridGenerator: 'visual_prefab' manquant dans la donnée de terrain '%s'." % chosen_terrain.id)
			continue
			
		var tile: Node3D = chosen_terrain.visual_prefab.instantiate() as Node3D
		if not tile:
			push_error("GridGenerator: Impossible d'instancier le visuel en tant que Node3D.")
			continue

		# Utilisation de notre utilitaire mathématique pour le placement spatial
		var world_pos: Vector3 = HexMath.hex_to_world(hex_coord, GridManager.hex_size, GridManager.elevation_step)
		tile.position = world_pos
		tile.name = "HexTile_%s_%d_%d_%d" % [chosen_terrain.id, hex_coord.x, hex_coord.y, hex_coord.z]

		add_child(tile)
		hex_tiles[hex_coord] = tile
		
		# Injections de données vitales
		GridManager.terrain_tiles[hex_coord] = chosen_terrain
		local_pathfinder.add_hex(hex_coord, world_pos, chosen_terrain.movement_cost)
		flat_to_3d[Vector2i(hex_coord.x, hex_coord.y)] = hex_coord

	# Deuxième passe : Connexion des voisins valides pour la navigation
	for hex_coord: Vector3i in hex_tiles.keys():
		for dir: Vector2i in HexMath.DIRECTIONS:
			var flat_neighbor: Vector2i = Vector2i(hex_coord.x + dir.x, hex_coord.y + dir.y)
			if flat_to_3d.has(flat_neighbor):
				local_pathfinder.connect_hexes(hex_coord, flat_to_3d[flat_neighbor])

	# Enregistrement de la hauteur max pour le ray-marching mathématique
	GridManager.max_elevation = max_elevation
	# Le graphe est terminé, on le rend disponible publiquement (Data-Driven Design)
	GridManager.pathfinder = local_pathfinder
	
	# AAA : Émission de la topologie pure pour l'initialisation des systèmes DOD (ex: GridLosSystem)
	GridEvents.grid_topology_ready.emit(GridManager.terrain_tiles)