class_name ApplicationStep
extends PipelineStep

func apply(data: DamageData) -> void:
	if data.final_amount <= 0:
		return
		
	if data.is_healing:
		data.target.health_component.heal(data.final_amount)
		CombatEvents.healing_done.emit(data.target, data.final_amount)
	elif data.is_shielding:
		data.target.health_component.grant_shield(data.final_amount)
		CombatEvents.shield_granted.emit(data.target, data.final_amount)
	else:
		data.target.health_component.take_damage(data.final_amount)
		CombatEvents.damage_dealt.emit(data.target, data.final_amount, data.is_critical)
