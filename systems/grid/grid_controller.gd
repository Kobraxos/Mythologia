class_name GridController
extends Node

# CONSTANTS
const INVALID_HEX: Vector3i = Vector3i(0, 0, -999)

# EXPORTS
@export var camera: Camera3D

# PUBLIC VARIABLES (Context partagé pour la FSM)
var hovered_hex: Vector3i = INVALID_HEX
var selected_unit: Unit = null
var reachable_hexes: Array[Vector3i] = []
var valid_casting_hexes: Array[Vector3i] = []
var planned_move_hex: Vector3i = INVALID_HEX
var targeted_skill: SkillData
var active_turn_unit: Unit = null

# PRIVATE VARIABLES
var _state_machine: GridStateMachine

# GODOT BUILT-IN FUNCTIONS
func _ready() -> void:
	CombatEvents.skill_button_clicked.connect(_on_skill_button_clicked)
	CombatEvents.move_button_clicked.connect(request_move_state)
	TurnEvents.active_unit_changed.connect(_on_active_unit_changed)
	
	_state_machine = GridStateMachine.new()
	var default_state = GridStateDefault.new()
	default_state.setup(self)
	_state_machine.register_state("default", default_state)
	
	var move_state = GridStateMove.new()
	move_state.setup(self)
	_state_machine.register_state("move", move_state)
	
	var skill_state = GridStateSkill.new()
	skill_state.setup(self)
	_state_machine.register_state("skill", skill_state)
	
	_state_machine.change_state("default")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_state_machine.process_hover()
	else:
		_state_machine.handle_input(event)

# PUBLIC FUNCTIONS (State Machine API & Utilitaires)
func change_state(state_name: String) -> void:
	_state_machine.change_state(state_name)

func get_hex_under_mouse() -> Vector3i:
	if not camera:
		camera = get_viewport().get_camera_3d()

	if not camera:
		return INVALID_HEX

	var mouse_pos: Vector2 = get_viewport().get_mouse_position()

	var origin: Vector3 = camera.project_ray_origin(mouse_pos)
	var normal: Vector3 = camera.project_ray_normal(mouse_pos)

	for z: int in range(GridManager.max_elevation, -1, -1):
		var plane_height: float = z * GridManager.elevation_step
		var plane: Plane = Plane(Vector3.UP, plane_height)
		var hit_pos = plane.intersects_ray(origin, normal)
		
		# Typage strict pour éviter la Variant implicite
		if typeof(hit_pos) == TYPE_VECTOR3:
			var hit_vec3 := hit_pos as Vector3
			var hex_coord: Vector3i = HexMath.world_to_hex(hit_vec3, GridManager.hex_size, GridManager.elevation_step)
			for test_z: int in range(hex_coord.z, GridManager.max_elevation + 1):
				var check_hex: Vector3i = Vector3i(hex_coord.x, hex_coord.y, test_z)
				if GridManager.terrain_tiles.has(check_hex):
					return check_hex
			
	return INVALID_HEX

func perform_raycast() -> void:
	var hex_coord: Vector3i = get_hex_under_mouse()
	if hex_coord == INVALID_HEX:
		return
		
	if GridManager.unit_positions.has(hex_coord):
		var unit: Unit = GridManager.unit_positions[hex_coord]
		if not unit.stats:
			push_error("GridController: L'unité sélectionnée n'a pas de stats.")
			return
		
		selected_unit = unit
		GridEvents.unit_selected.emit(unit)
	else:
		clear_selection()

func clear_selection() -> void:
	GridEvents.unit_deselected.emit()
	selected_unit = null
	reachable_hexes.clear()

func request_move_state() -> void:
	if not is_instance_valid(selected_unit) or not selected_unit.stats:
		return

	if selected_unit.faction != Unit.Faction.PLAYER or selected_unit != active_turn_unit:
		return

	if not selected_unit.can_move():
		return

	var available_mp: int = selected_unit.stats.movement_points
	if selected_unit.action_economy:
		available_mp = selected_unit.action_economy.get_current_mp()
		
	if available_mp <= 0:
		return
		
	reachable_hexes = GridManager.pathfinder.get_reachable_hexes(selected_unit.current_hex, selected_unit.stats, available_mp, selected_unit.faction, GridManager.unit_positions)
	
	change_state("move")

# SIGNAL HANDLERS
func _on_skill_button_clicked(skill: SkillData) -> void:
	if not is_instance_valid(selected_unit) or not selected_unit.skill_caster:
		return

	if selected_unit.faction != Unit.Faction.PLAYER or selected_unit != active_turn_unit:
		return

	if not selected_unit.can_cast_skill():
		return

	targeted_skill = skill
	
	if _state_machine.current_state is GridStateMove and hovered_hex != INVALID_HEX and reachable_hexes.has(hovered_hex):
		planned_move_hex = hovered_hex
	else:
		planned_move_hex = INVALID_HEX
		
	change_state("skill")

func _on_active_unit_changed(unit: Unit) -> void:
	# AAA: Annuler immédiatement toute action en cours (FSM) pour nettoyer les zones ciblées
	change_state("default")
	
	active_turn_unit = unit
	if is_instance_valid(unit):
		selected_unit = unit
		GridEvents.unit_selected.emit(unit)