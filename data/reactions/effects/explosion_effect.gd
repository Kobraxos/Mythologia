class_name ExplosionEffect
extends ReactionEffectData

@export_category("Dégâts de l'Explosion")
@export var damage_base: float = 10.0
@export var damage_mythic_scaling: float = 1.5
@export_enum("NONE", "FIRE", "WATER", "ICE", "LIGHTNING", "EARTH", "POISON", "LIGHT", "SHADOW") var element: int = 1 # FIRE

@export_category("Visuels")
@export var vfx_id: StringName = &"poison_explosion"

func execute(hex: Vector3i, caster: Unit, triggering_skill: SkillData) -> bool:
	# 1. Émission du VFX
	if vfx_id != &"":
		GridEvents.elemental_reaction_triggered.emit(hex, vfx_id)
	
	# 2. Résolution des dégâts via la Pipeline AAA
	var target_node: Node3D = GridManager.unit_positions.get(hex)
	if target_node and target_node is Unit:
		var target_unit := target_node as Unit
		
		var dmg_data := DamageData.new(caster, target_unit, triggering_skill)
		
		var base_dmg: float = damage_base
		if caster and caster.get("stats") != null:
			# Récompense les statistiques Mythiques du lanceur
			base_dmg = max(damage_base, float(caster.stats.base_mythic_damage) * damage_mythic_scaling)
			
		dmg_data.base_amount = base_dmg
		dmg_data.is_mythic = true
		dmg_data.element = element
		
		if caster and caster.get("stats") != null:
			var crit_chance: float = caster.stats.base_crit_chance
			if randf() <= crit_chance:
				dmg_data.is_critical = true
			
		DamagePipeline.calculate_and_apply(dmg_data)
		
	return false
