class_name SkillCasterComponent
extends Node

# EXPORTS
@export_category("Dependencies")
## Règle de Couplage Fratrie : Injection du portefeuille d'actions.
@export var action_economy: ActionEconomyComponent

# PRIVATE VARIABLES
var _known_skills: Array[SkillData] = []
var _cooldowns: Dictionary[SkillData, int] = {}

# PUBLIC FUNCTIONS
func initialize(skills: Array[SkillData]) -> void:
	_known_skills = skills
	_cooldowns.clear()

## Vérifie les ressources et demande l'exécution de la compétence. Retourne vrai si le sort a pu être lancé.
func cast_skill(skill: SkillData, target_hex: Vector3i) -> bool:
	if not skill in _known_skills:
		return false
		
	if _cooldowns.get(skill, 0) > 0:
		return false # Sort en récupération
		
	if action_economy and not action_economy.has_enough_ap(skill.ap_cost):
		return false # PA insuffisants
		
	if action_economy:
		action_economy.consume_ap(skill.ap_cost)
		
	_cooldowns[skill] = skill.cooldown
	CombatEvents.skill_cast_requested.emit(get_parent(), skill, target_hex)
	return true

func tick_cooldowns() -> void:
	for skill: SkillData in _cooldowns.keys():
		if _cooldowns[skill] > 0:
			_cooldowns[skill] -= 1