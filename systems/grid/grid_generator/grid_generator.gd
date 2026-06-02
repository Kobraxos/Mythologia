class_name GridGenerator
extends Node3D

# EXPORTS
@export var map_radius: int = 5
@export var hex_size: float = 1.0
@export var hex_prefab: PackedScene = preload("res://systems/grid/grid_generator/hex_tile.tscn")
@export var obstacles: Array[Vector3i] = []

# PUBLIC VARIABLES
## Dictionnaire contenant toutes les tuiles instanciées sur le plateau.
## Clé : Vector3i (Coordonnées hexagonales abstraites, ex: (0, 0, 0))
## Valeur : Node3D (Le modèle 3D physique instancié dans la scène)
var hex_tiles: Dictionary[Vector3i, Node3D] = {}

# GODOT BUILT-IN FUNCTIONS
func _ready() -> void:
	generate_grid()

# PUBLIC FUNCTIONS
## Fonction principale qui assemble le plateau en traduisant les mathématiques en 3D.
func generate_grid() -> void:
	# Nettoyage de sécurité ciblé : on ne supprime QUE les tuiles générées précédemment
	for tile: Node3D in hex_tiles.values():
		if is_instance_valid(tile):
			tile.queue_free()
	hex_tiles.clear()

	# Validation des dépendances requise par les standards
	if not hex_prefab:
		push_error("GridGenerator: La ressource 'hex_prefab' est manquante.")
		return

	var coords: Array[Vector3i] = HexMath.get_hexes_in_radius(Vector3i.ZERO, map_radius)
	var local_pathfinder: HexPathfinder = HexPathfinder.new()

	for hex_coord: Vector3i in coords:
		# Si la coordonnée est déclarée comme obstacle, on l'ignore : elle n'aura ni tuile, ni pathfinding.
		if obstacles.has(hex_coord):
			continue
			
		var tile: Node3D = hex_prefab.instantiate() as Node3D
		if not tile:
			push_error("GridGenerator: Impossible d'instancier 'hex_prefab' en tant que Node3D.")
			continue

		# Utilisation de notre utilitaire mathématique pour le placement spatial
		tile.position = HexMath.hex_to_world(hex_coord, hex_size)
		tile.name = "HexTile_%d_%d_%d" % [hex_coord.x, hex_coord.y, hex_coord.z]

		add_child(tile)
		hex_tiles[hex_coord] = tile
		local_pathfinder.add_hex(hex_coord)

	# Deuxième passe : Connexion des voisins valides pour la navigation
	for hex_coord: Vector3i in hex_tiles.keys():
		var neighbors: Array[Vector3i] = HexMath.get_all_neighbors(hex_coord)
		for neighbor: Vector3i in neighbors:
			if local_pathfinder.has_hex(neighbor):
				local_pathfinder.connect_hexes(hex_coord, neighbor)

	# Le graphe est terminé, on le rend disponible publiquement (Data-Driven Design)
	GridManager.pathfinder = local_pathfinder