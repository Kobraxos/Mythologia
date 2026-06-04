class_name TerrainData
extends Resource

@export_category("Identity & Visuals")
@export var id: StringName = &""
@export var terrain_name: String = "Unknown Terrain"
@export_multiline var description: String = ""
@export var icon: Texture2D
## Scène 3D instanciée pour représenter cette case (Mesh + Particules éventuelles).
@export var visual_prefab: PackedScene

@export_category("Grid Physics (A*)")
## Détermine si une unité peut s'arrêter ou marcher sur cette case.
@export var is_walkable: bool = true
## Coût en Points de Mouvement (PM) pour entrer sur cette case.
@export var movement_cost: int = 1
## Détermine si ce terrain bloque le calcul de la Ligne de Vue (LoS) au même niveau de hauteur Z.
@export var blocks_line_of_sight: bool = false

@export_category("Hazards & Status")
## Liste des altérations appliquées automatiquement aux unités entrant ou terminant leur tour sur cette case (ex: Poison, Brûlure).
@export var applied_status_effects: Array[Resource] = []

@export_category("Elemental System (Systemic Gameplay)")
## L'élément inhérent de ce terrain (utile pour les immunités ou les réactions conditionnelles).
@export var terrain_element: SkillData.Element = SkillData.Element.NONE
## Liste des éléments qui se propagent instantanément sur les cases adjacentes partageant ce terrain (ex: Foudre sur l'Eau).
@export var conducts_elements: Array[SkillData.Element] = []

@export_group("Elemental Transformations")
## Terrain de remplacement généré si ce terrain est frappé par une attaque de type FEU (ex: Herbe -> Cendre). Injecter une ressource TerrainData.
@export var transform_on_fire: Resource
## Terrain de remplacement généré si ce terrain est frappé par une attaque de type GLACE (ex: Eau -> Glace). Injecter une ressource TerrainData.
@export var transform_on_ice: Resource
## Terrain de remplacement généré si ce terrain est frappé par une attaque de type EAU (ex: Lave -> Obsidienne). Injecter une ressource TerrainData.
@export var transform_on_water: Resource
## Terrain de remplacement généré si ce terrain est frappé par une attaque de type FOUDRE. Injecter une ressource TerrainData.
@export var transform_on_lightning: Resource