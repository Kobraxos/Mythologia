extends Node

# SIGNALS
@warning_ignore("unused_signal")
## Demande l'exécution d'une compétence. Intercepté par le CombatManager.
signal skill_cast_requested(caster: Node3D, skill: SkillData, target_hex: Vector3i)

@warning_ignore("unused_signal")
## Émis quand des dégâts sont infligés (pour l'UI et les Floating Texts).
signal damage_dealt(target: Node3D, amount: int, is_crit: bool)

@warning_ignore("unused_signal")
## Émis quand des soins sont prodigués.
signal healing_done(target: Node3D, amount: int)

@warning_ignore("unused_signal")
## Émis par l'UI lorsqu'un joueur clique sur un bouton de sort. Intercepté par le GridController.
signal skill_button_clicked(skill: SkillData)