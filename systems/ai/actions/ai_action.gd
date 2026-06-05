class_name AIAction
extends Resource

# EXPORTS
@export var heuristics: Array[AIHeuristic] = []

# PUBLIC FUNCTIONS
## Calcule l'utilité globale de cette action en sommant/multipliant ses heuristiques.
func calculate_score(context: AIContext) -> float:
	var total_score: float = 0.0
	for heuristic: AIHeuristic in heuristics:
		if heuristic:
			total_score += heuristic.evaluate(context)
	return total_score

## Déclenche les conséquences de cette action (ex: appel de unit.execute_path ou émission de CombatEvents.skill_cast_requested).
## À surcharger (override) dans les scripts enfants.
func execute(context: AIContext) -> void:
	push_error("AIAction.execute() n'est pas implémenté.")
	# Par défaut, passe le tour en cas d'erreur
	TurnEvents.turn_end_requested.emit()