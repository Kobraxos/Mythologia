extends Node

@warning_ignore("unused_signal")
## Émis lorsque le joueur clique sur un hexagone valide du plateau.
signal hex_clicked(hex_coord: Vector3i)

@warning_ignore("unused_signal")
signal unit_selected(unit : Unit, reachable_hexes: Array[Vector3i])

@warning_ignore("unused_signal")
signal unit_deselected()

@warning_ignore("unused_signal")
## Émis lors de la visée d'une compétence pour afficher la zone affectée.
signal aoe_targeted(hexes: Array[Vector3i])

@warning_ignore("unused_signal")
## Émis pour effacer l'affichage de la zone d'effet (ex: annulation de la visée).
signal aoe_cleared()
