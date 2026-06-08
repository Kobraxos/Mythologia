class_name GridStateDefault
extends GridState

func enter() -> void:
	controller.hovered_hex = GridController.INVALID_HEX
	controller.reachable_hexes.clear()
	controller.valid_casting_hexes.clear()
	controller.targeted_skill = null
	controller.planned_move_hex = GridController.INVALID_HEX

func handle_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact_select"):
		controller.perform_raycast()
	elif event.is_action_pressed("interact_cancel"):
		controller.clear_selection()
	elif event.is_action_pressed("tactical_end_turn"):
		if is_instance_valid(controller.active_turn_unit) and controller.active_turn_unit.faction == Unit.Faction.PLAYER:
			TurnEvents.turn_end_requested.emit()
	elif event.is_action_pressed("tactical_move"):
		controller.request_move_state()

func process_hover() -> void:
	var hex_coord: Vector3i = controller.get_hex_under_mouse()
	if hex_coord == controller.hovered_hex:
		return
		
	controller.hovered_hex = hex_coord
	GridEvents.hex_hovered.emit(controller.hovered_hex)
