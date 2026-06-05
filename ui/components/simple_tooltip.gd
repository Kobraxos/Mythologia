class_name SimpleTooltip
extends PanelContainer

@export var label: Label

# GODOT BUILT-IN FUNCTIONS
func _ready() -> void:
	# AAA Fix : Godot place ce composant dans un PopupPanel généré automatiquement.
	# L'application DOIT être synchrone pour éviter un recalcul de layout (effet de zoom/FOUC).
	var parent := get_parent()
	if parent and parent is PopupPanel:
		parent.transparent_bg = true
		parent.add_theme_stylebox_override("panel", StyleBoxEmpty.new())

# PUBLIC FUNCTIONS
func set_text(text: String) -> void:
	if label:
		label.text = text