class_name SourceModifiersStep
extends PipelineStep

func apply(data: DamageData) -> void:
	if not data.source or not data.source.stats:
		return
		
	if data.is_healing or data.is_shielding:
		data.current_amount *= data.source.stats.outgoing_healing_multiplier
	else:
		data.current_amount *= data.source.stats.damage_dealt_multiplier
		if data.is_critical:
			data.current_amount *= data.source.stats.base_crit_multiplier
