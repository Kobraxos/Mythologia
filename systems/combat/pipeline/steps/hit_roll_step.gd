class_name HitRollStep
extends PipelineStep

func apply(data: DamageData) -> void:
	# L'esquive ne concerne que les dégâts physiques/mythiques, pas les soins ni les boucliers.
	if data.is_healing or data.is_shielding:
		return
		
	if data.source and data.source.stats and data.target.stats:
		# Formule AAA standard : Précision - Esquive (capée entre 5% et 100%)
		var accuracy: float = data.source.stats.base_accuracy
		if data.skill:
			accuracy += data.skill.accuracy_modifier
			
		var hit_chance: float = clampf(accuracy - data.target.stats.base_evasion, 0.05, 1.0)
		if randf() > hit_chance:
			data.is_dodged = true
			data.current_amount = 0.0
			data.final_amount = 0
			CombatEvents.attack_dodged.emit(data.target)
