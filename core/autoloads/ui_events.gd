extends Node

@warning_ignore("unused_signal")
## Émis lorsque le joueur maintient ou relâche la touche de vue tactique (Alt).
signal tactical_view_toggled(is_active: bool)

var is_tactical_view_active: bool = false

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.keycode == KEY_ALT or event.keycode == KEY_MENU:
			# Evite les répétitions d'événements (key echo)
			if event.pressed != is_tactical_view_active:
				is_tactical_view_active = event.pressed
				tactical_view_toggled.emit(is_tactical_view_active)
