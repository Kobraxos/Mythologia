class_name VarianceStep
extends PipelineStep

func apply(data: DamageData) -> void:
	var amount: float = data.current_amount
	
	if amount > 0.0:
		# Variance AAA de +/- 10%
		amount *= randf_range(0.9, 1.1)
		
		# Les dégâts minimums sont de 1, les soins/boucliers de 0.
		if not data.is_healing and not data.is_shielding:
			amount = maxf(1.0, amount)
		else:
			amount = maxf(0.0, amount)
			
	data.current_amount = amount
	data.final_amount = roundi(amount)
