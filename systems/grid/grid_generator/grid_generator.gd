class_name GridGenerator
extends Node3D

# EXPORTS
@export var map_radius: int = 5
@export var hex_prefab: PackedScene = preload("res://systems/grid/grid_generator/hex_tile.tscn")
## La donnée de terrain (ex: Plaine) à injecter dans la grille logique lors de la génération.
@export var default_terrain: TerrainData
@export var obstacles: Array[Vector3i] = []

@export_category("Procedural Generation")
## Bruit utilisé pour générer le relief de la carte (Laisser vide pour une carte plate).
@export var elevation_noise: FastNoiseLite
## Hauteur maximale (Z) que la génération procédurale peut atteindre.
@export var max_elevation: int = 3

# PUBLIC VARIABLES
## Dictionnaire contenant toutes les tuiles instanciées sur le plateau.
## Clé : Vector3i (Coordonnées hexagonales abstraites, ex: (0, 0, 0))
## Valeur : Node3D (Le modèle 3D physique instancié dans la scène)
var hex_tiles: Dictionary[Vector3i, Node3D] = {}

# GODOT BUILT-IN FUNCTIONS
func _ready() -> void:
	pass # Le DDD exige que l'Orchestrateur (BattleManager) contrôle le moment de la génération.

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

	# Validation des dépendances requise par les standards
	if not hex_prefab:
		push_error("GridGenerator: La ressource 'hex_prefab' est manquante.")
		return
	if not default_terrain:
		push_error("GridGenerator: La ressource 'default_terrain' est manquante. Le DDD exige une donnée.")
		return

	# Le rayon génère par défaut à Z=0 (Sol). Les obstacles peuvent avoir des Z différents.
	var coords: Array[Vector3i] = HexMath.get_hexes_in_radius(Vector3i.ZERO, map_radius)
	var local_pathfinder: HexPathfinder = HexPathfinder.new()

	# Dictionnaire temporaire pour trouver rapidement le vrai Z d'une coordonnée 2D (Q, R)
	var flat_to_3d: Dictionary[Vector2i, Vector3i] = {}

	# Optionnel : On change la graine (seed) à chaque génération pour avoir une carte unique
	if elevation_noise:
		elevation_noise.seed = randi()

	for hex_coord: Vector3i in coords:
		# Application du relief procédural via le bruit (Noise)
		if elevation_noise:
			var noise_val: float = elevation_noise.get_noise_2d(hex_coord.x * 10.0, hex_coord.y * 10.0)
			# Remappe la valeur du bruit [-1.0, 1.0] vers un niveau de hauteur entier [0, max_elevation]
			hex_coord.z = roundi(remap(noise_val, -1.0, 1.0, 0, max_elevation))

		# Si la coordonnée est déclarée comme obstacle, on l'ignore : elle n'aura ni tuile, ni pathfinding.
		if obstacles.has(hex_coord):
			continue
			
		var tile: Node3D = hex_prefab.instantiate() as Node3D
		if not tile:
			push_error("GridGenerator: Impossible d'instancier 'hex_prefab' en tant que Node3D.")
			continue

		# Utilisation de notre utilitaire mathématique pour le placement spatial
		var world_pos: Vector3 = HexMath.hex_to_world(hex_coord, GridManager.hex_size, GridManager.elevation_step)
		tile.position = world_pos
		tile.name = "HexTile_%d_%d_%d" % [hex_coord.x, hex_coord.y, hex_coord.z]

		add_child(tile)
		hex_tiles[hex_coord] = tile
		
		# Injections de données vitales
		GridManager.terrain_tiles[hex_coord] = default_terrain
		local_pathfinder.add_hex(hex_coord, world_pos, default_terrain.movement_cost)
		flat_to_3d[Vector2i(hex_coord.x, hex_coord.y)] = hex_coord

	# Deuxième passe : Connexion des voisins valides pour la navigation
	for hex_coord: Vector3i in hex_tiles.keys():
		for dir: Vector2i in HexMath.DIRECTIONS:
			var flat_neighbor: Vector2i = Vector2i(hex_coord.x + dir.x, hex_coord.y + dir.y)
			if flat_to_3d.has(flat_neighbor):
				local_pathfinder.connect_hexes(hex_coord, flat_to_3d[flat_neighbor])

	# Le graphe est terminé, on le rend disponible publiquement (Data-Driven Design)
	GridManager.pathfinder = local_pathfinder