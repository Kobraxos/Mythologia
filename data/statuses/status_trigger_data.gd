class_name StatusTriggerData
extends Resource



@export_category("Trigger")
@export_enum("ON_APPLIED", "ON_REMOVED", "ON_TURN_START", "ON_TURN_END", "ON_DAMAGE_TAKEN", "ON_DEATH_PREVENTED", "ON_ACTION_USED", "ON_MOVED") var trigger_event: int = 0
## Probabilité que le déclencheur s'active (1.0 = 100%, 0.5 = 50%).
@export var trigger_chance: float = 1.0
## Condition contextuelle supplémentaire requise pour le déclenchement.
@export_enum("ALWAYS", "ELEVATION_GREATER_THAN_ZERO", "TARGET_HP_BELOW_HALF", "SOURCE_HAS_LINE_OF_SIGHT") var condition: int = 0
## Compétence à exécuter lorsque ce déclencheur est activé.
## Le CombatManager la centrera sur le porteur du statut.
@export var triggered_skill: SkillData
