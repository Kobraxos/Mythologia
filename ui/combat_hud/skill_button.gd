class_name SkillButton
extends Button

## Représentation UI d'une compétence. Totalement stupide, ne fait qu'émettre un signal.

# PRIVATE VARIABLES
var _skill: SkillData
var _base_text: String = ""

# GODOT BUILT-IN FUNCTIONS
func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	pressed.connect(_on_pressed)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

# PUBLIC FUNCTIONS
func setup(skill: SkillData, shortcut_text: String = "") -> void:
	_skill = skill
	
	# Duck-typing sécurisé : On tente de récupérer le nom et l'icône
	var s_name: String = skill.get("skill_name") if "skill_name" in skill else "Compétence Inconnue"
	if shortcut_text != "":
		_base_text = s_name + " [" + shortcut_text + "]"
	else:
		_base_text = s_name
		
	text = _base_text
	
	if "icon" in skill and skill.get("icon") is Texture2D:
		icon = skill.get("icon")
		
func check_usability(available_ap: int, current_cooldown: int = 0) -> void:
	if not _skill:
		return
		
	if current_cooldown > 0:
		disabled = true
		text = _base_text + " (CD: " + str(current_cooldown) + ")"
	else:
		disabled = available_ap < _skill.ap_cost
		text = _base_text

# SIGNAL HANDLERS
func _on_pressed() -> void:
	if _skill:
		CombatEvents.skill_button_clicked.emit(_skill)

func _on_mouse_entered() -> void:
	if _skill:
		var data_dict = _skill.get_tooltip_data()
		TooltipManager.show_tooltip(data_dict, global_position, size)

func _on_mouse_exited() -> void:
	TooltipManager.hide_tooltip()