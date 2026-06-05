class_name AIHeuristicTargetInRange
extends AIHeuristic

@export_category("Targeting")
@export var skill_to_check: SkillData

# PUBLIC FUNCTIONS
func evaluate(context: AIContext) -> float:
	if not skill_to_check or not is_instance_valid(context.unit):
		return 0.0
		
	var unit: Unit = context.unit
	var valid_range: Array[Vector3i] = HexAoE.get_valid_casting_range(context.current_hex, skill_to_check)
	
	for hex: Vector3i in valid_range:
		var target_node: Node3D = GridManager.unit_positions.get(hex)
		if not target_node or not target_node is Unit:
			continue
			
		var target_unit := target_node as Unit
		if not is_instance_valid(target_unit) or target_unit == unit:
			continue
			
		var is_enemy: bool = target_unit.faction != unit.faction
		var valid_alignment: bool = false
		
		match skill_to_check.allowed_alignments:
			SkillData.TargetAlignment.ENEMY:
				valid_alignment = is_enemy
			SkillData.TargetAlignment.ALLY:
				valid_alignment = not is_enemy
			SkillData.TargetAlignment.ANY:
				valid_alignment = true
				
		if valid_alignment:
			return 1.0 # Une cible valide est présente dans la zone de ciblage
			
	return 0.0