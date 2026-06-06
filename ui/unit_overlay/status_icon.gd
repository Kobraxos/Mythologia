class_name StatusIcon
extends Control

## Widget léger représentant un statut actif sur une unité.
## Design Mythologia : Carré coloré (or divin / rouge Tartare) + compte de tours.
## Si une icône Texture2D est disponible dans StatusEffectData, elle est affichée à la place.
## Totalement autonome : se construit seul dans _ready(), configuré via setup().

# CONSTANTS
const ICON_SIZE: Vector2 = Vector2(22, 22)
const CORNER_RADIUS: int = 4

# PRIVATE VARIABLES
var _color_rect: ColorRect = null
var _texture_rect: TextureRect = null
var _turn_label: Label = null
var _status_data: StatusEffectData = null

# GODOT BUILT-IN FUNCTIONS
func _ready() -> void:
	custom_minimum_size = ICON_SIZE + Vector2(0, 0)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()

# PUBLIC API
## Configure l'icône depuis un ActiveStatus (duck-typed pour éviter la dépendance de classe interne).
func setup(active_status: Object) -> void:
	if not active_status or not active_status.get("data"):
		return

	_status_data = active_status.data
	_refresh_display(active_status.remaining_turns)

	# Tooltip mythologique
	var tip: String = _status_data.effect_name
	if _status_data.description != "":
		tip += "\n" + _status_data.description
	tooltip_text = tip

## Met à jour seulement le compteur de durée (appelé à chaque fin de tour).
func refresh_turns(remaining: int) -> void:
	if _turn_label:
		_turn_label.text = "" if remaining <= 0 or (_status_data and _status_data.duration_in_turns == 0) else str(remaining)

# PRIVATE FUNCTIONS
func _build_ui() -> void:
	# Fond coloré principal (fallback si pas d'icône)
	_color_rect = ColorRect.new()
	_color_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_color_rect.color = Color(0.3, 0.6, 0.3, 0.9) # Vert divin par défaut
	add_child(_color_rect)
	
	# Fond arrondi via clip_content + StyleBox
	_apply_rounded_style()

	# TextureRect pour icône réelle (invisible par défaut)
	_texture_rect = TextureRect.new()
	_texture_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_texture_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_texture_rect.visible = false
	add_child(_texture_rect)

	# Label de durée (coin bas-droit)
	_turn_label = Label.new()
	_turn_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_turn_label.offset_left = -14
	_turn_label.offset_top = -12
	_turn_label.add_theme_font_size_override("font_size", 9)
	_turn_label.add_theme_color_override("font_color", Color.WHITE)
	_turn_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	_turn_label.add_theme_constant_override("shadow_offset_x", 1)
	_turn_label.add_theme_constant_override("shadow_offset_y", 1)
	add_child(_turn_label)

func _apply_rounded_style() -> void:
	# Clip arrondi par un Panel invisible en dessous
	var panel := Panel.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.z_index = -1

	var style := StyleBoxFlat.new()
	style.bg_color = Color.TRANSPARENT
	style.corner_radius_top_left = CORNER_RADIUS
	style.corner_radius_top_right = CORNER_RADIUS
	style.corner_radius_bottom_left = CORNER_RADIUS
	style.corner_radius_bottom_right = CORNER_RADIUS
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(1.0, 1.0, 1.0, 0.15)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

func _refresh_display(remaining_turns: int) -> void:
	if not _status_data:
		return

	# Couleur selon le type de statut (palette Mythologia)
	var icon_color := Color(0.20, 0.70, 0.30, 0.92) # Vert Elysée (BUFF)
	match _status_data.type:
		StatusEffectData.EffectType.DEBUFF:
			icon_color = Color(0.55, 0.07, 0.12, 0.92) # Rouge Tartare (DEBUFF)
		StatusEffectData.EffectType.NEUTRAL:
			icon_color = Color(0.35, 0.35, 0.45, 0.92) # Gris Pierre Neutre
		StatusEffectData.EffectType.HIDDEN_TRIGGER:
			icon_color = Color(0.60, 0.45, 0.10, 0.92) # Bronze antique

	# Icône texturée si disponible
	if _status_data.icon and _texture_rect:
		_texture_rect.texture = _status_data.icon
		_texture_rect.visible = true
		if _color_rect:
			_color_rect.color = icon_color.darkened(0.3)
	elif _color_rect:
		_color_rect.color = icon_color

	# Durée restante
	refresh_turns(remaining_turns)
