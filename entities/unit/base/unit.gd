class_name Unit
extends Node3D

# SIGNALS
signal movement_finished()

# ENUMS
enum Faction { PLAYER, ENEMY, ALLY, NEUTRAL }

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
var faction: Faction = Faction.NEUTRAL

@onready var faction_ring: Sprite3D = $FactionRing

# PRIVATE VARIABLES
var _move_tween: Tween
var _is_selected: bool = false

# GODOT BUILT-IN FUNCTIONS
func _ready() -> void:
	GridEvents.hex_clicked.connect(_on_hex_clicked)
	GridEvents.unit_selected.connect(_on_unit_selected)
	GridEvents.unit_deselected.connect(_on_unit_deselected)
	CombatEvents.unit_died.connect(_on_unit_died_event)
	
	# Enregistrement spatial initial au lancement
	current_hex = HexMath.world_to_hex(position, GridManager.hex_size, GridManager.elevation_step)
	position = HexMath.hex_to_world(current_hex, GridManager.hex_size, GridManager.elevation_step) # Snap visuel strict
	GridManager.unit_positions[current_hex] = self
	GridEvents.unit_spawned.emit(self)

## Appelé par le BattleManager lors du Spawn pour injecter l'âme (les données) dans la coquille.
func initialize(new_stats: UnitStats, unit_faction: Faction = Faction.NEUTRAL) -> void:
	stats = new_stats
	faction = unit_faction
	
	if faction_ring:
		match faction:
			Faction.PLAYER:
				faction_ring.modulate = Color(0.2, 0.6, 1.0, 0.8) # Bleu Divin / Olympe
			Faction.ENEMY:
				faction_ring.modulate = Color(0.9, 0.1, 0.1, 0.8) # Rouge Sang / Tartare
			Faction.ALLY:
				faction_ring.modulate = Color(0.2, 0.8, 0.4, 0.8) # Vert Nature
			_:
				faction_ring.modulate = Color(0.5, 0.5, 0.5, 0.8) # Gris Neutre
				
	if stat_manager:
		stat_manager.initialize(stats)
	if action_economy:
		action_economy.initialize()
	if health_component:
		health_component.initialize(stats)
		
	if skill_caster and "active_skills" in stats:
		var skills: Array[SkillData] = []
		for res: Resource in stats.get("active_skills"):
			if res is SkillData:
				skills.append(res as SkillData)
		skill_caster.initialize(skills)

## Appelé par le TurnManager. L'unité délègue la gestion temporelle à ses organes (SRP).
func start_turn() -> void:
	if skill_caster:
		skill_caster.tick_cooldowns()
	
	if status_receiver:
		status_receiver.apply_start_turn_effects()
		
	if action_economy:
		action_economy.start_turn()
		
	# AAA VFX : L'anneau s'excite quand c'est le tour de l'unité
	if faction_ring and faction_ring.material_override:
		var mat := faction_ring.material_override as ShaderMaterial
		var tw := create_tween().set_parallel(true)
		tw.tween_property(mat, "shader_parameter/rotation_speed", 0.8, 0.5)
		tw.tween_property(mat, "shader_parameter/pulse_intensity", 0.4, 0.5)

## Appelé par le TurnManager à la fin du tour.
func end_turn() -> void:
	if action_economy:
		action_economy.end_turn()
		
	if status_receiver:
		status_receiver.tick_durations()
		
	# AAA VFX : L'anneau se calme à la fin du tour
	if faction_ring and faction_ring.material_override:
		var mat := faction_ring.material_override as ShaderMaterial
		var tw := create_tween().set_parallel(true)
		tw.tween_property(mat, "shader_parameter/rotation_speed", 0.2, 0.5)
		tw.tween_property(mat, "shader_parameter/pulse_intensity", 0.1, 0.5)

# PUBLIC FUNCTIONS
## Exécute un chemin de déplacement donné. (Appelé par les Contrôleurs : Joueur ou IA)
func execute_path(path: Array[Vector3i]) -> void:
	if path.size() <= 1:
		movement_finished.emit()
		return
		
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
		
	_move_tween.tween_callback(func() -> void: movement_finished.emit())

# SIGNAL HANDLERS
func _on_unit_selected(unit: Unit) -> void:
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

	execute_path(path)

func _on_unit_died_event(dead_unit: Unit) -> void:
	if dead_unit == self:
		# Pratique AAA : On ne détruit pas le noeud (pas de queue_free).
		# On le cache et on le retire du registre spatial, le gardant en mémoire pour une résurrection possible.
		visible = false
		if GridManager.unit_positions.get(current_hex) == self:
			GridManager.unit_positions.erase(current_hex)
		
		# Remarque: Si on devait jouer une animation de mort (AnimationPlayer),
		# on la lancerait ici au lieu de juste faire 'visible = false'.
