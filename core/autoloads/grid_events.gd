extends Node

@warning_ignore("unused_signal")
## Émis lorsque le joueur clique sur un hexagone valide du plateau.
signal hex_clicked(hex_coord: Vector3i)

@warning_ignore("unused_signal")
signal unit_selected(unit: Unit)

@warning_ignore("unused_signal")
signal unit_deselected()

@warning_ignore("unused_signal")
## Émis lors de la visée d'une compétence pour afficher la zone affectée.
signal aoe_targeted(hexes: Array[Vector3i])

@warning_ignore("unused_signal")
## Émis pour effacer l'affichage de la zone d'effet (ex: annulation de la visée).
signal aoe_cleared()

@warning_ignore("unused_signal")
## Émis lors du ciblage de déplacement pour afficher les cases accessibles.
signal movement_targeted(hexes: Array[Vector3i])

@warning_ignore("unused_signal")
## Émis pour effacer l'affichage des cases de déplacement.
signal movement_cleared()

@warning_ignore("unused_signal")
## Émis au survol d'une case valide pour prévisualiser le chemin de déplacement.
signal movement_path_targeted(path_hexes: Array[Vector3i])

@warning_ignore("unused_signal")
## Émis pour effacer la prévisualisation du chemin.
signal movement_path_cleared()

@warning_ignore("unused_signal")
## Émis lors de la visée d'une compétence pour afficher les cases valides depuis lesquelles on peut cibler.
signal skill_range_targeted(hexes: Array[Vector3i])

@warning_ignore("unused_signal")
## Émis lorsqu'une compétence est ciblée depuis une position planifiée (Ghost Stance).
signal ghost_stance_activated(planned_hex: Vector3i)

@warning_ignore("unused_signal")
## Émis pour effacer l'affichage du Ghost Stance.
signal ghost_stance_cleared()

@warning_ignore("unused_signal")
## Émis pour effacer l'affichage de la portée d'une compétence.
signal skill_range_cleared()

@warning_ignore("unused_signal")
## Émis lorsqu'une unité apparaît sur le plateau (utile pour initialiser les UI).
signal unit_spawned(unit: Node3D)
