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
var _active_indicator: Label3D
var _indicator_tween: Tween

# GODOT BUILT-IN FUNCTIONS
func _ready() -> void:
	GridEvents.unit_selected.connect(_on_unit_selected)
	GridEvents.unit_deselected.connect(_on_unit_deselected)
	CombatEvents.unit_died.connect(_on_unit_died_event)
	
	# Enregistrement spatial initial au lancement
	current_hex = HexMath.world_to_hex(position, GridManager.hex_size, GridManager.elevation_step)
	position = HexMath.hex_to_world(current_hex, GridManager.hex_size, GridManager.elevation_step) # Snap visuel strict
	GridManager.unit_positions[current_hex] = self
	GridEvents.unit_spawned.emit(self)
	
	# Création de l'indicateur d'unité active (Chevron flottant)
	_active_indicator = Label3D.new()
	_active_indicator.text = "▼"
	_active_indicator.font_size = 120
	_active_indicator.position = Vector3(0, 2.5, 0)
	_active_indicator.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_active_indicator.no_depth_test = true # Toujours visible par-dessus le reste
	_active_indicator.visible = false
	add_child(_active_indicator)

## Appelé par le BattleManager lors du Spawn pour injecter l'âme (les données) dans la coquille.
func initialize(new_stats: UnitStats, unit_faction: Faction = Faction.NEUTRAL) -> void:
	stats = new_stats
	faction = unit_faction
	
	if faction_ring:
		match faction:
			Faction.PLAYER:
				faction_ring.modulate = Color(0.2, 0.6, 1.0, 0.8) # Bleu Divin / Olympe
				if _active_indicator: _active_indicator.modulate = Color(0.2, 0.6, 1.0)
			Faction.ENEMY:
				faction_ring.modulate = Color(0.9, 0.1, 0.1, 0.8) # Rouge Sang / Tartare
				if _active_indicator: _active_indicator.modulate = Color(0.9, 0.1, 0.1)
			Faction.ALLY:
				faction_ring.modulate = Color(0.2, 0.8, 0.4, 0.8) # Vert Nature
				if _active_indicator: _active_indicator.modulate = Color(0.2, 0.8, 0.4)
			_:
				faction_ring.modulate = Color(0.5, 0.5, 0.5, 0.8) # Gris Neutre
				if _active_indicator: _active_indicator.modulate = Color(1.0, 1.0, 1.0)
				
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

	# Régénération HP et Aegis de base (après les DoT/HoT des statuts, avant le reset d'économie)
	if health_component:
		health_component.tick_regen()
		health_component.tick_regen_shield()
		
	if action_economy:
		action_economy.start_turn()
		
	# AAA VFX : L'anneau s'excite
	if faction_ring and faction_ring.material_override:
		var mat := faction_ring.material_override as ShaderMaterial
		var tw := create_tween().set_parallel(true).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		tw.tween_property(mat, "shader_parameter/rotation_speed", 1.5, 0.5)
		tw.tween_property(mat, "shader_parameter/pulse_intensity", 0.8, 0.5)
		
	# AAA VFX : Indicateur Actif (Chevron flottant)
	if _active_indicator:
		_active_indicator.visible = true
		_active_indicator.position.y = 2.5
		if _indicator_tween and _indicator_tween.is_valid():
			_indicator_tween.kill()
		_indicator_tween = create_tween().set_loops()
		_indicator_tween.tween_property(_active_indicator, "position:y", 2.0, 0.5).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
		_indicator_tween.tween_property(_active_indicator, "position:y", 2.5, 0.5).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)

## Appelé par le TurnManager à la fin du tour.
func end_turn() -> void:
	if action_economy:
		action_economy.end_turn()
		
	if status_receiver:
		status_receiver.tick_durations()
		
	# AAA VFX : L'anneau se calme à la fin du tour
	if faction_ring and faction_ring.material_override:
		var mat := faction_ring.material_override as ShaderMaterial
		var tw := create_tween().set_parallel(true).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
		tw.tween_property(mat, "shader_parameter/rotation_speed", 0.2, 0.5)
		tw.tween_property(mat, "shader_parameter/pulse_intensity", 0.1, 0.5)
		
	if _active_indicator:
		_active_indicator.visible = false
		if _indicator_tween and _indicator_tween.is_valid():
			_indicator_tween.kill()

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
			var prev_hex = current_hex
			current_hex = h
			GridEvents.unit_moved.emit(self, prev_hex, current_hex)
			
		_move_tween.tween_callback(update_hex.bind(step_hex))
		
	_move_tween.tween_callback(func() -> void: movement_finished.emit())

## Exécute un mouvement forcé (Knockback/Pull) instantané en logique, mais lissé visuellement.
func execute_forced_movement(final_hex: Vector3i) -> void:
	if _move_tween and _move_tween.is_valid():
		_move_tween.kill()
		
	var prev_hex: Vector3i = current_hex
	current_hex = final_hex
	
	# Cerveau : Notification immédiate pour les systèmes DOD (LoS, Pathfinding)
	GridEvents.unit_moved.emit(self, prev_hex, current_hex)
	
	# Yeux : Rattrapage visuel avec inertie (QUAD OUT simule une friction)
	var target_pos: Vector3 = HexMath.hex_to_world(final_hex, GridManager.hex_size, GridManager.elevation_step)
	_move_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_move_tween.tween_property(self, "position", target_pos, 0.25)
	_move_tween.tween_callback(func() -> void: movement_finished.emit())

# SIGNAL HANDLERS
func _on_unit_selected(unit: Unit) -> void:
	_is_selected = (unit == self)

func _on_unit_deselected() -> void:
	_is_selected = false


func _on_unit_died_event(dead_unit: Unit) -> void:
	if dead_unit == self:
		# Pratique AAA : On ne détruit pas le noeud (pas de queue_free).
		# On le cache et on le retire du registre spatial, le gardant en mémoire pour une résurrection possible.
		visible = false
		if GridManager.unit_positions.get(current_hex) == self:
			GridManager.unit_positions.erase(current_hex)
		
		# Remarque: Si on devait jouer une animation de mort (AnimationPlayer),
		# on la lancerait ici au lieu de juste faire 'visible = false'.
