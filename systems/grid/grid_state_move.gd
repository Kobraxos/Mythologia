class_name GridStateMove
extends GridState

func enter() -> void:
	GridEvents.movement_targeted.emit(controller.reachable_hexes)

func exit() -> void:
	GridEvents.movement_path_cleared.emit()
	GridEvents.movement_cleared.emit()

func handle_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact_select"):
		_confirm_movement()
	elif event.is_action_pressed("interact_cancel"):
		controller.change_state("default")
	elif event.is_action_pressed("tactical_end_turn"):
		controller.change_state("default")

func process_hover() -> void:
	var hex_coord: Vector3i = controller.get_hex_under_mouse()
	if hex_coord == controller.hovered_hex:
		return
		
	controller.hovered_hex = hex_coord
	GridEvents.hex_hovered.emit(controller.hovered_hex)
	
	if controller.hovered_hex == GridController.INVALID_HEX or not controller.reachable_hexes.has(controller.hovered_hex):
		GridEvents.movement_path_cleared.emit()
		return
		
	if is_instance_valid(controller.selected_unit) and GridManager.pathfinder:
		var path: Array[Vector3i] = GridManager.pathfinder.get_hex_path(controller.selected_unit.current_hex, controller.hovered_hex, controller.selected_unit.stats, controller.selected_unit.faction, GridManager.unit_positions)
		GridEvents.movement_path_targeted.emit(path)

func _confirm_movement() -> void:
	var hex_coord: Vector3i = controller.get_hex_under_mouse()
	if hex_coord == GridController.INVALID_HEX:
		return
		
	if is_instance_valid(controller.selected_unit) and controller.reachable_hexes.has(hex_coord):
		var path: Array[Vector3i] = GridManager.pathfinder.get_hex_path(controller.selected_unit.current_hex, hex_coord, controller.selected_unit.stats, controller.selected_unit.faction, GridManager.unit_positions)
		if path.is_empty():
			return
		
		var success: bool = controller.selected_unit.request_movement(path)
		if success:
			controller.change_state("default")
