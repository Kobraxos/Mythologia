class_name AIAction
extends Resource

# SIGNALS
signal finished()

# EXPORTS
@export var heuristics: Array[AIHeuristic] = []

# PUBLIC FUNCTIONS
## Calcule l'utilité globale de cette action par la multiplication de ses heuristiques (Standard AAA).
func calculate_score(context: AIContext) -> float:
	if heuristics.is_empty():
		return 0.0
		
	var total_score: float = 1.0
	for heuristic: AIHeuristic in heuristics:
		if heuristic:
			total_score *= clampf(heuristic.evaluate(context), 0.0, 1.0)
	return total_score

## Déclenche les conséquences de cette action (ex: appel de unit.execute_path ou émission de CombatEvents.skill_cast_requested).
## À surcharger (override) dans les scripts enfants.
func execute(_context: AIContext) -> void:
	push_error("AIAction.execute() n'est pas implémenté.")
	finished.emit()