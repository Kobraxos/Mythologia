class_name UnitOverlayManager
extends Control

@export var overlay_prefab: PackedScene

@export_category("Configuration")
## Couleur de la bordure par défaut si la faction n'est pas configurée.
@export var default_color: Color = Color(0.3, 0.3, 0.3) # Gris neutre
## Dictionnaire liant une faction (UnitStats.Mythology) à la couleur de la bordure de l'overlay.
@export var faction_colors: Dictionary = {}

func _ready() -> void:
	if GridEvents.has_signal("unit_spawned"):
		GridEvents.unit_spawned.connect(_on_unit_spawned)

func _on_unit_spawned(unit: Node3D) -> void:
	var tactical_unit := unit as Unit
	if not tactical_unit:
		return
		
	if not overlay_prefab:
		return
		
	var color: Color = default_color
	if "stats" in tactical_unit and tactical_unit.stats is UnitStats:
		var myth_id: int = tactical_unit.stats.mythology
		if faction_colors.has(myth_id) and faction_colors[myth_id] is Color:
			color = faction_colors[myth_id]
			
	var overlay: UnitOverlay = overlay_prefab.instantiate() as UnitOverlay
	add_child(overlay)
	overlay.setup(tactical_unit, color)