class_name HighlightManager
extends Node3D

# CONSTANTS
## Décalage vertical pour empêcher le Z-Fighting (clignotement) avec la tuile de sol.
const Z_FIGHTING_OFFSET: float = 0.05

# EXPORTS
@export_category("Prefabs")
## Le modèle 3D affiché pour les cases de déplacement accessibles (ex: Vert).
@export var move_highlight_prefab: PackedScene
## Le modèle 3D affiché pour les cases affectées par une compétence (ex: Rouge).
@export var attack_highlight_prefab: PackedScene

# PRIVATE VARIABLES
var _move_pool: Array[Node3D] = []
var _attack_pool: Array[Node3D] = []

# GODOT BUILT-IN FUNCTIONS
func _ready() -> void:
	GridEvents.unit_deselected.connect(_on_unit_deselected)
	
	if GridEvents.has_signal("movement_targeted"):
		GridEvents.movement_targeted.connect(_on_movement_targeted)
	if GridEvents.has_signal("movement_cleared"):
		GridEvents.movement_cleared.connect(_on_movement_cleared)
		
	# AAA Fix : has_user_signal ne détecte que les signaux dynamiques. has_signal détecte les signaux déclarés.
	if GridEvents.has_signal("aoe_targeted"):
		GridEvents.aoe_targeted.connect(_on_aoe_targeted)
	if GridEvents.has_signal("aoe_cleared"):
		GridEvents.aoe_cleared.connect(_on_aoe_cleared)

# SIGNAL HANDLERS
func _on_movement_targeted(reachable_hexes: Array[Vector3i]) -> void:
	_on_movement_cleared()
	if not move_highlight_prefab:
		push_error("HighlightManager: 'move_highlight_prefab' manquant.")
		return
		
	_display_hexes(reachable_hexes, _move_pool, move_highlight_prefab)

func _on_movement_cleared() -> void:
	_hide_pool(_move_pool)

func _on_unit_deselected() -> void:
	_on_movement_cleared()
	_on_aoe_cleared()

func _on_aoe_targeted(hexes: Array[Vector3i]) -> void:
	_on_aoe_cleared()
	
	if not attack_highlight_prefab:
		push_error("HighlightManager: 'attack_highlight_prefab' manquant.")
		return
		
	_display_hexes(hexes, _attack_pool, attack_highlight_prefab)

func _on_aoe_cleared() -> void:
	_hide_pool(_attack_pool)

# PRIVATE FUNCTIONS
func _display_hexes(hexes: Array[Vector3i], pool: Array[Node3D], prefab: PackedScene) -> void:
	while pool.size() < hexes.size():
		var mesh: Node3D = prefab.instantiate() as Node3D
		add_child(mesh)
		mesh.visible = false
		pool.append(mesh)

	for i in range(hexes.size()):
		var hex: Vector3i = hexes[i]
		var mesh: Node3D = pool[i]
		
		var world_pos: Vector3 = HexMath.hex_to_world(hex, GridManager.hex_size, GridManager.elevation_step)
		world_pos.y += Z_FIGHTING_OFFSET 
		mesh.position = world_pos
		mesh.visible = true

func _hide_pool(pool: Array[Node3D]) -> void:
	for mesh: Node3D in pool:
		if is_instance_valid(mesh):
			mesh.visible = false