class_name TargetModifiersStep
extends PipelineStep

func apply(data: DamageData) -> void:
	if not data.target or not data.target.stats:
		return
		
	if data.is_healing or data.is_shielding:
		data.current_amount *= data.target.stats.incoming_healing_multiplier
		return
		
	var amount: float = data.current_amount
	
	amount *= data.target.stats.damage_taken_multiplier
	
	# Résistances Élémentaires (Pourcentage)
	var res: float = 0.0
	match data.element:
		CoreEnums.Element.FIRE: res = data.target.stats.res_fire
		CoreEnums.Element.WATER: res = data.target.stats.res_water
		CoreEnums.Element.ICE: res = data.target.stats.res_ice
		CoreEnums.Element.LIGHTNING: res = data.target.stats.res_lightning
		CoreEnums.Element.EARTH: res = data.target.stats.res_earth
		CoreEnums.Element.POISON: res = data.target.stats.res_poison
		CoreEnums.Element.LIGHT: res = data.target.stats.res_light
		CoreEnums.Element.SHADOW: res = data.target.stats.res_shadow
		
	# Application de la résistance
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
		
	data.current_amount = amount
