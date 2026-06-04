class_name FloatingTextManager
extends Control

## Gestionnaire AAA de textes flottants (Object Pooling & Projection 3D -> 2D).

# EXPORTS
@export_category("Prefabs")
@export var text_prefab: PackedScene

@export_category("Configuration")
@export var pool_size: int = 20
@export var damage_color: Color = Color(1.0, 0.2, 0.2)
@export var crit_color: Color = Color(1.0, 0.8, 0.0)
@export var heal_color: Color = Color(0.2, 1.0, 0.4)
@export var height_offset: float = 2.0

# PRIVATE VARIABLES
var _pool: Array[FloatingText] = []

# GODOT BUILT-IN FUNCTIONS
func _ready() -> void:
	CombatEvents.damage_dealt.connect(_on_damage_dealt)
	CombatEvents.healing_done.connect(_on_healing_done)
	_initialize_pool()

# PRIVATE FUNCTIONS
func _initialize_pool() -> void:
	if not text_prefab:
		push_error("FloatingTextManager: 'text_prefab' manquant.")
		return
		
	for i: int in range(pool_size):
		var ft: FloatingText = text_prefab.instantiate() as FloatingText
		add_child(ft)
		ft.visible = false
		_pool.append(ft)

func _get_available_text() -> FloatingText:
	for ft: FloatingText in _pool:
		if not ft.visible:
			return ft
	return null # Object Pool plein (Optionnel : Agrandir le pool dynamiquement)

func _spawn_text(target: Node3D, text_val: String, color: Color) -> void:
	var ft: FloatingText = _get_available_text()
	var camera: Camera3D = get_viewport().get_camera_3d()
	
	if not ft or not camera:
		return
		
	# Projection 3D vers 2D
	var world_pos: Vector3 = target.global_position + Vector3(0, height_offset, 0)
	if camera.is_position_behind(world_pos):
		return
		
	var screen_pos: Vector2 = camera.unproject_position(world_pos)
	ft.animate(screen_pos, text_val, color)

# SIGNAL HANDLERS
func _on_damage_dealt(target: Node3D, amount: int, is_crit: bool) -> void:
	var color: Color = crit_color if is_crit else damage_color
	var prefix: String = "Crit! " if is_crit else ""
	_spawn_text(target, prefix + str(amount), color)

func _on_healing_done(target: Node3D, amount: int) -> void:
	_spawn_text(target, "+" + str(amount), heal_color)