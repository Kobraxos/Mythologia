class_name GridFeatureNode
extends Resource

@export_category("Feature Node")
## Coordonnée axiale (X) relative au centre du tampon (0,0)
@export var relative_q: int = 0
## Coordonnée axiale (Y) relative au centre du tampon (0,0)
@export var relative_r: int = 0
## Décalage de hauteur (Z) relatif au centre du tampon
@export var height_offset: int = 0
## Le rôle de ce terrain, qui sera traduit via la BiomePalette
@export var role: BiomePalette.TerrainRole = BiomePalette.TerrainRole.BASE
