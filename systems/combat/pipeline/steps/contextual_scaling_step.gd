class_name ContextualScalingStep
extends PipelineStep

func apply(data: DamageData) -> void:
	if data.is_healing or data.is_shielding:
		return
		
	if data.skill and data.skill.contextual_scaling != SkillData.DamageScaling.NONE:
		var factor: float = data.skill.scaling_factor
		var multiplier: float = 1.0
		var flat_bonus: float = 0.0
		
		match data.skill.contextual_scaling:
			SkillData.DamageScaling.TARGET_MISSING_HP:
				if data.target and data.target.health_component and data.target.stats:
					var max_hp: int = data.target.stats.max_health
					if max_hp > 0:
						var current_hp: int = data.target.health_component.get_current_health()
						var missing_pct: float = 1.0 - (float(current_hp) / float(max_hp))
						multiplier += missing_pct * factor
			SkillData.DamageScaling.TARGET_MAX_HP:
				if data.target and data.target.stats:
					flat_bonus += float(data.target.stats.max_health) * factor
			SkillData.DamageScaling.CASTER_MAX_HP:
				if data.source and data.source.stats:
					flat_bonus += float(data.source.stats.max_health) * factor
			SkillData.DamageScaling.CASTER_CURRENT_MANA:
				if data.source is Unit and data.source.stats and data.source.action_economy:
					var max_mana: int = data.source.stats.max_mana
					if max_mana > 0:
						var current_mana: int = data.source.action_economy.get_current_mana()
						var mana_ratio: float = float(current_mana) / float(max_mana)
						multiplier += mana_ratio * factor
			SkillData.DamageScaling.FLAT_HP_DIFFERENCE:
				if data.source is Unit and data.target is Unit and data.source.stats and data.target.stats and data.source.health_component and data.target.health_component:
					var s_max: int = data.source.stats.max_health
					var t_max: int = data.target.stats.max_health
					if s_max > 0 and t_max > 0:
						var s_ratio: float = float(data.source.health_component.get_current_health()) / float(s_max)
						var t_ratio: float = float(data.target.health_component.get_current_health()) / float(t_max)
						multiplier += maxf(0.0, s_ratio - t_ratio) * factor
			SkillData.DamageScaling.ELEVATION_DIFFERENCE:
				if data.source is Unit and data.target is Unit:
					var s_z: int = data.source.current_hex.z
					var t_z: int = data.target.current_hex.z
					multiplier += maxf(0.0, float(s_z - t_z)) * factor
					
		data.current_amount = (data.current_amount + flat_bonus) * multiplier
