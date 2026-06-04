extends Node

# SIGNALS
## Émis quand le combat est officiellement prêt à démarrer.
signal battle_started()
## Émis quand le numéro du round change (toutes les unités ont joué).
signal round_changed(round_num: int)
## Émis quand c'est au tour d'une nouvelle unité de jouer.
signal active_unit_changed(unit: Unit)
## Émis quand le tour de l'unité précédente est formellement terminé.
signal turn_ended(unit: Unit)
## Émis par le Contrôleur (Input) pour demander la fin du tour actuel.
signal turn_end_requested()