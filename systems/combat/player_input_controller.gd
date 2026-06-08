class_name PlayerInputController
extends Node

## Le PlayerInputController capte les entrées globales du joueur (hors grille)
## pendant le combat, comme la touche Alt (tactical_highlight_info) pour la vue tactique.
## Il s'attache à la scène de combat et disparaît avec elle.

var is_tactical_view_active: bool = false

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action("tactical_highlight_info"):
		# Ne déclenche que si l'état change vraiment pour éviter le spam (key echo)
		if event.is_pressed() != is_tactical_view_active:
			is_tactical_view_active = event.is_pressed()
			UIEvents.tactical_view_toggled.emit(is_tactical_view_active)
