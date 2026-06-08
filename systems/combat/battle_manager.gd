class_name BattleManager
extends Node

const ERR_MISSING_DEPS = "BattleManager: Dépendances manquantes ('player_unit_prefab')."

@export_category("Spawns")
## Le préfabriqué de l'unité à faire apparaître.
@export var player_unit_prefab: PackedScene
## Les données du Héros 1 à injecter.
@export var hero_stats: UnitStats
## Les données du Monstre 1 à injecter.
@export var enemy_stats: UnitStats

# GODOT BUILT-IN FUNCTIONS
func _ready() -> void:
	if not player_unit_prefab:
		push_error(ERR_MISSING_DEPS)
		return
		
	# On s'abonne à la génération de la grille au lieu de la piloter.
	GridEvents.grid_topology_ready.connect(_on_grid_topology_ready)

# SIGNAL HANDLERS
func _on_grid_topology_ready(_topology: Dictionary) -> void:
	_process_spawn_points()
	
	# Signal de fin d'instanciation. Le TurnManager (ou autre) peut maintenant prendre le relais.
	CombatEvents.units_spawned.emit()

# PRIVATE FUNCTIONS
func _process_spawn_points() -> void:
	var spawn_nodes: Array[Node] = get_tree().get_nodes_in_group("spawn_points")
	
	if spawn_nodes.is_empty():
		push_warning("BattleManager: Aucun nœud trouvé dans le groupe 'spawn_points'.")
		return
		
	for node: Node in spawn_nodes:
		var spawn_point := node as SpawnPoint
		if not spawn_point:
			continue
			
		if not spawn_point.stats:
			push_warning("BattleManager: SpawnPoint '%s' ignoré car il n'a pas de ressource 'stats' assignée." % spawn_point.name)
			continue
			
		# Conversion de la position globale (Monde) vers la grille logique
		var raw_hex: Vector3i = HexMath.world_to_hex(spawn_point.global_position, GridManager.hex_size, GridManager.elevation_step)
		
		# AAA : Retrouver la vraie élévation du terrain pour cette coordonnée 2D
		var target_hex: Vector3i = _get_surface_hex(raw_hex.x, raw_hex.y)
		
		var unit: Unit = player_unit_prefab.instantiate() as Unit
		# Placement 3D précis basé sur la logique HexMath
		unit.position = HexMath.hex_to_world(target_hex, GridManager.hex_size, GridManager.elevation_step)
		add_child(unit)
		
		# AAA : Duplication des stats pour éviter que tous les héros partagent la même barre de PV
		var unique_stats: UnitStats = spawn_point.stats.duplicate() as UnitStats
		unit.initialize(unique_stats, spawn_point.faction)
		
		TurnEvents.register_unit_requested.emit(unit)

## Scanne la grille pour trouver la case (et surtout sa hauteur Z) correspondant à une coordonnée 2D.
func _get_surface_hex(q: int, r: int) -> Vector3i:
	var elevation: int = GridManager.get_elevation(q, r)
	return Vector3i(q, r, elevation)