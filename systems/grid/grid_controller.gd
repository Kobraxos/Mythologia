class_name GridController
extends Node

# CONSTANTS
## Masque de collision AAA : Uniquement le Terrain (Layer 1). Les unités sont ignorées par le raycast.
const TERRAIN_MASK: int = 1
const RAY_LENGTH: float = 1000.0

# EXPORTS
@export var camera: Camera3D

# PRIVATE VARIABLES
var _selected_unit: Unit = null
var _reachable_hexes: Array[Vector3i] = []

# GODOT BUILT-IN FUNCTIONS
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact_select"):
		_perform_raycast()
	elif event.is_action_pressed("tactical_end_turn"):
		TurnEvents.turn_end_requested.emit()

# PRIVATE FUNCTIONS
func _perform_raycast() -> void:
	# Mécanisme de sécurité (Lazy Loading) si les liens de l'inspecteur ont sauté
	if not camera:
		camera = get_viewport().get_camera_3d()

	if not camera:
		push_error("GridController: Référence 'camera' manquante.")
		return

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

		if not GridManager.terrain_tiles.has(hex_coord):
			return

		# Logique d'interaction contextuelle
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
			if _selected_unit:
				if _reachable_hexes.has(hex_coord):
					GridEvents.hex_clicked.emit(hex_coord)
				GridEvents.unit_deselected.emit()
				_selected_unit = null
				_reachable_hexes.clear()