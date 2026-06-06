class_name UnitOverlay
extends Control

@export var hp_bar: ProgressBar
@export var mana_bar: ProgressBar

@export_category("Depth Scaling")
## La distance (ou taille de caméra) où l'échelle est exactement à 100%.
@export var reference_distance: float = 15.0
## Échelle minimum (Zoom arrière max).
@export var min_scale: float = 0.5
## Échelle maximum (Zoom avant max).
@export var max_scale: float = 2.0

@export_category("Positioning")
## Hauteur en mètres au-dessus du point d'origine de l'unité (ajuster selon la taille du sprite 2D).
@export var height_offset: float = 2.5

var _target: Unit
var _camera: Camera3D
var _hp_tween: Tween
var _mana_tween: Tween
var _is_initialized: bool = false
var _health_initialized: bool = false

# Status icons
var _status_container: HBoxContainer = null
var _status_icons: Dictionary = {} # StatusEffectData -> StatusIcon

func setup(unit: Unit) -> void:
	_target = unit
	_camera = get_viewport().get_camera_3d()
	
	if hp_bar:
		# AAA : Permet aux tweens d'animer les valeurs intermédiaires au lieu de "sauter" d'entier en entier
		hp_bar.step = 0.0
		
		var fill_style := StyleBoxFlat.new()
		# AAA UX : La barre de vie reste universellement rouge pour la clarté cognitive
		fill_style.bg_color = Color(0.8, 0.15, 0.15)
		hp_bar.add_theme_stylebox_override("fill", fill_style)
		
		var bg_style := StyleBoxFlat.new()
		bg_style.bg_color = Color(0.1, 0.1, 0.1, 0.8) # Fond de la barre assombri pour le contraste
		# AAA UX : La couleur de faction est subtilement reléguée à la bordure du conteneur
		bg_style.border_width_left = 2
		bg_style.border_width_top = 2
		bg_style.border_width_right = 2
		bg_style.border_width_bottom = 2
		bg_style.border_color = Color(0.1, 0.1, 0.1) # Bordure noire/neutre
		hp_bar.add_theme_stylebox_override("background", bg_style)
		
	if mana_bar:
		mana_bar.step = 0.0
		var fill_style := StyleBoxFlat.new()
		# AAA UX : La barre de mana est bleue
		fill_style.bg_color = Color(0.15, 0.45, 0.85)
		mana_bar.add_theme_stylebox_override("fill", fill_style)
		
		var bg_style := StyleBoxFlat.new()
		bg_style.bg_color = Color(0.1, 0.1, 0.1, 0.8)
		bg_style.border_width_left = 2
		bg_style.border_width_top = 2
		bg_style.border_width_right = 2
		bg_style.border_width_bottom = 2
		bg_style.border_color = Color(0.1, 0.1, 0.1)
		mana_bar.add_theme_stylebox_override("background", bg_style)
	
	# Connexion AAA au Séquenceur Visuel (Découplage Logique/UI)
	if not CombatEvents.has_user_signal("visual_health_updated"):
		CombatEvents.add_user_signal("visual_health_updated", [
			{"name": "target", "type": TYPE_OBJECT},
			{"name": "current", "type": TYPE_INT},
			{"name": "max_hp", "type": TYPE_INT}
		])
	CombatEvents.connect("visual_health_updated", _on_visual_health_updated)

	if _target.health_component:
		if _target.health_component.has_signal("health_changed"):
			_target.health_component.connect("health_changed", _on_health_changed)
			
		# Initialisation immédiate (État de base)
		if _target.health_component.has_method("get_current_health") and _target.health_component.has_method("get_max_health"):
			_on_health_changed(_target.health_component.get_current_health(), _target.health_component.get_max_health())
			
	# AAA UX : Branchement dynamique au composant d'économie pour le Mana
	if _target.action_economy:
		if _target.action_economy.has_signal("mana_changed"):
			_target.action_economy.connect("mana_changed", _on_mana_changed)
			
		if _target.action_economy.has_method("get_current_mana") and _target.action_economy.has_method("get_max_mana"):
			_on_mana_changed(_target.action_economy.get_current_mana(), _target.action_economy.get_max_mana())
			
	# AAA : Le pivot au centre garantit que le zoom s'applique uniformément depuis le milieu de la barre
	pivot_offset = size / 2.0

	# Statuts actifs : construction du conteneur d'icônes
	_build_status_container()

	# Différer l'initialisation permet aux vraies valeurs (injectées peu après le spawn) de ne pas déclencher les Tweens.
	call_deferred("_finalize_initialization")

func _finalize_initialization() -> void:
	_is_initialized = true

func _process(_delta: float) -> void:
	if not is_instance_valid(_target) or not is_instance_valid(_camera):
		queue_free()
		return
		
	# Calcul de la projection AAA avec offset ajustable pour les sprites 2D
	var world_pos: Vector3 = _target.global_position + Vector3(0, height_offset, 0)
	
	# AAA : Si l'unité est cachée (ex: elle est morte), on cache l'overlay
	if not _target.visible or _camera.is_position_behind(world_pos):
		visible = false
	else:
		visible = true
		
		# AAA : Calcul de l'échelle par rapport à la profondeur (Depth Scaling)
		var scale_factor: float = 1.0
		if _camera.projection == Camera3D.PROJECTION_ORTHOGONAL:
			scale_factor = reference_distance / _camera.size
		else:
			var dist: float = _camera.global_position.distance_to(world_pos)
			scale_factor = reference_distance / dist
			
		scale = Vector2.ONE * clamp(scale_factor, min_scale, max_scale)
		
		# On centre le Control sur le point projeté
		position = _camera.unproject_position(world_pos) - (size / 2.0)

func _on_health_changed(current: int, max_val: int) -> void:
	if hp_bar:
		# AAA : Filtre intelligent. On SNAP instantanément UNIQUEMENT lors de l'initialisation ou d'un buff de Max HP.
		# Les dégâts purs (même max_val) sont silencieusement ignorés pour laisser le Séquenceur faire son Tween.
		if not _health_initialized or hp_bar.max_value != max_val:
			hp_bar.max_value = max_val
			hp_bar.value = current
			_health_initialized = true

func _on_visual_health_updated(target: Node3D, current: int, max_val: int) -> void:
	if target != _target: return
	
	if hp_bar:
		hp_bar.max_value = max_val
		if _hp_tween and _hp_tween.is_valid():
			_hp_tween.kill()
		# Tween AAA : Décélération cubique strictement ordonnée par le Séquenceur
		_hp_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_hp_tween.tween_property(hp_bar, "value", float(current), 0.3)

func _on_mana_changed(current: int, max_val: int) -> void:
	if mana_bar:
		mana_bar.visible = (max_val > 0)
		mana_bar.max_value = max_val
		if not _is_initialized:
			mana_bar.value = current
		else:
			if _mana_tween and _mana_tween.is_valid():
				_mana_tween.kill()
			_mana_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			_mana_tween.tween_property(mana_bar, "value", float(current), 0.3)

# ─────────────────────────────────────────────
# STATUS ICONS
# ─────────────────────────────────────────────

func _build_status_container() -> void:
	_status_container = HBoxContainer.new()
	_status_container.add_theme_constant_override("separation", 2)
	_status_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var vbox: Node = get_node_or_null("VBoxContainer")
	if vbox:
		vbox.add_child(_status_container)
	else:
		add_child(_status_container)

	if not is_instance_valid(_target) or not _target.status_receiver:
		return

	# Connexion aux signaux d'application et de suppression
	_target.status_receiver.status_applied.connect(_on_status_applied)
	_target.status_receiver.status_removed.connect(_on_status_removed)

	# Connexion pour rafraîchir les compteurs de tour en fin de tour
	TurnEvents.turn_ended.connect(_on_turn_ended)

	# Affichage des statuts déjà actifs au moment du spawn de l'overlay
	for active_s: Object in _target.status_receiver.get_active_statuses():
		_add_status_icon(active_s)

func _add_status_icon(active_status: Object) -> void:
	if not active_status or not active_status.get("data"):
		return

	# Évite les doublons (cas STACK_DURATION)
	var data: StatusEffectData = active_status.data
	if _status_icons.has(data):
		_status_icons[data].refresh_turns(active_status.remaining_turns)
		return

	var icon := StatusIcon.new()
	_status_container.add_child(icon)
	icon.setup(active_status)
	_status_icons[data] = icon

func _on_status_applied(status: StatusEffectData) -> void:
	if not is_instance_valid(_target) or not _target.status_receiver:
		return
	# Retrouve l'ActiveStatus correspondant
	for active_s: Object in _target.status_receiver.get_active_statuses():
		if active_s.data == status:
			_add_status_icon(active_s)
			return

func _on_status_removed(status: StatusEffectData) -> void:
	if _status_icons.has(status):
		_status_icons[status].queue_free()
		_status_icons.erase(status)

func _on_turn_ended(_unit: Unit) -> void:
	# Rafraîchit le compteur de tous les statuts actifs
	if not is_instance_valid(_target) or not _target.status_receiver:
		return
	for active_s: Object in _target.status_receiver.get_active_statuses():
		var data: StatusEffectData = active_s.data
		if _status_icons.has(data):
			_status_icons[data].refresh_turns(active_s.remaining_turns)
