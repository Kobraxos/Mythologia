class_name SkillEffectPayload
extends Resource

enum PayloadTarget { MAIN_TARGET, CASTER, ALL_IN_AOE, ENEMIES_IN_AOE, ALLIES_IN_AOE }

## Conditions de déclenchement dynamiques lues par le CombatManager.
enum TriggerCondition {
	ALWAYS,
	CASTER_HP_LOWER_THAN_TARGET,
	CASTER_HP_HIGHER_THAN_TARGET,
	TARGET_ELEVATION_LOWER,
	TARGET_ELEVATION_HIGHER,
	TARGET_HAS_SPECIFIC_STATUS,
	ON_KILL
}

@export_category("Payload Delivery")
@export var target: PayloadTarget = PayloadTarget.MAIN_TARGET
## Chances d'appliquer l'effet (1.0 = 100%).
@export var application_chance: float = 1.0

@export_category("Conditional Logic")
@export var condition: TriggerCondition = TriggerCondition.ALWAYS
## L'ID du statut requis sur la cible si la condition est TARGET_HAS_SPECIFIC_STATUS (ex: &"wet").
@export var required_status_id: StringName = &""

@export_category("Payload Content")
@export var status_effect: StatusEffectData
