class_name AIHeuristicHasAP
extends AIHeuristic

@export_category("Action Economy")
## Si renseigné, l'heuristique lira directement le coût et le cooldown de ce sort.
@export var skill_to_check: SkillData
## Utilisé uniquement si aucune compétence n'est renseignée.
@export var minimum_ap: int = 1

# PUBLIC FUNCTIONS
func evaluate(context: AIContext) -> float:
	var unit: Unit = context.unit
	if not is_instance_valid(unit) or not unit.action_economy:
		return 0.0
		
	var required_ap: int = minimum_ap
	
	if skill_to_check:
		required_ap = skill_to_check.ap_cost
		# AAA : Si le sort est en recharge, on tue l'envie à la racine
		if unit.skill_caster and unit.skill_caster.get_cooldowns().get(skill_to_check, 0) > 0:
			return 0.0
			
	if unit.action_economy.has_enough_ap(required_ap):
		return 1.0
		
	return 0.0