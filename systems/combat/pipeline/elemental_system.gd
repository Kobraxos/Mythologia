extends Node

@export_category("Configuration Data-Driven")
## Glissez-déposez ici toutes les ressources `ReactionData` du jeu (ex: depuis data/reactions/)
@export var reactions: Array[ReactionData] = []

## Dictionnaire O(1) pour l'accès instantané aux réactions. Clé: String, Valeur: ReactionData
var _reaction_map: Dictionary = {}

func _ready() -> void:
	for reaction: ReactionData in reactions:
		if not reaction:
			continue
		# Création d'une clé unique O(1) basée sur la suggestion du Lead Dev
		var key: String = str(reaction.trigger_element) + "_" + str(reaction.target_surface_element)
		_reaction_map[key] = reaction

## Traite l'impact d'un sort sur une case et arbitre les réactions chimiques de façon 100% Data-Driven.
func process_elemental_impact(hex: Vector3i, element: CoreEnums.Element, caster: Unit, skill: SkillData) -> void:
	if element == CoreEnums.Element.NONE:
		return
		
	var active_terrain: TerrainData = GridManager.get_active_terrain(hex)
	if not active_terrain:
		return
		
	var target_element: CoreEnums.Element = active_terrain.terrain_element
	if target_element == CoreEnums.Element.NONE:
		return
		
	var key: String = str(element) + "_" + str(target_element)
	
	if _reaction_map.has(key):
		var reaction: ReactionData = _reaction_map[key]
		# Exécution séquentielle de la composition d'effets
		for effect: ReactionEffectData in reaction.effects:
			if not effect:
				continue
			var interrupt: bool = effect.execute(hex, caster, skill)
			if interrupt:
				# Si un effet consomme formellement la surface ou interrompt la chaîne, on s'arrête.
				break
	else:
		# Fail-silent gracieux si aucune réaction n'est configurée (ex: Eau sur Pierre)
		pass

