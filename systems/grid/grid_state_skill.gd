class_name GridStateSkill
extends GridState

func enter() -> void:
	var origin_hex: Vector3i = controller.selected_unit.current_hex
	var ignored_hex: Vector3i = GridController.INVALID_HEX
	
	if controller.planned_move_hex != GridController.INVALID_HEX:
		origin_hex = controller.planned_move_hex
		ignored_hex = controller.selected_unit.current_hex
		GridEvents.ghost_stance_activated.emit(controller.planned_move_hex)
	else:
		GridEvents.ghost_stance_cleared.emit()
		
	controller.valid_casting_hexes = GridTargeting.get_valid_casting_range(origin_hex, controller.targeted_skill, ignored_hex)
	GridEvents.skill_range_targeted.emit(controller.valid_casting_hexes)
	
	var previous: Vector3i = controller.hovered_hex
	controller.hovered_hex = GridController.INVALID_HEX
	_update_hover(previous)

func exit() -> void:
	GridEvents.skill_range_cleared.emit()
	GridEvents.aoe_cleared.emit()
	GridEvents.ghost_stance_cleared.emit()

func handle_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact_select"):
		_confirm_targeting()
	elif event.is_action_pressed("interact_cancel"):
		controller.change_state("default")
	elif event.is_action_pressed("tactical_end_turn"):
		controller.change_state("default")

func process_hover() -> void:
	var hex_coord: Vector3i = controller.get_hex_under_mouse()
	if hex_coord == controller.hovered_hex:
		return
	_update_hover(hex_coord)

func _update_hover(hex_coord: Vector3i) -> void:
	controller.hovered_hex = hex_coord
	GridEvents.hex_hovered.emit(controller.hovered_hex)
	
	if controller.hovered_hex == GridController.INVALID_HEX or not controller.valid_casting_hexes.has(controller.hovered_hex):
		GridEvents.aoe_cleared.emit()
		return
		
	if is_instance_valid(controller.selected_unit) and controller.targeted_skill:
		var origin: Vector3i = controller.planned_move_hex if controller.planned_move_hex != GridController.INVALID_HEX else controller.selected_unit.current_hex
		var ignored: Vector3i = controller.selected_unit.current_hex if controller.planned_move_hex != GridController.INVALID_HEX else GridController.INVALID_HEX
		var affected: Array[Vector3i] = GridTargeting.get_affected_hexes(origin, controller.hovered_hex, controller.targeted_skill, ignored)
		GridEvents.aoe_targeted.emit(affected)

func _confirm_targeting() -> void:
	if controller.hovered_hex == GridController.INVALID_HEX or not controller.valid_casting_hexes.has(controller.hovered_hex):
		return
		
	if is_instance_valid(controller.selected_unit) and controller.targeted_skill:
		if controller.planned_move_hex != GridController.INVALID_HEX:
			var path: Array[Vector3i] = GridManager.pathfinder.get_hex_path(controller.selected_unit.current_hex, controller.planned_move_hex, controller.selected_unit.stats, controller.selected_unit.faction, GridManager.unit_positions)
			controller.selected_unit.request_movement(path)
			controller.change_state("default")
			return
			
		var success: bool = controller.selected_unit.skill_caster.cast_skill(controller.targeted_skill, controller.hovered_hex)
		if success:
			controller.change_state("default")
