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
	
	# 1.5 Interception AAA : On écoute les événements de la DamagePipeline pour les mettre en file d'attente
	var captured_texts: Array[VisualCommand] = []
	
	var capture_dmg := func(t: Node3D, amount: int, is_crit: bool) -> void:
		var cmd := VisualCommand.new()
		cmd.type = VisualCommand.Type.DAMAGE_NUMBER
		cmd.target = t
		cmd.int_payload = amount
		cmd.string_payload = "CRIT" if is_crit else "DAMAGE"
		captured_texts.append(cmd)
		
		# AAA UI : Capture de la santé post-impact pour le Séquenceur
		var hp_cmd := VisualCommand.new()
		hp_cmd.type = VisualCommand.Type.UPDATE_HEALTH_BAR
		hp_cmd.target = t
		if t.get("health_component") != null: hp_cmd.int_payload = t.health_component.get_current_health()
		captured_texts.append(hp_cmd)
		
		# AAA VFX : Injection d'une Commande VFX directionnelle (Statique au point d'impact)
		var vfx_cmd := VisualCommand.new()
		vfx_cmd.type = VisualCommand.Type.SPAWN_VFX
		vfx_cmd.string_payload = "impact_hit" # Vfx ID
		vfx_cmd.position_payload = t.global_position + Vector3(0, 1.0, 0) # Centre de masse
		if is_instance_valid(caster) and is_instance_valid(t):
			var dir := (t.global_position - caster.global_position).normalized()
			vfx_cmd.direction_payload = dir if dir.length_squared() > 0.0 else Vector3.UP
		captured_texts.append(vfx_cmd)
		
	var capture_heal := func(t: Node3D, amount: int) -> void:
		var cmd := VisualCommand.new()
		cmd.type = VisualCommand.Type.DAMAGE_NUMBER
		cmd.target = t
		cmd.int_payload = amount
		cmd.string_payload = "HEAL"
		captured_texts.append(cmd)
		
		# AAA UI : Capture de la santé post-soin pour le Séquenceur
		var hp_cmd := VisualCommand.new()
		hp_cmd.type = VisualCommand.Type.UPDATE_HEALTH_BAR
		hp_cmd.target = t
		if t.get("health_component") != null: hp_cmd.int_payload = t.health_component.get_current_health()
		captured_texts.append(hp_cmd)
		
		# AAA VFX : Injection d'une Commande VFX avec Attachement Dynamique
		var vfx_cmd := VisualCommand.new()
		vfx_cmd.type = VisualCommand.Type.SPAWN_VFX
		vfx_cmd.string_payload = "heal_effect" # Vfx ID
		vfx_cmd.target = t # Assigne l'attachement au Node3D cible
		vfx_cmd.direction_payload = Vector3.UP
		captured_texts.append(vfx_cmd)
		
	var capture_shield := func(t: Node3D, amount: int) -> void:
		var cmd := VisualCommand.new()
		cmd.type = VisualCommand.Type.DAMAGE_NUMBER
		cmd.target = t
		cmd.int_payload = amount
		cmd.string_payload = "AEGIS"
		captured_texts.append(cmd)
		
		var hp_cmd := VisualCommand.new()
		hp_cmd.type = VisualCommand.Type.UPDATE_HEALTH_BAR
		hp_cmd.target = t
		if t.get("health_component") != null: hp_cmd.int_payload = t.health_component.get_current_health()
		captured_texts.append(hp_cmd)
		
		var vfx_cmd := VisualCommand.new()
		vfx_cmd.type = VisualCommand.Type.SPAWN_VFX
		vfx_cmd.string_payload = "shield_granted"
		vfx_cmd.target = t
		vfx_cmd.direction_payload = Vector3.UP
		captured_texts.append(vfx_cmd)
		
	var capture_dodge := func(t: Node3D) -> void:
		var cmd := VisualCommand.new()
		cmd.type = VisualCommand.Type.DAMAGE_NUMBER
		cmd.target = t
		cmd.string_payload = "DODGE"
		captured_texts.append(cmd)
		
		# AAA VFX : Poussière d'esquive (statique au sol)
		var vfx_cmd := VisualCommand.new()
		vfx_cmd.type = VisualCommand.Type.SPAWN_VFX
		vfx_cmd.string_payload = "dodge_dust" # ID à ajouter dans l'inspecteur VfxManager
		vfx_cmd.position_payload = t.global_position
		captured_texts.append(vfx_cmd)
		
	CombatEvents.damage_dealt.connect(capture_dmg)
	CombatEvents.healing_done.connect(capture_heal)
	CombatEvents.shield_granted.connect(capture_shield)
	if not CombatEvents.has_user_signal("attack_dodged"):
		CombatEvents.add_user_signal("attack_dodged", [{"name": "target", "type": TYPE_OBJECT}])
	CombatEvents.connect("attack_dodged", capture_dodge)
	
	var sequence: Array[VisualCommandGroup] = []
	
	# 2. Boucle du Multi-Hit AAA (Séquençage temporel)
	var max_hits: int = max(1, skill.hit_count)
	for hit_index: int in range(max_hits):
		var is_final_hit: bool = (hit_index == max_hits - 1)
		var current_group := VisualCommandGroup.new()
		captured_texts.clear() # Réinitialise l'interception pour cette frappe
		var displaced_targets: Array[Unit] = []
		
		# AAA : Rythmique du Multi-Hit (On simule une animation pour créer le délai dans le Séquenceur)
		var anim_cmd := VisualCommand.new()
		anim_cmd.type = VisualCommand.Type.PLAY_ANIMATION
		anim_cmd.target = caster
		anim_cmd.string_payload = skill.animation_trigger
		anim_cmd.duration = 0.3 # C'est ce délai qui cadence le "Bam... Bam..."
		current_group.commands.append(anim_cmd)
		
		# Exécution Logique Instantanée (0 ms) pour la frappe actuelle
		for hex: Vector3i in affected_hexes:
			var target_node: Node3D = GridManager.unit_positions.get(hex)
			if target_node and target_node is Unit:
				var target_unit := target_node as Unit
				var was_hit: bool = _resolve_single_target(caster_unit, target_unit, skill, is_final_hit)
				if was_hit and is_final_hit and (skill.knockback_distance > 0 or skill.pull_distance > 0):
					displaced_targets.append(target_unit)
					
		if is_final_hit:
			# 3. Résolution Mathématique des Déplacements Forcés (0 ms)
			var knockback_destinations: Dictionary = {}
			for t: Unit in displaced_targets:
				var final_hex: Vector3i = t.current_hex
				if skill.knockback_distance > 0:
					final_hex = GridDisplacement.get_knockback_destination(caster_unit, t, skill.knockback_distance)
				elif skill.pull_distance > 0:
					final_hex = GridDisplacement.get_pull_destination(caster_unit, t, skill.pull_distance)
					
				if final_hex != t.current_hex:
					knockback_destinations[t] = final_hex
					var prev_hex = t.current_hex
					GridManager.unit_positions.erase(prev_hex)
					GridManager.unit_positions[final_hex] = t
					t.current_hex = final_hex
					GridEvents.unit_moved.emit(t, prev_hex, final_hex)
					
			# Ajout des commandes de déplacement
			for t: Unit in knockback_destinations:
				var cmd := VisualCommand.new()
				cmd.type = VisualCommand.Type.FORCED_MOVEMENT
				cmd.target = t
				cmd.target_hex = knockback_destinations[t]
				current_group.commands.append(cmd)
				
				var vfx_cmd := VisualCommand.new()
				vfx_cmd.type = VisualCommand.Type.SPAWN_VFX
				vfx_cmd.string_payload = "dash_trail"
				vfx_cmd.target = t
				var start_pos := t.global_position
				var end_pos := HexMath.hex_to_world(knockback_destinations[t], GridManager.hex_size, GridManager.elevation_step)
				var move_dir := (end_pos - start_pos).normalized()
				vfx_cmd.direction_payload = move_dir if move_dir.length_squared() > 0.0 else Vector3.UP
				current_group.commands.append(vfx_cmd)
				
		# Ajout des Textes et Particules capturés pour CETTE frappe
		for cmd: VisualCommand in captured_texts:
			current_group.commands.append(cmd)
			
		if not current_group.commands.is_empty():
			sequence.append(current_group)
			
	# 3.5 Fin de l'Interception
	CombatEvents.damage_dealt.disconnect(capture_dmg)
	CombatEvents.healing_done.disconnect(capture_heal)
	CombatEvents.shield_granted.disconnect(capture_shield)
	CombatEvents.disconnect("attack_dodged", capture_dodge)
		
	# Déploiement du Séquenceur Éphémère (Mort programmée)
	var sequencer = CombatSequencer.new()
	add_child(sequencer)
	sequencer.play_sequence(sequence, caster, skill, target_hex)

# PRIVATE FUNCTIONS
func _resolve_single_target(caster: Unit, target: Unit, skill: SkillData, is_final_hit: bool = true) -> bool:
	var is_dodged := false
	
	# 1. Résolution des Dégâts via la Pipeline AAA
	if skill.physical_damage_multiplier > 0.0 or skill.mythic_damage_multiplier > 0.0:
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
				if actual_target and actual_target.get("status_receiver") != null:
					actual_target.status_receiver.apply_status(payload.status_effect)
					
		# 4. Compétence de suivi (Follow-up Skill)
		if skill.follow_up_skill:
			CombatEvents.skill_cast_requested.emit(caster, skill.follow_up_skill, target.current_hex)
				
	return true