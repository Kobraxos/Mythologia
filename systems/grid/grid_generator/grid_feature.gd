class_name GridFeature
extends Resource
## Ressource définissant une structure ou un motif de terrain ("Stamp") à appliquer 
## lors de la génération procédurale de la grille (ex: une ruine, une colline spécifique).

@export_category("Grid Feature (Stamp)")
@export var feature_name: String = "Nouvelle Structure"
## Liste de toutes les cases constituant cette structure
@export var nodes: Array[GridFeatureNode] = []
