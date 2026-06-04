class_name GridController
extends Node

# CONSTANTS
## Masque de collision AAA : Uniquement le Terrain (Layer 1). Les unités sont ignorées par le raycast.
const TERRAIN_MASK: int = 1
const RAY_LENGTH: float = 1000.0
## Valeur mathématique représentant l'absence de tuile (le vide absolu).
const INVALID_HEX: Vector3i = Vector3i(0, 0, -999)

# ENUMS
enum State { DEFAULT, TARGETING }

# EXPORTS
@export var camera: Camera3D

# PRIVATE VARIABLES
var _state: State = State.DEFAULT
var _targeted_skill: SkillData
var _hovered_hex: Vector3i = INVALID_HEX
var _selected_unit: Unit = null
var _reachable_hexes: Array[Vector3i] = []

# GODOT BUILT-IN FUNCTIONS
func _ready() -> void:
	CombatEvents.skill_button_clicked.connect(_on_skill_button_clicked)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if _state == State.TARGETING:
			_process_hover()
	elif event.is_action_pressed("interact_select"):
		if _state == State.TARGETING:
			_confirm_targeting()
		else:
			_perform_raycast()
	elif event.is_action_pressed("interact_cancel"):
		if _state == State.TARGETING:
			cancel_targeting()
		else:
			_clear_selection()
	elif event.is_action_pressed("tactical_end_turn"):
		TurnEvents.turn_end_requested.emit()

# PUBLIC FUNCTIONS
## Annule la préparation du sort et nettoie l'écran.
func cancel_targeting() -> void:
	_targeted_skill = null
	_state = State.DEFAULT
	_hovered_hex = INVALID_HEX
	GridEvents.aoe_cleared.emit()

# PRIVATE FUNCTIONS
func _get_hex_under_mouse() -> Vector3i:
	if not camera:
		camera = get_viewport().get_camera_3d()

	if not camera:
		return INVALID_HEX

	var space_state: PhysicsDirectSpaceState3D = camera.get_world_3d().direct_space_state
	var mouse_pos: Vector2 = get_viewport().get_mouse_position()

	var origin: Vector3 = camera.project_ray_origin(mouse_pos)
	var normal: Vector3 = camera.project_ray_normal(mouse_pos)
	var end: Vector3 = origin + normal * RAY_LENGTH

	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(origin, end)
	query.collision_mask = TERRAIN_MASK

	var result: Dictionary = space_state.intersect_ray(query)

	if result and result.has("position"):
		var world_pos: Vector3 = result["position"] as Vector3
		var hex_coord: Vector3i = HexMath.world_to_hex(world_pos, GridManager.hex_size, GridManager.elevation_step)

		if GridManager.terrain_tiles.has(hex_coord):
			return hex_coord
			
	return INVALID_HEX

func _process_hover() -> void:
	var hex_coord: Vector3i = _get_hex_under_mouse()
	
	# Ne recalculer les maths complexes que si la souris a changé de case hexagonale
	if hex_coord == _hovered_hex:
		return
		
	_hovered_hex = hex_coord
	
	if _hovered_hex == INVALID_HEX:
		GridEvents.aoe_cleared.emit()
		return
		
	if is_instance_valid(_selected_unit) and _targeted_skill:
		var affected: Array[Vector3i] = HexAoE.get_affected_hexes(_selected_unit.current_hex, _hovered_hex, _targeted_skill)
		GridEvents.aoe_targeted.emit(affected)

func _confirm_targeting() -> void:
	if _hovered_hex == INVALID_HEX:
		return
		
	if is_instance_valid(_selected_unit) and _targeted_skill:
		var success: bool = _selected_unit.skill_caster.cast_skill(_targeted_skill, _hovered_hex)
		if success:
			cancel_targeting()

func _perform_raycast() -> void:
	var hex_coord: Vector3i = _get_hex_under_mouse()
	if hex_coord == INVALID_HEX:
		return
		
	# Logique d'interaction contextuelle (Déplacement et Sélection)
	if GridManager.unit_positions.has(hex_coord):
		var unit: Unit = GridManager.unit_positions[hex_coord]
		if not unit.stats:
			push_error("GridController: L'unité sélectionnée n'a pas de stats.")
			return
		
		_selected_unit = unit
		
		var available_mp: int = unit.stats.movement_points
		if unit.action_economy:
			available_mp = unit.action_economy.get_current_mp()
			
		_reachable_hexes = GridManager.pathfinder.get_reachable_hexes(hex_coord, unit.stats, available_mp)
		GridEvents.unit_selected.emit(unit, _reachable_hexes)
	else:
		if is_instance_valid(_selected_unit):
			if _reachable_hexes.has(hex_coord):
				GridEvents.hex_clicked.emit(hex_coord)
		_clear_selection()

func _clear_selection() -> void:
	GridEvents.unit_deselected.emit()
	_selected_unit = null
	_reachable_hexes.clear()

# SIGNAL HANDLERS
func _on_skill_button_clicked(skill: SkillData) -> void:
	if not is_instance_valid(_selected_unit) or not _selected_unit.skill_caster:
		return
		
	_targeted_skill = skill
	_state = State.TARGETING
	_process_hover() # Force un premier dessin de l'AoE immédiatement