class_name ResourcePipBar
extends HBoxContainer

## Widget UI générique affichant une ressource sous forme de "pips" mythologiques.
## Chaque pip représente une unité de faveur divine (PA) ou d'élan céleste (PM).
## AAA Pattern : Totalement découplé, piloté uniquement par les méthodes publiques.
## Réutilisable pour PA, PM, ou toute autre ressource discrète.

# CONSTANTS
## Durée de l'animation pour chaque pip (en secondes).
const PIP_TWEEN_DURATION: float = 0.15
## Délai en cascade entre chaque pip (effet de vague divine).
const PIP_STAGGER_DELAY: float = 0.055
## Taille de l'aura divine sur un pip plein.
const DIVINE_GLOW_SIZE: int = 6
## Décalage vertical de l'aura (effet de lumière venant du dessus).
const DIVINE_GLOW_OFFSET: Vector2 = Vector2(0, -1)

# EXPORTS
@export_group("Apparence Divine")
## Couleur des pips pleins — Faveur des Dieux (or olympien pour PA, argent-cyan pour PM).
@export var color_full: Color = Color(1.0, 0.80, 0.15, 1.0) # Or Divin par défaut
## Couleur des pips vides — Pierre antique érodée.
@export var color_empty: Color = Color(0.10, 0.09, 0.13, 0.92)
## Couleur du label de titre.
@export var label_color: Color = Color(0.95, 0.78, 0.25, 1.0) # Reflet doré
## Texte du label (ex: "⚡" pour PA, "☄" pour PM).
@export var label_text: String = "⚡"
## Taille des pips — forme étirée verticalement (style bouclier / médaillon antique).
@export var pip_size: Vector2 = Vector2(14, 20)
## Espacement entre les pips.
@export var pip_gap: int = 4
## Arrondi des coins — valeur haute = forme ovoide (médaillon), basse = losange.
@export var pip_corner_radius: int = 5

# PRIVATE VARIABLES
var _current_value: int = 0
var _max_value: int = 0
var _pips: Array[Panel] = []
var _tweens: Array[Tween] = []
var _label_node: Label = null
var _pip_container: HBoxContainer = null

# GODOT BUILT-IN FUNCTIONS
func _ready() -> void:
	_build_widget()

# PUBLIC API
## Initialise la barre avec ses valeurs max et courantes (sans animation).
func initialize(current: int, max_val: int) -> void:
	_max_value = max(0, max_val)
	_current_value = clampi(current, 0, _max_value)
	_rebuild_pips()
	_refresh_pips_instant()

## Met à jour la valeur courante avec une animation en vague.
func set_value(current: int, max_val: int) -> void:
	var new_max: int = max(0, max_val)
	var new_current: int = clampi(current, 0, new_max)

	# Reconstruction des pips seulement si le maximum change
	if new_max != _max_value:
		_max_value = new_max
		_current_value = new_current
		_rebuild_pips()
		_refresh_pips_instant()
		return

	var old_current: int = _current_value
	_current_value = new_current
	_animate_pips(old_current, new_current)

# PRIVATE FUNCTIONS
func _build_widget() -> void:
	# Conteneur principal : label divin + pips côte à côte
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", 8)

	# Label de titre avec style mythologique
	_label_node = Label.new()
	_label_node.text = label_text
	_label_node.add_theme_color_override("font_color", label_color)
	_label_node.add_theme_font_size_override("font_size", 16)
	_label_node.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label_node.custom_minimum_size = Vector2(20, 0)
	add_child(_label_node)

	# Conteneur des pips
	_pip_container = HBoxContainer.new()
	_pip_container.add_theme_constant_override("separation", pip_gap)
	add_child(_pip_container)

func _rebuild_pips() -> void:
	# Nettoyage des tweens et pips existants
	for tw in _tweens:
		if tw and tw.is_valid():
			tw.kill()
	_tweens.clear()
	_pips.clear()

	for child in _pip_container.get_children():
		child.queue_free()

	# Création des nouveaux pips (médaillons divins)
	for i: int in range(_max_value):
		var pip := Panel.new()
		pip.custom_minimum_size = pip_size
		pip.name = "Pip_%d" % i

		var style := StyleBoxFlat.new()
		# AAA: Pip vide (trou dans la pierre)
		style.bg_color = Color(0.04, 0.04, 0.04, 1.0) # Très sombre
		style.corner_radius_top_left = pip_corner_radius
		style.corner_radius_top_right = pip_corner_radius
		style.corner_radius_bottom_left = pip_corner_radius
		style.corner_radius_bottom_right = pip_corner_radius
		# Effet d'embossage inversé (Inset)
		style.border_width_left = 2
		style.border_width_top = 2
		style.border_width_right = 0
		style.border_width_bottom = 0
		style.border_color = Color(0, 0, 0, 1.0) # Ombre interne
		pip.add_theme_stylebox_override("panel", style)

		_pip_container.add_child(pip)
		_pips.append(pip)
		_tweens.append(null)

func _refresh_pips_instant() -> void:
	for i in range(_pips.size()):
		_set_pip_color(_pips[i], i < _current_value)

func _animate_pips(old_val: int, new_val: int) -> void:
	# AAA : Détermination du sens de l'animation (consommation vs regain)
	var pip_min: int = mini(old_val, new_val)
	var pip_max: int = maxi(old_val, new_val)
	var is_gaining: bool = new_val > old_val

	for i in range(pip_min, pip_max):
		if i >= _pips.size():
			break

		var pip: Panel = _pips[i]
		var delay: float = float(i - pip_min) * PIP_STAGGER_DELAY
		var target_color: Color = color_full if is_gaining else color_empty

		# Annulation du tween précédent sur ce pip
		if _tweens[i] and _tweens[i].is_valid():
			_tweens[i].kill()

		_tweens[i] = create_tween()
		_tweens[i].tween_interval(delay)

		# Mythologia : Flash divin — éclair blanc à l'allumage, extinction dégradée au vide
		# L'effet de flash représente la faveur des dieux qui s'allume ou s'éteint
		var flash_is_full: bool = is_gaining
		_tweens[i].tween_callback(_get_pip_setter(pip, flash_is_full))
		_tweens[i].tween_interval(PIP_TWEEN_DURATION * 0.35)
		_tweens[i].tween_callback(_get_pip_setter(pip, is_gaining))

## Closure pour capturer la référence du pip et le booléen dans le callback.
func _get_pip_setter(pip: Panel, is_full: bool) -> Callable:
	return func(): _set_pip_color(pip, is_full)

func _set_pip_color(pip: Panel, is_full: bool) -> void:
	var style: StyleBoxFlat = pip.get_theme_stylebox("panel") as StyleBoxFlat
	if not style:
		return

	if is_full:
		# Aura divine : la gemme est pleine et lumineuse
		style.bg_color = color_full
		style.border_width_left = 1
		style.border_width_top = 1
		style.border_width_right = 1
		style.border_width_bottom = 1
		style.border_color = Color(1.0, 1.0, 1.0, 0.5) # Reflet spéculaire
		style.shadow_color = Color(color_full.r, color_full.g, color_full.b, 0.5)
		style.shadow_size = DIVINE_GLOW_SIZE
		style.shadow_offset = Vector2.ZERO # Glow centré
		pip.material = null
	else:
		# Pierre creuse : le pip s'éteint
		style.bg_color = Color(0.04, 0.04, 0.04, 1.0)
		style.border_width_left = 2
		style.border_width_top = 2
		style.border_width_right = 0
		style.border_width_bottom = 0
		style.border_color = Color(0, 0, 0, 1.0)
		style.shadow_size = 0
