class_name Unit
extends Node3D

# EXPORTS
@export var hex_size: float = 1.0
@export var move_duration: float = 0.3
@export var stats: UnitStats

# PUBLIC VARIABLES
var current_hex: Vector3i = Vector3i.ZERO

# PRIVATE VARIABLES
var _move_tween: Tween
var _is_selected: bool = false

# GODOT BUILT-IN FUNCTIONS
func _ready() -> void:
	GridEvents.hex_clicked.connect(_on_hex_clicked)
	GridEvents.unit_selected.connect(_on_unit_selected)
	GridEvents.unit_deselected.connect(_on_unit_deselected)
	
	if not stats:
		push_error("Unit: Ressource 'stats' manquante.")
		return
		
	# Enregistrement spatial initial au lancement
	current_hex = HexMath.world_to_hex(position, hex_size)
	position = HexMath.hex_to_world(current_hex, hex_size) # Snap visuel strict
	GridManager.unit_positions[current_hex] = self

# PRIVATE FUNCTIONS
func _move_along_path(path: Array[Vector3i]) -> void:
	if _move_tween and _move_tween.is_valid():
		_move_tween.kill()
		
	# Libération immédiate pour la logique, occupation de la nouvelle case
	GridManager.unit_positions.erase(current_hex)
	var final_hex: Vector3i = path.back()
	GridManager.unit_positions[final_hex] = self
		
	_move_tween = create_tween()
	
	# L'index 0 est toujours la case de départ. On commence à l'index 1.
	for i: int in range(1, path.size()):
		var step_hex: Vector3i = path[i]
		var target_pos: Vector3 = HexMath.hex_to_world(step_hex, hex_size)
		
		# Vitesse constante (LINEAR) idéale pour enchaîner plusieurs cases
		_move_tween.tween_property(self, "position", target_pos, move_duration).set_trans(Tween.TRANS_LINEAR)
		
		# Correction AAA : Il faut lier (bind) les arguments directement sur la Callable, pas sur le Tweener
		var update_hex := func(h: Vector3i) -> void:
			current_hex = h
			
		_move_tween.tween_callback(update_hex.bind(step_hex))

# SIGNAL HANDLERS
func _on_unit_selected(unit: Unit, _reachable: Array[Vector3i]) -> void:
	_is_selected = (unit == self)

func _on_unit_deselected() -> void:
	_is_selected = false

func _on_hex_clicked(target_hex: Vector3i) -> void:
	if not _is_selected or not GridManager.pathfinder:
		return
		
	var path: Array[Vector3i] = GridManager.pathfinder.get_hex_path(current_hex, target_hex)
	if not path.is_empty():
		_move_along_path(path)
