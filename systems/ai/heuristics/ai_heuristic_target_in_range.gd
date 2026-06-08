class_name AIHeuristicTargetInRange
extends AIHeuristic

@export_category("Targeting")
@export var skill_to_check: SkillData

# PUBLIC FUNCTIONS
func evaluate(context: AIContext) -> float:
	if not skill_to_check or not is_instance_valid(context.unit):
		return 0.0
		
	var unit: Unit = context.unit
	var valid_range: Array[Vector3i] = GridTargeting.get_valid_casting_range(context.current_hex, skill_to_check)
	
	for hex: Vector3i in valid_range:
		var target_node: Node3D = GridManager.unit_positions.get(hex)
		if not target_node or not target_node is Unit:
			continue
			
		var target_unit := target_node as Unit
		if not is_instance_valid(target_unit) or target_unit == unit:
			continue
			
		if AIUtils.is_valid_alignment(unit, target_unit, skill_to_check.allowed_alignments):
			return 1.0 # Une cible valide est présente dans la zone de ciblage
			
	return 0.0
