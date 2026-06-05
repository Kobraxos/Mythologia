class_name UnitOverlayManager
extends Control

@export var overlay_prefab: PackedScene

func _ready() -> void:
	if GridEvents.has_signal("unit_spawned"):
		GridEvents.unit_spawned.connect(_on_unit_spawned)

func _on_unit_spawned(unit: Node3D) -> void:
	var tactical_unit := unit as Unit
	if not tactical_unit:
		return
		
	if not overlay_prefab:
		return
		
	var overlay: UnitOverlay = overlay_prefab.instantiate() as UnitOverlay
	add_child(overlay)
	overlay.setup(tactical_unit)
