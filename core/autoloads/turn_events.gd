extends Node

# SIGNALS
@warning_ignore("unused_signal")
## Émis quand le combat est officiellement prêt à démarrer.
signal battle_started()

@warning_ignore("unused_signal")
## Émis quand le numéro du round change (toutes les unités ont joué).
signal round_changed(round_num: int)

@warning_ignore("unused_signal")
## Émis quand c'est au tour d'une nouvelle unité de jouer.
signal active_unit_changed(unit: Unit)

@warning_ignore("unused_signal")
## Émis quand le tour de l'unité précédente est formellement terminé.
signal turn_ended(unit: Unit)

@warning_ignore("unused_signal")
## Émis par le Contrôleur (Input) pour demander la fin du tour actuel.
signal turn_end_requested()

@warning_ignore("unused_signal")
## Émis par le Domaine pour mettre à jour l'UI de la Timeline avec l'ordre des prochains tours.
## queue: La liste des unités.
## round_breaks: Une liste d'indices indiquant APRES quel portrait un nouveau round commence.
signal timeline_updated(queue: Array[Unit], round_breaks: Array[int])