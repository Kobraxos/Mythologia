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
## Terrain de repli si aucun biome ne correspond ou erreur
@export var fallback_terrain: TerrainData
## Bruit déterminant l'humidité/fertilité de chaque case
@export var moisture_noise: FastNoiseLite
## Terrain utilisé pour les zones arides (humidité <= 0.0)
@export var arid_terrain: TerrainData
## Terrain utilisé pour les zones fertiles (humidité > 0.0)
@export var fertile_terrain: TerrainData
## Terrain utilisé pour l'eau
@export var water_terrain: TerrainData
## Niveau Z (altitude) sous lequel les tuiles deviennent de l'eau
@export var water_level: int = 0

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
		moisture_noise.seed = grid_seed + 1000 # Graine décalée pour éviter la corrélation avec l'élévation

	for hex_coord: Vector3i in coords:
		# Application du relief procédural via le bruit (Noise)
		if elevation_noise:
			var noise_val: float = elevation_noise.get_noise_2d(hex_coord.x * 10.0, hex_coord.y * 10.0)
			# Remappe la valeur du bruit [-1.0, 1.0] vers un niveau de hauteur entier [0, max_elevation]
			hex_coord.z = roundi(remap(noise_val, -1.0, 1.0, 0, max_elevation))

		# Si la coordonnée est déclarée comme obstacle, on l'ignore : elle n'aura ni tuile, ni pathfinding.
		if obstacles.has(hex_coord):
			continue
			
		# --- BIOME SELECTION ---
		var chosen_terrain: TerrainData = fallback_terrain
		
		# 1. Vérification de l'eau (Altitude)
		if hex_coord.z <= water_level and water_terrain:
			chosen_terrain = water_terrain
		else:
			# 2. Logique d'humidité (Moisture)
			if moisture_noise:
				var moisture_val: float = moisture_noise.get_noise_2d(hex_coord.x * 10.0, hex_coord.y * 10.0)
				if moisture_val > 0.0 and fertile_terrain:
					chosen_terrain = fertile_terrain
				elif arid_terrain:
					chosen_terrain = arid_terrain
			else:
				# Fallback si pas de bruit défini
				if fertile_terrain: chosen_terrain = fertile_terrain
				elif arid_terrain: chosen_terrain = arid_terrain
			
		if not chosen_terrain:
			push_error("GridGenerator: Aucun TerrainData valide trouvé (fallback, fertile, ou aride).")
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