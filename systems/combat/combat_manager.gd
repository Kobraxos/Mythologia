class_name CombatManager
extends Node

# GODOT BUILT-IN FUNCTIONS
func _ready() -> void:
	CombatEvents.skill_cast_requested.connect(_on_skill_cast_requested)

# SIGNAL HANDLERS
func _on_skill_cast_requested(caster: Node3D, skill: SkillData, target_hex: Vector3i) -> void:
	var caster_unit := caster as Unit
	if not caster_unit:
		return
		
	var caster_hex: Vector3i = caster_unit.current_hex
		
	# 1. Requête Mathématique (L'Arbitre interroge le Géomètre)
	var affected_hexes: Array[Vector3i] = GridTargeting.get_affected_hexes(caster_hex, target_hex, skill)
	
	# Émission du signal de début pour que l'Interprète Visuel commence l'enregistrement
	CombatEvents.skill_execution_started.emit(caster_unit, skill, target_hex)
	
	# Résolution métier pure (0 ms)
	_resolve_movement(caster_unit, skill, target_hex)
	_resolve_hits(caster_unit, skill, affected_hexes)
	
	# Signal de fin. L'Interprète visuel déploie alors le Séquenceur.
	CombatEvents.skill_execution_finished.emit()

# PRIVATE FUNCTIONS
func _resolve_movement(caster_unit: Unit, skill: SkillData, target_hex: Vector3i) -> void:
	if skill.caster_movement == SkillData.CasterMovement.NONE:
		return
		
	var final_caster_hex: Vector3i = caster_unit.current_hex
	if skill.caster_movement == SkillData.CasterMovement.DASH_TO_TARGET:
		final_caster_hex = GridDisplacement.get_dash_destination(caster_unit, target_hex)
	elif skill.caster_movement == SkillData.CasterMovement.LEAP_TO_TARGET:
		final_caster_hex = GridDisplacement.get_leap_destination(caster_unit, target_hex)
	elif skill.caster_movement == SkillData.CasterMovement.TELEPORT_TO_TARGET:
		final_caster_hex = GridDisplacement.get_teleport_destination(caster_unit, target_hex)
		
	if final_caster_hex != caster_unit.current_hex:
		var prev_hex = caster_unit.current_hex
		GridManager.unit_positions.erase(prev_hex)
		GridManager.unit_positions[final_caster_hex] = caster_unit
		caster_unit.current_hex = final_caster_hex
		GridEvents.unit_moved.emit(caster_unit, prev_hex, final_caster_hex)

func _resolve_hits(caster_unit: Unit, skill: SkillData, affected_hexes: Array[Vector3i]) -> void:
	var max_hits: int = max(1, skill.hit_count)
	var displaced_targets: Dictionary = {}
	
	for hit_index: int in range(max_hits):
		var is_final_hit: bool = (hit_index == max_hits - 1)
		
		# Rythme pour l'Interprète (Nouveau VisualCommandGroup)
		CombatEvents.skill_hit_started.emit(hit_index)
		
		for hex: Vector3i in affected_hexes:
			var target_node: Node3D = GridManager.unit_positions.get(hex)
			if target_node and target_node is Unit:
				var target_unit := target_node as Unit
				var was_hit: bool = _resolve_single_target(caster_unit, target_unit, skill, is_final_hit)
				if was_hit and is_final_hit and (skill.knockback_distance > 0 or skill.pull_distance > 0):
					displaced_targets[target_unit] = true
					
			# Traitement de surface et élémentaire
			if is_final_hit:
				if skill.spawned_surface and skill.spawned_surface.get("is_surface") == true:
					GridManager.add_surface(hex, skill.spawned_surface)
				ElementalSystem.process_elemental_impact(hex, skill.skill_element, caster_unit, skill)
				
		CombatEvents.skill_hit_resolved.emit(hit_index)
		
	# Déplacements forcés (Knockback/Pull) après tous les coups
	_resolve_knockbacks(caster_unit, skill, displaced_targets.keys())

func _resolve_knockbacks(caster_unit: Unit, skill: SkillData, displaced_targets: Array) -> void:
	for t: Unit in displaced_targets:
		var final_hex: Vector3i = t.current_hex
		if skill.knockback_distance > 0:
			final_hex = GridDisplacement.get_knockback_destination(caster_unit, t, skill.knockback_distance)
		elif skill.pull_distance > 0:
			final_hex = GridDisplacement.get_pull_destination(caster_unit, t, skill.pull_distance)
			
		if final_hex != t.current_hex:
			var prev_hex = t.current_hex
			GridManager.unit_positions.erase(prev_hex)
			GridManager.unit_positions[final_hex] = t
			t.current_hex = final_hex
			GridEvents.unit_moved.emit(t, prev_hex, final_hex)

func _resolve_single_target(caster: Unit, target: Unit, skill: SkillData, is_final_hit: bool = true) -> bool:
	var is_dodged := false
	
	# AAA : Smart Targeting & Self-Damage Prevention
	var is_offensive: bool = skill.physical_damage_multiplier > 0.0 or skill.mythic_damage_multiplier > 0.0
	var is_support: bool = skill.base_healing > 0 or skill.flat_shield_granted > 0
	
	if is_offensive and target == caster and skill.target_mode != SkillData.TargetMode.SELF:
		return false # On ne se frappe pas soi-même en atterrissant d'un Dash/Leap
		
	if skill.smart_targeting:
		if is_offensive and target.faction == caster.faction and target != caster:
			return false # Ne blesse pas les alliés
		if is_support and target.faction != caster.faction:
			return false # Ne soigne pas les ennemis
	
	# 1. Résolution des Dégâts via la Pipeline AAA
	if is_offensive:
		var dmg_data := DamageData.new(caster, target, skill)
		
		# Choix du type de dégâts principal (peut être étendu pour faire les deux en même temps)
		if skill.physical_damage_multiplier > 0.0:
			dmg_data.base_amount = float(caster.stats.base_physical_damage) * skill.physical_damage_multiplier
			dmg_data.is_mythic = false
		elif skill.mythic_damage_multiplier > 0.0:
			dmg_data.base_amount = float(caster.stats.base_mythic_damage) * skill.mythic_damage_multiplier
			dmg_data.is_mythic = true
			
		dmg_data.element = skill.skill_element
		
		# Jet de Critique
		var crit_chance: float = caster.stats.base_crit_chance + skill.crit_chance_modifier
		if randf() <= crit_chance:
			dmg_data.is_critical = true
			
		DamagePipeline.calculate_and_apply(dmg_data)
		is_dodged = dmg_data.is_dodged
			
	if is_dodged:
		return false # L'attaque est esquivée, on ignore les effets secondaires et le recul.

	# 2. Résolution des Soins via la Pipeline AAA
	if skill.base_healing > 0:
		var heal_data := DamageData.new(caster, target, skill)
		heal_data.is_healing = true
		heal_data.base_amount = float(skill.base_healing)
		
		if skill.healing_mythic_scaling > 0.0:
			heal_data.base_amount += float(caster.stats.base_mythic_damage) * skill.healing_mythic_scaling
			
		DamagePipeline.calculate_and_apply(heal_data)
			
	# 2.5 Résolution du Bouclier via la Pipeline AAA
	if skill.flat_shield_granted > 0:
		var shield_data := DamageData.new(caster, target, skill)
		shield_data.is_shielding = true
		shield_data.base_amount = float(skill.flat_shield_granted)
		DamagePipeline.calculate_and_apply(shield_data)
			
	# 3. Application des Payloads (Statuts via StatusReceiverComponent)
	if is_final_hit:
		for payload_res: Resource in skill.effect_payloads:
			var payload := payload_res as SkillEffectPayload
			if not payload or not payload.status_effect:
				continue
				
			# Vérification de la probabilité d'application
			if randf() <= payload.application_chance:
				var actual_target: Unit = target
				if payload.target == SkillEffectPayload.PayloadTarget.CASTER:
					actual_target = caster
					
				# Duck typing de sécurité pour s'assurer que la cible gère bien les statuts
				if actual_target and actual_target.status_receiver:
					actual_target.status_receiver.apply_status(payload.status_effect)
					
		# 4. Compétence de suivi (Follow-up Skill)
		if skill.follow_up_skill:
			CombatEvents.skill_cast_requested.emit(caster, skill.follow_up_skill, target.current_hex)
				
	return true