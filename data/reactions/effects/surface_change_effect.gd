class_name SurfaceChangeEffect
extends ReactionEffectData

@export_category("Altération de Surface")
## La surface qui remplace l'ancienne (Laisser vide si la surface est juste détruite).
@export var new_surface: TerrainData

## Si Vrai, cet effet consomme (retire) la surface actuelle avant d'en placer une nouvelle.
@export var consumes_surface: bool = true

func execute(hex: Vector3i, _caster: Unit, _triggering_skill: SkillData) -> bool:
	if consumes_surface:
		GridManager.remove_surface(hex)
		
	if new_surface:
		if new_surface.is_surface:
			GridManager.add_surface(hex, new_surface)
		else:
			# Remplacement radical du terrain de base (ex: destruction structurelle)
			GridManager.terrain_tiles[hex] = new_surface
			GridEvents.grid_topology_ready.emit(GridManager.terrain_tiles)
			
	return consumes_surface
