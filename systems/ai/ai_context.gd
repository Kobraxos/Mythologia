class_name AIContext
extends RefCounted

# PUBLIC VARIABLES
## L'unité actuellement contrôlée par l'IA.
var unit: Unit
## La position actuelle (cubique) de l'unité au moment de la décision.
var current_hex: Vector3i
## Une référence statique au GridManager/Pathfinder peut être cachée ici si besoin.

# GODOT BUILT-IN FUNCTIONS
func _init(p_unit: Unit) -> void:
	unit = p_unit
	current_hex = unit.current_hex