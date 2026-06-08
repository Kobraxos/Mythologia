class_name GridStateMachine
extends RefCounted

var current_state: GridState
var states: Dictionary = {}

func register_state(name: String, state: GridState) -> void:
	states[name] = state

func change_state(name: String) -> void:
	if current_state:
		current_state.exit()
	
	if states.has(name):
		current_state = states[name]
		current_state.enter()

func handle_input(event: InputEvent) -> void:
	if current_state:
		current_state.handle_input(event)

func process_hover() -> void:
	if current_state:
		current_state.process_hover()
