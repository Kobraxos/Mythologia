class_name DamageData
extends RefCounted

## Données encapsulant une instance de dégâts ou de soins,
## permettant aux modificateurs d'altérer la valeur dans le pipeline.

var source: Unit
var target: Unit
var skill: SkillData

var base_amount: float = 0.0
var current_amount: float = 0.0
var final_amount: int = -1

var is_healing: bool = false
var is_shielding: bool = false
var is_critical: bool = false
var is_dodged: bool = false

var element: SkillData.Element = SkillData.Element.NONE
var is_mythic: bool = false

## Tags permettant aux passifs/modificateurs de filtrer ce dégât 
## (ex: &"melee", &"projectile", &"dot", &"direct_damage")
var tags: Array[StringName] = []

func _init(p_source: Unit, p_target: Unit, p_skill: SkillData = null) -> void:
	source = p_source
	target = p_target
	skill = p_skill
	
func initialize_amounts(base: float) -> void:
	base_amount = base
	current_amount = base
