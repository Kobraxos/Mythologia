class_name SystemActionButton
extends Button

@export var action_name: String = "move"
@export var shortcut_label: Label
@export var active_overlay: ColorRect

func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	shortcut_in_tooltip = false
	if toggle_mode:
		toggled.connect(_on_toggled)

func set_shortcut_text(text: String) -> void:
	if shortcut_label:
		shortcut_label.text = text

func _on_toggled(button_pressed: bool) -> void:
	if active_overlay:
		active_overlay.visible = button_pressed
