class_name GridState
extends RefCounted

var controller: GridController

func setup(p_controller: GridController) -> void:
	controller = p_controller

func enter() -> void:
	pass

func exit() -> void:
	pass

func handle_input(_event: InputEvent) -> void:
	pass

func process_hover() -> void:
	pass
