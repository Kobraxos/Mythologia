class_name SpawnPoint
extends Marker3D

@export var stats: UnitStats
@export var faction: Unit.Faction = Unit.Faction.PLAYER

# Le marqueur n'a pas de logique au runtime, il agit uniquement 
# comme un conteneur de données spatial et typé pour le BattleManager.
