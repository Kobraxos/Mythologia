class_name Unit
extends Node3D

# EXPORTS
@export var move_duration: float = 0.3
@export var stats: UnitStats
## Référence au gestionnaire central des statistiques.
@export var stat_manager: StatManagerComponent
## Référence au composant d'économie (Portefeuille de PA/PM).
@export var action_economy: ActionEconomyComponent
## Référence au composant de vie.
@export var health_component: HealthComponent
## Référence au composant de lancement de compétences.
@export var skill_caster: SkillCasterComponent
## Référence au gestionnaire des statuts.
@export var status_receiver: StatusReceiverComponent

# PUBLIC VARIABLES
var current_hex: Vector3i = Vector3i.ZERO

# PRIVATE VARIABLES
var _move_tween: Tween
var _is_selected: bool = false

# GODOT BUILT-IN FUNCTIONS
func _ready() -> void:
	GridEvents.hex_clicked.connect(_on_hex_clicked)
	GridEvents.unit_selected.connect(_on_unit_selected)
	GridEvents.unit_deselected.connect(_on_unit_deselected)
	
	# Enregistrement spatial initial au lancement
	current_hex = HexMath.world_to_hex(position, GridManager.hex_size, GridManager.elevation_step)
	position = HexMath.hex_to_world(current_hex, GridManager.hex_size, GridManager.elevation_step) # Snap visuel strict
	GridManager.unit_positions[current_hex] = self

## Appelé par le BattleManager lors du Spawn pour injecter l'âme (les données) dans la coquille.
func initialize(new_stats: UnitStats) -> void:
	stats = new_stats
	if stat_manager:
		stat_manager.initialize(stats)
	if action_economy:
		action_economy.initialize()
	if health_component:
		health_component.initialize(stats)

## Appelé par le TurnManager. L'unité délègue la gestion temporelle à ses organes (SRP).
func start_turn() -> void:
	if skill_caster:
		skill_caster.tick_cooldowns()
	
	if status_receiver:
		status_receiver.apply_start_turn_effects()
		
	if action_economy:
		action_economy.start_turn()

## Appelé par le TurnManager à la fin du tour.
func end_turn() -> void:
	if action_economy:
		action_economy.end_turn()
		
	if status_receiver:
		status_receiver.tick_durations()

# PRIVATE FUNCTIONS
func _move_along_path(path: Array[Vector3i]) -> void:
	if _move_tween and _move_tween.is_valid():
		_move_tween.kill()
		
	# Libération immédiate pour la logique, occupation de la nouvelle case
	GridManager.unit_positions.erase(current_hex)
	var final_hex: Vector3i = path.back()
	GridManager.unit_positions[final_hex] = self
		
	_move_tween = create_tween()
	
	# L'index 0 est toujours la case de départ. On commence à l'index 1.
	for i: int in range(1, path.size()):
		var step_hex: Vector3i = path[i]
		var target_pos: Vector3 = HexMath.hex_to_world(step_hex, GridManager.hex_size, GridManager.elevation_step)
		
		# Vitesse constante (LINEAR) idéale pour enchaîner plusieurs cases
		_move_tween.tween_property(self, "position", target_pos, move_duration).set_trans(Tween.TRANS_LINEAR)
		
		# Correction AAA : Il faut lier (bind) les arguments directement sur la Callable, pas sur le Tweener
		var update_hex := func(h: Vector3i) -> void:
			current_hex = h
			
		_move_tween.tween_callback(update_hex.bind(step_hex))

# SIGNAL HANDLERS
func _on_unit_selected(unit: Unit, _reachable: Array[Vector3i]) -> void:
	_is_selected = (unit == self)

func _on_unit_deselected() -> void:
	_is_selected = false

func _on_hex_clicked(target_hex: Vector3i) -> void:
	if not _is_selected or not GridManager.pathfinder:
		return
		
	var path: Array[Vector3i] = GridManager.pathfinder.get_hex_path(current_hex, target_hex, stats)
	if path.is_empty():
		return

	if action_economy:
		var path_cost: int = GridManager.pathfinder.get_path_cost(path, stats)
		if not action_economy.has_enough_mp(path_cost):
			return # Mouvement annulé : Fonds insuffisants.
		action_economy.consume_mp(path_cost)

	_move_along_path(path)
