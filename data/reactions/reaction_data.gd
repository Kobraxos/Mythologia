class_name ReactionData
extends Resource

@export_category("Conditions de Déclenchement")
## L'élément de l'attaque qui frappe la case (ex: FEU)
@export var trigger_element: SkillData.Element = SkillData.Element.NONE

## L'élément inhérent de la surface/terrain ciblée (ex: POISON)
@export var target_surface_element: SkillData.Element = SkillData.Element.NONE

@export_category("Composition d'Effets (Payload)")
## Liste modulaire des conséquences (Explosion, Changement de Surface, Statuts, etc.)
## Ces effets seront exécutés séquentiellement.
@export var effects: Array[ReactionEffectData] = []
