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
	var affected_hexes: Array[Vector3i] = HexAoE.get_affected_hexes(caster_hex, target_hex, skill)
	
	# 2. Exécution Logique
	for hex: Vector3i in affected_hexes:
		var target_node: Node3D = GridManager.unit_positions.get(hex)
		if target_node and target_node is Unit:
			_resolve_single_target(caster_unit, target_node as Unit, skill)
			
	# 3. Libération asynchrone : Informe l'IA ou l'UI que le sort a terminé son exécution
	CombatEvents.skill_resolved.emit(caster, skill, target_hex)

# PRIVATE FUNCTIONS
func _resolve_single_target(caster: Unit, target: Unit, skill: SkillData) -> void:
	# 1. Résolution des Dégâts AAA (Connecté aux statistiques dynamiques)
	if skill.physical_damage_multiplier > 0.0:
		var base_damage: float = float(caster.stats.base_physical_damage)
		var final_damage: int = roundi(base_damage * skill.physical_damage_multiplier * caster.stats.damage_dealt_multiplier)
		
		if target.health_component:
			target.health_component.take_damage(final_damage)
			CombatEvents.damage_dealt.emit(target, final_damage, false)
			
	# 2. Résolution des Soins
	if skill.base_healing > 0:
		if target.health_component:
			target.health_component.heal(skill.base_healing)
			CombatEvents.healing_done.emit(target, skill.base_healing)
			
	# 3. Application des Payloads (Statuts via StatusReceiverComponent)
	for payload_res: Resource in skill.effect_payloads:
		var payload := payload_res as SkillEffectPayload
		if not payload or not payload.status_effect:
			continue
			
		# Vérification de la probabilité d'application
		if randf() <= payload.application_chance:
			# Duck typing de sécurité pour s'assurer que la cible gère bien les statuts
			if target.get("status_receiver") != null:
				target.status_receiver.apply_status(payload.status_effect)