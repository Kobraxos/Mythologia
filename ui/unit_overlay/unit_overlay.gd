class_name UnitOverlay
extends Control

@export var hp_bar: ProgressBar
@export var shield_rect: ColorRect
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
var _shield_tween: Tween
var _is_initialized: bool = false
var _health_initialized: bool = false

# Smart UI States
var _is_active_turn: bool = false
var _is_hovered: bool = false
var _is_damaged: bool = false
var _has_status_effects: bool = false
var _is_targeted: bool = false
var _is_alt_pressed: bool = false
var _visibility_tween: Tween
var _current_target_alpha: float = -1.0

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

	# Connexion au Séquenceur Visuel du Bouclier
	if not CombatEvents.has_user_signal("visual_shield_updated"):
		CombatEvents.add_user_signal("visual_shield_updated", [
			{"name": "target", "type": TYPE_OBJECT},
			{"name": "current_shield", "type": TYPE_INT},
			{"name": "max_shield", "type": TYPE_INT},
			{"name": "current_hp", "type": TYPE_INT},
			{"name": "max_hp", "type": TYPE_INT}
		])
	CombatEvents.connect("visual_shield_updated", _on_visual_shield_updated)
	
	# Abonnements Smart UI
	TurnEvents.active_unit_changed.connect(_on_active_unit_changed)
	GridEvents.hex_hovered.connect(_on_hex_hovered)
	GridEvents.timeline_portrait_hovered.connect(_on_timeline_portrait_hovered)
	
	if UIEvents.has_signal("tactical_view_toggled"):
		UIEvents.tactical_view_toggled.connect(_on_tactical_view_toggled)
		_is_alt_pressed = Input.is_action_pressed("tactical_highlight_info")
		
	if GridEvents.has_signal("aoe_targeted"):
		GridEvents.aoe_targeted.connect(_on_targeted_hexes)
	if GridEvents.has_signal("aoe_cleared"):
		GridEvents.aoe_cleared.connect(_on_targeting_cleared)
	if GridEvents.has_signal("skill_range_targeted"):
		GridEvents.skill_range_targeted.connect(_on_targeted_hexes)
	if GridEvents.has_signal("skill_range_cleared"):
		GridEvents.skill_range_cleared.connect(_on_targeting_cleared)

	# Enregistrement de l'événement Shield Break (pour VFX futurs)
	if not CombatEvents.has_user_signal("visual_shield_broken"):
		CombatEvents.add_user_signal("visual_shield_broken", [
			{"name": "target", "type": TYPE_OBJECT}
		])

	if _target.health_component:
		if _target.health_component.has_signal("health_changed"):
			_target.health_component.connect("health_changed", _on_health_changed)
		if _target.health_component.has_signal("shield_changed"):
			_target.health_component.connect("shield_changed", _on_shield_changed)
		
		# Initialisation immédiate (État de base)
		if _target.health_component.has_method("get_current_health") and _target.health_component.has_method("get_max_health"):
			_on_health_changed(_target.health_component.get_current_health(), _target.health_component.get_max_health())
		# Différer la position de ShieldRect : hp_bar.size n'est pas encore calculé à ce stade.
		if _target.health_component.get_max_shield() > 0:
			call_deferred("_deferred_init_shield")
			
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
	
	var should_show: bool = _is_active_turn or _is_hovered or _is_damaged or _has_status_effects or _is_targeted or _is_alt_pressed
	
	# AAA : Si l'unité est cachée (ex: morte) ou derrière la caméra, on cache tout instantanément
	if not _target.visible or _camera.is_position_behind(world_pos):
		modulate.a = 0.0
		visible = false
		_current_target_alpha = 0.0
	else:
		var target_alpha: float = 1.0 if should_show else 0.0
		
		if _current_target_alpha != target_alpha:
			_current_target_alpha = target_alpha
			
			if _visibility_tween and _visibility_tween.is_valid():
				_visibility_tween.kill()
				
			if target_alpha > 0.0:
				visible = true # Assure la visibilité avant de fade in
				
			_visibility_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			_visibility_tween.tween_property(self, "modulate:a", target_alpha, 0.2)
			
			if target_alpha == 0.0:
				_visibility_tween.tween_callback(func() -> void: visible = false)
		
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
	# Délègue à _update_shield_rect qui gère l'échelle totale HP+Shield et le snap initial.
	if is_instance_valid(_target) and _target.health_component:
		_update_shield_rect(
			_target.health_component.get_current_shield(),
			_target.health_component.get_max_shield(),
			current, max_val
		)
	# Ne marque l'overlay comme initialisé que si la valeur est valide.
	# Évite la race condition où l'overlay est créé avant health_component.initialize().
	if current > 0:
		_health_initialized = true

func _on_shield_changed(current_shield: int, max_shield: int) -> void:
	if not is_instance_valid(_target) or not _target.health_component:
		return
	_update_shield_rect(
		current_shield, max_shield,
		_target.health_component.get_current_health(),
		_target.health_component.get_max_health()
	)

func _on_visual_shield_updated(target: Node3D, current_shield: int, max_shield: int, current_hp: int, max_hp: int) -> void:
	if target != _target:
		return
	_update_shield_rect(current_shield, max_shield, current_hp, max_hp)

## Positionne la ShieldRect et met à jour l'échelle de la HPBar.
## L'échelle totale est max_hp + max_shield : la barre représente la survie totale de l'unité.
func _update_shield_rect(current_shield: int, max_shield: int, current_hp: int, max_hp: int) -> void:
	if not hp_bar or max_hp <= 0:
		return

	# L'échelle totale fait de la place au bouclier, même si les HP sont pleins.
	var total_max: int = max_hp + max_shield if max_shield > 0 else max_hp
	hp_bar.max_value = float(total_max)

	# Snap initial : avant le premier tween, on force la valeur correcte.
	# Guard current_hp > 0 : ignore un appel avec une valeur non-initialisée (= 0).
	if not _health_initialized and current_hp > 0:
		hp_bar.value = float(current_hp)

	if shield_rect:
		var bar_width: float = hp_bar.size.x
		if bar_width <= 0.0:
			return # Pas encore rendu — _deferred_init_shield repassera.

		var hp_ratio: float = clampf(float(current_hp) / float(total_max), 0.0, 1.0)
		var shield_ratio: float = clampf(float(current_shield) / float(total_max), 0.0, 1.0)

		shield_rect.position.x = bar_width * hp_ratio
		shield_rect.size.x = clampf(bar_width * shield_ratio, 0.0, bar_width * (1.0 - hp_ratio))
		shield_rect.size.y = hp_bar.size.y
		shield_rect.visible = (current_shield > 0 and shield_rect.size.x > 0.5)
	_is_damaged = (current_hp < max_hp) or (current_shield < max_shield)

func _deferred_init_shield() -> void:
	if not is_instance_valid(_target) or not _target.health_component:
		return
	_update_shield_rect(
		_target.health_component.get_current_shield(),
		_target.health_component.get_max_shield(),
		_target.health_component.get_current_health(),
		_target.health_component.get_max_health()
	)

func _on_visual_health_updated(target: Node3D, current: int, max_val: int) -> void:
	if target != _target: return

	if hp_bar:
		# Recalcule le total pour garder la même échelle que _update_shield_rect.
		var max_shield: int = 0
		if is_instance_valid(_target) and _target.health_component:
			max_shield = _target.health_component.get_max_shield()
		var total_max: int = max_val + max_shield if max_shield > 0 else max_val
		hp_bar.max_value = float(total_max)
		if _hp_tween and _hp_tween.is_valid():
			_hp_tween.kill()
		# Tween AAA : Décélération cubique strictement ordonnée par le Séquenceur.
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
		
	_has_status_effects = (_target.status_receiver.get_active_statuses().size() > 0)

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
	_has_status_effects = true
	# Retrouve l'ActiveStatus correspondant
	for active_s: Object in _target.status_receiver.get_active_statuses():
		if active_s.data == status:
			_add_status_icon(active_s)
			return

func _on_status_removed(status: StatusEffectData) -> void:
	if _status_icons.has(status):
		_status_icons[status].queue_free()
		_status_icons.erase(status)
	if is_instance_valid(_target) and _target.status_receiver:
		_has_status_effects = (_target.status_receiver.get_active_statuses().size() > 0)

func _on_turn_ended(_unit: Unit) -> void:
	# Rafraîchit le compteur de tous les statuts actifs
	if not is_instance_valid(_target) or not _target.status_receiver:
		return
	for active_s: Object in _target.status_receiver.get_active_statuses():
		var data: StatusEffectData = active_s.data
		if _status_icons.has(data):
			_status_icons[data].refresh_turns(active_s.remaining_turns)

# ─────────────────────────────────────────────
# SMART UI EVENTS
# ─────────────────────────────────────────────

func _on_active_unit_changed(unit: Unit) -> void:
	_is_active_turn = (unit == _target)

func _on_hex_hovered(hex_coord: Vector3i) -> void:
	if is_instance_valid(_target):
		_is_hovered = (hex_coord == _target.current_hex)

func _on_timeline_portrait_hovered(unit: Unit, is_hovered: bool) -> void:
	if unit == _target:
		_is_hovered = is_hovered

func _on_tactical_view_toggled(is_active: bool) -> void:
	_is_alt_pressed = is_active

func _on_targeted_hexes(hexes: Array[Vector3i]) -> void:
	if is_instance_valid(_target):
		_is_targeted = hexes.has(_target.current_hex)

func _on_targeting_cleared() -> void:
	_is_targeted = false
