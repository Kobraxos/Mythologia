extends Node

@warning_ignore("unused_signal")
## Émis lorsque le joueur clique sur un hexagone valide du plateau.
signal hex_clicked(hex_coord: Vector3i)

@warning_ignore("unused_signal")
signal unit_selected(unit : Unit, reachable_hexes: Array[Vector3i])

@warning_ignore("unused_signal")
signal unit_deselected()
