class_name HighlightManager
extends Node3D

@export var highlight_prefab: PackedScene
@export var grid_generator: GridGenerator

var _pool: Array[Node3D] = []

func _ready() -> void:
	GridEvents.unit_selected.connect(_on_unit_selected)
	GridEvents.unit_deselected.connect(_on_unit_deselected)

func _on_unit_selected(_unit: Unit, reachable_hexes: Array[Vector3i]) -> void:
	_on_unit_deselected() # Réinitialise l'affichage précédent
	
	if not grid_generator or not highlight_prefab:
		push_error("HighlightManager: Dépendances manquantes.")
		return

	# Agrandissement du pool si nécessaire (Object Pooling)
	while _pool.size() < reachable_hexes.size():
		var mesh: Node3D = highlight_prefab.instantiate() as Node3D
		add_child(mesh)
		mesh.visible = false
		_pool.append(mesh)

	# Activation et positionnement des meshs requis
	for i in range(reachable_hexes.size()):
		var hex: Vector3i = reachable_hexes[i]
		var mesh: Node3D = _pool[i]
		
		var world_pos: Vector3 = HexMath.hex_to_world(hex, grid_generator.hex_size)
		world_pos.y += 0.05 # Surélévation pour éviter le Z-Fighting avec la tuile de base
		mesh.position = world_pos
		mesh.visible = true

func _on_unit_deselected() -> void:
	for mesh: Node3D in _pool:
		mesh.visible = false