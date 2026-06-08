class_name ReactionData
extends Resource

@export_category("Conditions de Déclenchement")
## L'élément de l'attaque qui frappe la case (ex: FEU)
@export_enum("NONE", "FIRE", "WATER", "ICE", "LIGHTNING", "EARTH", "POISON", "LIGHT", "SHADOW") var trigger_element: int = 0

## L'élément inhérent de la surface/terrain ciblée (ex: POISON)
@export_enum("NONE", "FIRE", "WATER", "ICE", "LIGHTNING", "EARTH", "POISON", "LIGHT", "SHADOW") var target_surface_element: int = 0

@export_category("Composition d'Effets (Payload)")
## Liste modulaire des conséquences (Explosion, Changement de Surface, Statuts, etc.)
## Ces effets seront exécutés séquentiellement.
@export var effects: Array[ReactionEffectData] = []
