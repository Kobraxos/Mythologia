class_name ResourcePanel
extends PanelContainer

## Panneau AAA regroupant les barres de Points d'Action (PA) et de Mouvement (PM).
## S'abonne aux signaux des composants de l'unité active et se met à jour automatiquement.
## Aucune dépendance directe sur les nœuds de la scène : tout passe par des @exports.

# EXPORTS
@export var ap_bar: ResourcePipBar
@export var mp_bar: ResourcePipBar

# PRIVATE VARIABLES
## Référence gardée pour pouvoir se désabonner proprement à la prochaine sélection.
var _tracked_economy: ActionEconomyComponent = null

# GODOT BUILT-IN FUNCTIONS
func _ready() -> void:
	# Le panneau est invisible par défaut (aucune unité sélectionnée)
	visible = false
	TurnEvents.active_unit_changed.connect(_on_active_unit_changed)
	GridEvents.unit_deselected.connect(_on_unit_deselected)
	_apply_background_style()

# PUBLIC API
## Connecte ce panneau à l'économie d'action d'une unité et affiche les valeurs initiales.
func track_unit(unit: Unit) -> void:
	_untrack()

	if not is_instance_valid(unit) or not unit.action_economy:
		visible = false
		return

	_tracked_economy = unit.action_economy
	_tracked_economy.ap_changed.connect(_on_ap_changed)
	_tracked_economy.mp_changed.connect(_on_mp_changed)

	# Initialisation immédiate (snapshot de l'état courant)
	if ap_bar:
		ap_bar.initialize(
			_tracked_economy.get_current_ap(),
			_tracked_economy.get_max_ap()
		)
	if mp_bar:
		mp_bar.initialize(
			_tracked_economy.get_current_mp(),
			_tracked_economy.get_max_mp()
		)

	visible = true

# PRIVATE FUNCTIONS
func _untrack() -> void:
	if is_instance_valid(_tracked_economy):
		if _tracked_economy.ap_changed.is_connected(_on_ap_changed):
			_tracked_economy.ap_changed.disconnect(_on_ap_changed)
		if _tracked_economy.mp_changed.is_connected(_on_mp_changed):
			_tracked_economy.mp_changed.disconnect(_on_mp_changed)
	_tracked_economy = null

func _apply_background_style() -> void:
	# Mythologia : Tablette de pierre ancienne aux reflets de bronze
	# Inspiré de la palette existante : Or Divin / Lumière Solaire du joueur
	var style := StyleBoxFlat.new()

	# Fond : pierre sombre comme les murs de l'Olympe dans l'ombre
	style.bg_color = Color(0.07, 0.06, 0.09, 0.92)

	# Forme : coins légèrement arrondis comme une tablette taillée à la main
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6

	# Bordure : bronze antique gravé (épaisseur supérieure = gravure en relief)
	style.border_width_left = 1
	style.border_width_top = 2
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.85, 0.70, 0.25, 0.55) # Or Divin atténué

	# Ombre portée : ombre divine, comme si la tablette flottait
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.65)
	style.shadow_size = 10
	style.shadow_offset = Vector2(0, 4)

	add_theme_stylebox_override("panel", style)

# SIGNAL HANDLERS
func _on_ap_changed(current: int, max_val: int) -> void:
	if ap_bar:
		ap_bar.set_value(current, max_val)

func _on_mp_changed(current: int, max_val: int) -> void:
	if mp_bar:
		mp_bar.set_value(current, max_val)

func _on_active_unit_changed(unit: Unit) -> void:
	# AAA : À chaque changement de tour on re-track l'unité active
	track_unit(unit)

func _on_unit_deselected() -> void:
	# Le panneau reste visible si une unité joue (basé sur active_unit)
	# Il se cache uniquement si aucune unité n'est suivie
	pass
