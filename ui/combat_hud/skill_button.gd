class_name SkillButton
extends Button

## Représentation UI d'une compétence. Bouton AAA Icon-Driven.

# EXPORTS
@export var shortcut_label: Label
@export var ap_cost_label: Label
@export var ap_cost_container: Control
@export var cooldown_progress: TextureProgressBar
@export var cooldown_label: Label

# PRIVATE VARIABLES
var _skill: SkillData
var _caster: Node

# GODOT BUILT-IN FUNCTIONS
func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	shortcut_in_tooltip = false
	pressed.connect(_on_pressed)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

# PUBLIC FUNCTIONS
func setup(skill: SkillData, caster: Node = null, shortcut_text: String = "") -> void:
	_skill = skill
	_caster = caster
	
	# Icone
	if "icon" in skill and skill.get("icon") is Texture2D:
		icon = skill.get("icon")
	
	# Shortcut
	if shortcut_label:
		if shortcut_text != "":
			shortcut_label.text = shortcut_text
			shortcut_label.get_parent().visible = true
		else:
			shortcut_label.text = ""
			shortcut_label.get_parent().visible = false
			
	# AP Cost
	if ap_cost_container and ap_cost_label:
		if skill.ap_cost > 0:
			ap_cost_label.text = str(skill.ap_cost)
			ap_cost_container.visible = true
		else:
			ap_cost_container.visible = false
			
	# Initial states for CD
	if cooldown_progress:
		cooldown_progress.visible = false
	if cooldown_label:
		cooldown_label.visible = false
		
func check_usability(available_ap: int, current_cooldown: int = 0) -> void:
	if not _skill:
		return
		
	if current_cooldown > 0:
		disabled = true
		
		# Afficher l'overlay radial et le texte
		if cooldown_progress:
			cooldown_progress.visible = true
			# On simule un ratio. Si cooldown max est connu, on pourrait faire (current/max)*100
			# Pour l'instant, disons qu'on affiche la barre pleine si CD, ou on simule 100%
			var max_cd = float(_skill.cooldown) if _skill.cooldown > 0 else float(current_cooldown)
			var ratio = (float(current_cooldown) / max_cd) * 100.0
			cooldown_progress.value = ratio
			
		if cooldown_label:
			cooldown_label.visible = true
			cooldown_label.text = str(current_cooldown)
	else:
		disabled = available_ap < _skill.ap_cost
		
		# Cacher l'overlay
		if cooldown_progress:
			cooldown_progress.visible = false
		if cooldown_label:
			cooldown_label.visible = false

# SIGNAL HANDLERS
func _on_pressed() -> void:
	if _skill:
		CombatEvents.skill_button_clicked.emit(_skill)

func _on_mouse_entered() -> void:
	if _skill:
		var data_dict = _skill.get_tooltip_data(_caster)
		TooltipManager.show_tooltip(data_dict, global_position, size)

func _on_mouse_exited() -> void:
	TooltipManager.hide_tooltip()