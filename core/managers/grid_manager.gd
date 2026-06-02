extends Node

# PUBLIC VARIABLES

## Référence globale au pathfinder actuel de la scène.
var pathfinder: HexPathfinder

## Registre spatial des unités. Clé: Vector3i, Valeur: Unit
var unit_positions: Dictionary[Vector3i, Unit] = {}
