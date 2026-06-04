class_name StatusModifierData
extends Resource

## La statistique ciblée par ce modificateur.
@export var stat: StatManagerComponent.StatType

## Le type mathématique (Addition fixe ou Pourcentage).
@export var type: StatManagerComponent.ModifierType

## La valeur à appliquer (ex: 2.0 pour un FLAT de +2, ou 0.5 pour un PERCENT de +50%).
@export var value: float