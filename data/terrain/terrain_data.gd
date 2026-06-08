class_name TerrainData
extends Resource

@export_category("Identity & Visuals")
## Détermine si ce terrain est une surface volatile (ex: Flaque de feu, gaz empoisonné) ou le sol structurel de base.
@export var is_surface: bool = false
@export_group("Surface Lifecycle")
## Durée de vie en tours de la surface. 0 = infinie. Valable uniquement si is_surface = true.
@export var duration_turns: int = 0

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
@export_enum("NONE", "FIRE", "WATER", "ICE", "LIGHTNING", "EARTH", "POISON", "LIGHT", "SHADOW") var terrain_element: int = 0
## Liste des éléments qui se propagent instantanément sur les cases adjacentes partageant ce terrain (ex: Foudre sur l'Eau).
@export var conducts_elements: Array[int] = []
