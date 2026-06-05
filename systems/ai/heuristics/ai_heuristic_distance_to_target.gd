class_name AIHeuristicDistanceToTarget
extends AIHeuristic

@export_category("Distance Scoring")
## La distance (en hexagones) au-delà de laquelle le score sera cappé (ex: 100% d'envie).
@export var max_expected_distance: float = 15.0
## Vrai = Favorise l'approche (Renvoie 1.0 quand la cible est loin).
## Faux = Favorise la fuite/le kiting (Renvoie 1.0 quand la cible est au contact).
@export var higher_score_when_far: bool = true

# PUBLIC FUNCTIONS
func evaluate(context: AIContext) -> float:
	var unit: Unit = context.unit
	if not is_instance_valid(unit):
		return 0.0
		
	var start_hex: Vector3i = context.current_hex
	var min_dist: int = 999999
	var found_enemy: bool = false
	
	for hex: Vector3i in GridManager.unit_positions:
		var target_node: Node3D = GridManager.unit_positions.get(hex)
		if not target_node or not target_node is Unit:
			continue
			
		var target_unit := target_node as Unit
		if not is_instance_valid(target_unit) or target_unit == unit:
			continue
			
		if target_unit.faction != unit.faction:
			var dist: int = HexMath.distance_2d(start_hex, hex)
			if dist < min_dist:
				min_dist = dist
				found_enemy = true
				
	if not found_enemy:
		return 0.0
		
	var normalized_dist: float = clampf(float(min_dist) / max_expected_distance, 0.0, 1.0)
	
	return normalized_dist if higher_score_when_far else (1.0 - normalized_dist)