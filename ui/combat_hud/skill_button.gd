class_name SkillButton
extends Button

## Représentation UI d'une compétence. Totalement stupide, ne fait qu'émettre un signal.

# PRIVATE VARIABLES
var _skill: SkillData

# GODOT BUILT-IN FUNCTIONS
func _ready() -> void:
	pressed.connect(_on_pressed)

# PUBLIC FUNCTIONS
func setup(skill: SkillData) -> void:
	_skill = skill
	
	# Duck-typing sécurisé : On tente de récupérer le nom et l'icône
	text = skill.get("skill_name") if "skill_name" in skill else "Compétence Inconnue"
	
	if "icon" in skill and skill.get("icon") is Texture2D:
		icon = skill.get("icon")
		
	# Respect de la Charte : On utilise les variations du Thème, pas d'override en dur !
	theme_type_variation = "BoldLabel"

# SIGNAL HANDLERS
func _on_pressed() -> void:
	if _skill:
		CombatEvents.skill_button_clicked.emit(_skill)