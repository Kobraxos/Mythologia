class_name StatusTriggerData
extends Resource

## Définit l'événement de jeu que ce déclencheur écoute.
enum TriggerEvent {
	ON_APPLIED, ## Lorsque le statut est appliqué pour la première fois.
	ON_REMOVED, ## Lorsque le statut est retiré (fin de durée, dissipation, consommé).
	ON_TURN_START, ## Au début du tour du porteur.
	ON_TURN_END, ## À la fin du tour du porteur.
	ON_DAMAGE_TAKEN, ## Lorsque le porteur subit des dégâts.
	ON_DEATH_PREVENTED, ## Déclencheur spécial pour les statuts qui empêchent la mort.
	ON_ACTION_USED, ## Lorsque le porteur utilise une compétence ou une attaque.
	ON_MOVED, ## Lorsque le porteur change de case sur la grille.
}

enum TriggerCondition {
	ALWAYS,
	ELEVATION_GREATER_THAN_ZERO,
	TARGET_HP_BELOW_HALF,
	SOURCE_HAS_LINE_OF_SIGHT ## Le créateur du statut a une ligne de vue directe sur le porteur au moment du déclenchement.
}

@export_category("Trigger")
@export var trigger_event: TriggerEvent = TriggerEvent.ON_APPLIED
## Probabilité que le déclencheur s'active (1.0 = 100%, 0.5 = 50%).
@export var trigger_chance: float = 1.0
## Condition contextuelle supplémentaire requise pour le déclenchement.
@export var condition: TriggerCondition = TriggerCondition.ALWAYS
## Compétence à exécuter lorsque ce déclencheur est activé.
## Le CombatManager la centrera sur le porteur du statut.
@export var triggered_skill: SkillData
