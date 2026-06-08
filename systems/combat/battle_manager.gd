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
	if hero_stats and enemy_stats:
		_spawn_units_from_group("player_spawns", hero_stats, Unit.Faction.PLAYER)
		_spawn_units_from_group("enemy_spawns", enemy_stats, Unit.Faction.ENEMY)
	
	# Signal de fin d'instanciation. Le TurnManager (ou autre) peut maintenant prendre le relais.
	CombatEvents.units_spawned.emit()

# PRIVATE FUNCTIONS
func _spawn_units_from_group(group_name: String, stats: UnitStats, faction: Unit.Faction) -> void:
	var spawn_nodes: Array[Node] = get_tree().get_nodes_in_group(group_name)
	for spawn_node: Node in spawn_nodes:
		if spawn_node is Node3D:
			# Conversion de la position globale (Monde) vers la grille logique
			var target_hex: Vector3i = HexMath.world_to_hex(spawn_node.global_position, GridManager.hex_size, GridManager.elevation_step)
			
			var unit: Unit = player_unit_prefab.instantiate() as Unit
			# Placement 3D précis basé sur la logique HexMath
			unit.position = HexMath.hex_to_world(target_hex, GridManager.hex_size, GridManager.elevation_step)
			add_child(unit)
			unit.initialize(stats, faction)
			
			# Note : L'enregistrement dans le TurnManager pourrait aussi se faire
			# de manière event-driven (ex: via GridEvents.unit_spawned), mais ici 
			# on s'assure que tout est prêt pour le début de combat.
			# Pour un AAA strict, le TurnManager devrait écouter l'événement "unit_spawned".
			# On le simule ici si l'enregistrement dépend encore d'une fonction publique.
			# Dans notre refactor, on pourrait utiliser un groupe ou un signal si TurnManager n'a plus de méthode register_unit.
			# Supposons que l'entité Unit gère son propre enregistrement via un composant ou que 
			# le TurnManager s'abonne à GridEvents.unit_spawned. S'il y a un composant, on le laisse.
			# Pour l'instant on réutilise l'événement existant s'il n'y en a pas, on appelle get_tree().get_first_node_in_group.
			var turn_manager_node: Node = get_tree().get_first_node_in_group("turn_manager")
			if turn_manager_node and turn_manager_node.has_method("register_unit"):
				turn_manager_node.register_unit(unit)