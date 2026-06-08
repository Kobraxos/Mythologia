class_name ReactionEffectData
extends Resource

## Exécute l'effet de cette réaction sur la grille.
## Retourne Vrai si l'effet interrompt formellement le reste de la chaîne de la réaction courante.
func execute(_hex: Vector3i, _caster: Unit, _triggering_skill: SkillData) -> bool:
	return false
