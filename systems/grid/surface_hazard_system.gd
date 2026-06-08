class_name SurfaceHazardSystem
extends Node

func _ready() -> void:
	if TurnEvents.has_signal("turn_started"):
		TurnEvents.turn_started.connect(_on_turn_started)
	if TurnEvents.has_signal("round_ended"):
		TurnEvents.round_ended.connect(_on_round_ended)

## Applique aveuglément les statuts toxiques/brûlures à l'unité en début de tour
func _on_turn_started(unit: Unit) -> void:
	var hex: Vector3i = unit.current_hex
	var surface: TerrainData = GridManager.surface_tiles.get(hex)
	if not surface:
		return
		
	# Typage strict pour les composants
	if unit.status_receiver:
		for status_res: Resource in surface.applied_status_effects:
			var status := status_res as StatusEffectData # StatusEffectData n'est peut-être pas la classe exacte, on fait confiance au cast
			if status:
				unit.status_receiver.apply_status(status)

## Gère le cycle de vie (Théorie Mythologique : 0 = éternel, >0 = décrémente)
func _on_round_ended() -> void:
	var hexes_to_remove: Array[Vector3i] = []
	
	for hex: Vector3i in GridManager.surface_durations.keys():
		var duration: int = GridManager.surface_durations[hex]
		# 0 signifie que la surface est éternelle
		if duration > 0:
			duration -= 1
			GridManager.surface_durations[hex] = duration
			if duration <= 0:
				hexes_to_remove.append(hex)
				
	for hex: Vector3i in hexes_to_remove:
		GridManager.remove_surface(hex)
