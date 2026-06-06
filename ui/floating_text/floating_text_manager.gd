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
@export var dodge_color: Color = Color(0.8, 0.8, 0.8) # Gris/Blanc neutre
## Couleur du texte d'étourdissement — Vert acide (distinctif, alerte immédiate).
@export var stun_color: Color = Color(0.9, 1.0, 0.1) # Jaune-vert électrique
@export var height_offset: float = 2.0

# PRIVATE VARIABLES
var _pool: Array[FloatingText] = []

# GODOT BUILT-IN FUNCTIONS
func _ready() -> void:
	# Création dynamique du signal AAA exclusif au Séquenceur Visuel
	if not CombatEvents.has_user_signal("visual_text_requested"):
		CombatEvents.add_user_signal("visual_text_requested", [
			{"name": "target", "type": TYPE_OBJECT}, 
			{"name": "amount", "type": TYPE_INT},
			{"name": "is_crit", "type": TYPE_BOOL},
			{"name": "is_heal", "type": TYPE_BOOL},
			{"name": "is_dodge", "type": TYPE_BOOL}
		])
	CombatEvents.connect("visual_text_requested", _on_visual_text_requested)
	TurnEvents.turn_skipped_stun.connect(_on_turn_skipped_stun)
	
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

# SIGNAL HANDLERS
func _on_visual_text_requested(target: Node3D, amount: int, is_crit: bool, is_heal: bool, is_dodge: bool) -> void:
	var color: Color = dodge_color if is_dodge else (heal_color if is_heal else (crit_color if is_crit else damage_color))
	var prefix: String = ""
	var text_val: String = ""
	
	if is_dodge:
		text_val = "Esquive"
	else:
		if is_heal: prefix = "+"
		elif is_crit: prefix = "Crit! "
		text_val = prefix + str(amount)
	
	var ft: FloatingText = _get_available_text()
	var camera: Camera3D = get_viewport().get_camera_3d()
	
	if not ft or not camera:
		return
		
	ft.animate(target, camera, text_val, color, height_offset, is_crit, is_dodge)

# SIGNAL HANDLERS (Stun)
func _on_turn_skipped_stun(unit: Unit) -> void:
	var ft: FloatingText = _get_available_text()
	var camera: Camera3D = get_viewport().get_camera_3d()
	if not ft or not camera or not is_instance_valid(unit):
		return
	# AAA : "ÉTOURDI" en grand, non-crité (pas de montant numérique)
	ft.animate(unit, camera, "ÉTOURDI", stun_color, height_offset + 0.5, false, false)