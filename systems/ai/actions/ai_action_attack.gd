class_name AIActionAttack
extends AIAction

# EXPORTS
@export var skill_to_use: SkillData

# PUBLIC FUNCTIONS
func execute(context: AIContext) -> void:
	if not skill_to_use or not is_instance_valid(context.unit):
		_end_action()
		return
		
	var unit: Unit = context.unit
	var caster: SkillCasterComponent = unit.skill_caster
	
	if not caster:
		_end_action()
		return
		
	# 1. Vérification économique (PA et Cooldown) pour éviter des calculs lourds inutiles
	if caster.get_cooldowns().get(skill_to_use, 0) > 0:
		_end_action()
		return
		
	if unit.action_economy and not unit.action_economy.has_enough_ap(skill_to_use.ap_cost):
		_end_action()
		return
		
	# 2. Récupération des cases atteignables
	var valid_range: Array[Vector3i] = HexAoE.get_valid_casting_range(context.current_hex, skill_to_use)
	
	var best_target_hex: Vector3i = Vector3i(0, 0, -999)
	var lowest_hp: int = 999999
	var found_target: bool = false
	
	# 3. Évaluation tactique des cibles
	for target_hex: Vector3i in valid_range:
		if not GridManager.unit_positions.has(target_hex):
			continue
			
		var target_unit: Unit = GridManager.unit_positions[target_hex]
		if not is_instance_valid(target_unit) or target_unit == unit:
			continue
			
		# Filtrage strict de l'allégeance (Identify Friend or Foe)
		var is_enemy: bool = target_unit.faction != unit.faction
		var valid_alignment: bool = false
		
		match skill_to_use.allowed_alignments:
			SkillData.TargetAlignment.ENEMY:
				valid_alignment = is_enemy
			SkillData.TargetAlignment.ALLY:
				valid_alignment = not is_enemy
			SkillData.TargetAlignment.ANY:
				valid_alignment = true
				
		if not valid_alignment:
			continue
			
		# Heuristique : Prioriser la cible avec le moins de points de vie
		if target_unit.health_component:
			var hp: int = target_unit.health_component.get_current_health()
			if hp < lowest_hp:
				lowest_hp = hp
				best_target_hex = target_hex
				found_target = true
				
	if not found_target:
		_end_action()
		return
		
	# 4. Préparation de la résolution asynchrone (AAA Stateless Lambda)
	var on_resolved: Callable
	on_resolved = func(resolving_caster: Node3D, resolved_skill: SkillData, _t_hex: Vector3i) -> void:
		if resolving_caster == unit and resolved_skill == skill_to_use:
			if CombatEvents.skill_resolved.is_connected(on_resolved):
				CombatEvents.skill_resolved.disconnect(on_resolved)
			_end_action()
			
	CombatEvents.skill_resolved.connect(on_resolved)
	
	# 5. Déclenchement
	var success: bool = caster.cast_skill(skill_to_use, best_target_hex)
	if not success:
		# En cas de garde inattendue dans le SkillCaster
		if CombatEvents.skill_resolved.is_connected(on_resolved):
			CombatEvents.skill_resolved.disconnect(on_resolved)
		_end_action()

# PRIVATE FUNCTIONS
func _end_action() -> void:
	finished.emit()