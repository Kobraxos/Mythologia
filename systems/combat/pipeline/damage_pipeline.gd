class_name DamagePipeline
extends RefCounted

## L'arbitre ultime des dégâts et soins de Mythologia (Pipeline AAA).
## Calcule la valeur finale en passant par plusieurs filtres (buffs, armure, résistances).

static var damage_steps: Array[PipelineStep] = []
static var healing_steps: Array[PipelineStep] = []
static var shielding_steps: Array[PipelineStep] = []

static func _static_init() -> void:
	var hit_roll := HitRollStep.new()
	var source_mods := SourceModifiersStep.new()
	var scaling := ContextualScalingStep.new()
	var target_mods := TargetModifiersStep.new()
	var variance := VarianceStep.new()
	var application := ApplicationStep.new()
	
	damage_steps = [hit_roll, source_mods, scaling, target_mods, variance, application]
	healing_steps = [source_mods, target_mods, variance, application]
	shielding_steps = [source_mods, target_mods, variance, application]

static func calculate_and_apply(data: DamageData) -> void:
	if not data.target or not data.target.health_component:
		return
		
	# Initialise current_amount à base_amount pour le parcours des étapes
	data.initialize_amounts(data.base_amount)
		
	var steps: Array[PipelineStep] = []
	
	if data.is_healing:
		steps = healing_steps
	elif data.is_shielding:
		steps = shielding_steps
	else:
		steps = damage_steps
		
	for step: PipelineStep in steps:
		step.apply(data)
		# AAA : Guard clause prématurée si le coup est annulé
		if data.is_dodged or data.final_amount == 0:
			break
