class_name SurfaceVisuals
extends Node3D

## Registre des instances 3D des surfaces. Clé: Vector3i, Valeur: Node3D
var active_visuals: Dictionary[Vector3i, Node3D] = {}

func _ready() -> void:
	GridEvents.surface_spawned.connect(_on_surface_spawned)
	GridEvents.surface_removed.connect(_on_surface_removed)

func _on_surface_spawned(hex: Vector3i, surface_data: Resource) -> void: # surface_data is TerrainData
	# Nettoie le précédent visuel s'il y en a un
	if active_visuals.has(hex):
		_on_surface_removed(hex)
		
	if surface_data and surface_data.get("visual_prefab"):
		var prefab = surface_data.get("visual_prefab") as PackedScene
		if prefab:
			var visual_instance: Node3D = prefab.instantiate() as Node3D
			if visual_instance:
				add_child(visual_instance)
				visual_instance.global_position = HexMath.hex_to_world(hex, GridManager.hex_size, GridManager.elevation_step)
				active_visuals[hex] = visual_instance

func _on_surface_removed(hex: Vector3i) -> void:
	if active_visuals.has(hex):
		var visual: Node3D = active_visuals[hex]
		if is_instance_valid(visual):
			visual.queue_free()
		active_visuals.erase(hex)
