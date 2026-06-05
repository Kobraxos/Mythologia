class_name TimelineUI
extends Control

@export var portrait_scene: PackedScene
@export var separator_scene: PackedScene
@export var container: HBoxContainer

# GODOT BUILT-IN FUNCTIONS
func _ready() -> void:
	if not portrait_scene or not container or not separator_scene:
		push_error("TimelineUI: Dépendances manquantes.")
		return
		
	TurnEvents.timeline_updated.connect(_on_timeline_updated)

# SIGNAL HANDLERS
func _on_timeline_updated(queue: Array[Unit], round_breaks: Array[int]) -> void:
	# 1. AAA : On nettoie l'état précédent pour reconstruire la vue.
	# Pour une UI simple comme celle-ci, c'est plus robuste et lisible qu'un Object Pool complexe.
	for child: Node in container.get_children():
		child.queue_free()
		
	# 2. On reconstruit la timeline avec les portraits et les séparateurs
	for i: int in range(queue.size()):
		var unit: Unit = queue[i]
		var portrait: TimelinePortrait = portrait_scene.instantiate() as TimelinePortrait
		container.add_child(portrait)
		
		var is_active: bool = (i == 0)
		portrait.setup(unit, is_active)
		
		# On insère un séparateur visuel si le Domaine nous l'indique
		if round_breaks.has(i):
			var separator: Control = separator_scene.instantiate() as Control
			container.add_child(separator)