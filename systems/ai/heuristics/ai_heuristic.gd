class_name AIHeuristic
extends Resource

# PUBLIC FUNCTIONS
## Évalue le contexte actuel de l'unité et renvoie un score (généralement entre 0.0 et 1.0).
## À surcharger (override) dans les scripts enfants.
func evaluate(context: AIContext) -> float:
	push_error("AIHeuristic.evaluate() n'est pas implémenté.")
	return 0.0