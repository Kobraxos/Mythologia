class_name DamagePipeline
extends RefCounted

## L'arbitre ultime des dégâts et soins de Mythologia (Pipeline AAA).
## Calcule la valeur finale en passant par plusieurs filtres (buffs, armure, résistances).

static func calculate_and_apply(data: DamageData) -> void:
	if not data.target or not data.target.health_component:
		return
		
	if data.is_healing:
		_process_healing(data)
	else:
		_process_damage(data)

static func _process_damage(data: DamageData) -> void:
	# 1. Jet d'Esquive / Précision (Hit Roll)
	if data.source and data.source.stats and data.target.stats:
		# Formule AAA standard : Précision - Esquive (capée entre 5% et 100%)
		var accuracy: float = data.source.stats.base_accuracy
		if data.skill:
			accuracy += data.skill.accuracy_modifier
			
		var hit_chance: float = clampf(accuracy - data.target.stats.base_evasion, 0.05, 1.0)
		if randf() > hit_chance:
			data.is_dodged = true
			data.final_amount = 0
			if not CombatEvents.has_user_signal("attack_dodged"):
				CombatEvents.add_user_signal("attack_dodged", [{"name": "target", "type": TYPE_OBJECT}])
			CombatEvents.emit_signal("attack_dodged", data.target)
			return
			
	var amount: float = data.base_amount
	
	# 2. Modificateurs de la Source (Buffs de dégâts, Multiplicateurs critiques)
	if data.source and data.source.stats:
		amount *= data.source.stats.damage_dealt_multiplier
		if data.is_critical:
			amount *= data.source.stats.base_crit_multiplier
	
	# 3. Modificateurs de la Cible (Vulnérabilités, Résistances Élémentaires, Armure)
	if data.target.stats:
		amount *= data.target.stats.damage_taken_multiplier
		
		# Résistances Élémentaires (Pourcentage)
		var res: float = 0.0
		match data.element:
			SkillData.Element.FIRE: res = data.target.stats.res_fire
			SkillData.Element.WATER: res = data.target.stats.res_water
			SkillData.Element.ICE: res = data.target.stats.res_ice
			SkillData.Element.LIGHTNING: res = data.target.stats.res_lightning
			SkillData.Element.EARTH: res = data.target.stats.res_earth
			SkillData.Element.POISON: res = data.target.stats.res_poison
			SkillData.Element.LIGHT: res = data.target.stats.res_light
			SkillData.Element.SHADOW: res = data.target.stats.res_shadow
			
		# Application de la résistance (ex: res 0.20 = 20% de réduction)
		amount *= (1.0 - res)
		
		# Mitigations Plates (Armure / Défense)
		var armor_pen: float = 0.0
		if data.skill:
			armor_pen += data.skill.armor_penetration_bonus
			
		if data.is_mythic:
			var pen: float = (data.source.stats.mythic_penetration if data.source else 0.0) + armor_pen
			var effective_def: float = maxf(0.0, data.target.stats.mythic_defense * (1.0 - pen))
			amount = maxf(0.0, amount - effective_def)
		else:
			var pen: float = (data.source.stats.physical_penetration if data.source else 0.0) + armor_pen
			var effective_def: float = maxf(0.0, data.target.stats.physical_defense * (1.0 - pen))
			amount = maxf(0.0, amount - effective_def)

	# 4. Variance et Final Clamp
	if amount > 0.0:
		# Variance AAA de +/- 10%
		amount *= randf_range(0.9, 1.1)
		amount = maxf(1.0, amount)
		
	data.final_amount = roundi(amount)
	
	# 5. Application (Mutations d'état)
	if data.final_amount > 0:
		data.target.health_component.take_damage(data.final_amount)
	
	# 6. Événements Globaux (Pour l'UI, les logs de combat, les passifs)
	CombatEvents.damage_dealt.emit(data.target, data.final_amount, data.is_critical)

static func _process_healing(data: DamageData) -> void:
	var amount: float = data.base_amount
	
	# Modificateurs de Soin Sortant
	if data.source and data.source.stats:
		amount *= data.source.stats.outgoing_healing_multiplier
		
	# Modificateurs de Soin Entrant
	if data.target and data.target.stats:
		amount *= data.target.stats.incoming_healing_multiplier
		
	# Variance AAA de +/- 10%
	amount *= randf_range(0.9, 1.1)
		
	data.final_amount = maxi(0, roundi(amount))
	
	if data.final_amount > 0:
		data.target.health_component.heal(data.final_amount)
		
	CombatEvents.healing_done.emit(data.target, data.final_amount)
