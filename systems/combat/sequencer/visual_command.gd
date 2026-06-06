class_name VisualCommand
extends RefCounted

## Donnée de transfert pure. Ne contient aucune logique métier.

enum Type {
	PLAY_ANIMATION,
	FORCED_MOVEMENT,
	SPAWN_VFX,
	DAMAGE_NUMBER
}

var type: Type
var target: Node3D
var target_hex: Vector3i
var string_payload: String
var int_payload: int
var duration: float = 0.25
var position_payload: Vector3
var direction_payload: Vector3
