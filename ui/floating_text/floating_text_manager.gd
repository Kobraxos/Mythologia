class_name FloatingTextManager
extends Control

## Gestionnaire AAA de textes flottants (Object Pooling & Projection 3D -> 2D).

# EXPORTS
@export_category("Prefabs")
@export var text_prefab: PackedScene

@export_category("Configuration")
@export var pool_size: int = 20
@export var default_damage_color: Color = Color(1.0, 0.2, 0.2)
@export var fire_color: Color = Color(1.0, 0.4, 0.0)
@export var poison_color: Color = Color(0.2, 0.8, 0.2)
@export var crit_color: Color = Color(1.0, 0.8, 0.0)
@export var heal_color: Color = Color(0.2, 1.0, 0.4)
@export var shield_color: Color = Color(0.2, 0.6, 1.0) # Bleu ciel (Aegis)
@export var dodge_color: Color = Color(0.8, 0.8, 0.8) # Gris/Blanc neutre
## Couleur du texte d'étourdissement — Vert acide (distinctif, alerte immédiate).
@export var stun_color: Color = Color(0.9, 1.0, 0.1) # Jaune-vert électrique
@export var height_offset: float = 2.0

# PRIVATE VARIABLES
var _pool: Array[FloatingText] = []
## Dictionnaire pour empiler les délais par cible (Staggering AAA)
var _target_queues: Dictionary = {}

# GODOT BUILT-IN FUNCTIONS
func _ready() -> void:
	CombatEvents.visual_text_requested.connect(_on_visual_text_requested)
	TurnEvents.turn_skipped_stun.connect(_on_turn_skipped_stun)
	
	_initialize_pool()

func _process(delta: float) -> void:
	# Purge de la file d'attente (Staggering)
	for target: Node3D in _target_queues.keys():
		_target_queues[target] -= delta
		if _target_queues[target] <= 0.0:
			_target_queues.erase(target)

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

func _get_color_for_element(element: CoreEnums.Element) -> Color:
	match element:
		CoreEnums.Element.FIRE: return fire_color
		CoreEnums.Element.POISON: return poison_color
		# Par défaut on retourne la couleur standard
		_: return default_damage_color

# SIGNAL HANDLERS
func _on_visual_text_requested(target: Node3D, amount: int, type: CombatEvents.FloatingTextType, element: CoreEnums.Element) -> void:
	var color: Color
	var prefix: String = ""
	var text_val: String = ""
	var is_crit: bool = false
	var is_dodge: bool = false
	
	match type:
		CombatEvents.FloatingTextType.DODGE:
			color = dodge_color
			is_dodge = true
			text_val = "Esquive"
		CombatEvents.FloatingTextType.MISS:
			color = dodge_color
			text_val = "Raté"
		CombatEvents.FloatingTextType.IMMUNE:
			color = dodge_color
			text_val = "Immunisé"
		CombatEvents.FloatingTextType.SHIELD:
			color = shield_color
			prefix = "+Aegis "
			text_val = prefix + str(amount)
		CombatEvents.FloatingTextType.HEAL:
			color = heal_color
			prefix = "+"
			text_val = prefix + str(amount)
		CombatEvents.FloatingTextType.CRIT:
			color = crit_color
			is_crit = true
			prefix = "Crit! "
			text_val = prefix + str(amount)
		CombatEvents.FloatingTextType.DAMAGE:
			color = _get_color_for_element(element)
			text_val = str(amount)
			
	var ft: FloatingText = _get_available_text()
	var camera: Camera3D = get_viewport().get_camera_3d()
	
	if not ft or not camera or not is_instance_valid(target):
		return
		
	# Gestion du Staggering (Queueing visuel)
	var delay: float = 0.0
	if _target_queues.has(target):
		delay = _target_queues[target]
		_target_queues[target] += 0.2 # 200ms d'espacement pour chaque texte supplémentaire
	else:
		_target_queues[target] = 0.2
		
	# Lancement avec délai (Si le script FloatingText gère un delay_start ou via un petit Timer ici)
	if delay > 0.0:
		get_tree().create_timer(delay).timeout.connect(func():
			if is_instance_valid(target) and is_instance_valid(ft):
				ft.animate(target, camera, text_val, color, height_offset, is_crit, is_dodge)
		)
	else:
		ft.animate(target, camera, text_val, color, height_offset, is_crit, is_dodge)

# SIGNAL HANDLERS (Stun)
func _on_turn_skipped_stun(unit: Unit) -> void:
	var ft: FloatingText = _get_available_text()
	var camera: Camera3D = get_viewport().get_camera_3d()
	if not ft or not camera or not is_instance_valid(unit):
		return
	# AAA : "ÉTOURDI" en grand, non-crité (pas de montant numérique)
	ft.animate(unit, camera, "ÉTOURDI", stun_color, height_offset + 0.5, false, false)