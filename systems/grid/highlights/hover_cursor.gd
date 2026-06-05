class_name HoverCursor
extends Node3D

# CONSTANTS
## Élévation légère (en mètres) pour éviter le Z-Fighting (scintillement) avec le maillage du sol.
const Y_OFFSET: float = 0.05

# GODOT BUILT-IN FUNCTIONS
func _ready() -> void:
	# Le AAA exige un découplage total : on écoute passivement le bus global
	GridEvents.hex_hovered.connect(_on_hex_hovered)
	
	# L'état initial du curseur doit être inactif (invisible)
	hide()

# SIGNAL HANDLERS
func _on_hex_hovered(hex_coord: Vector3i) -> void:
	# Guard Clause : Si la souris pointe en dehors du plateau valide
	if hex_coord == GridController.INVALID_HEX:
		hide()
		return
		
	# Le survol est valide, on active le maillage
	show()
	
	# Projection mathématique de la couche logique (Vector3i) vers la couche physique (Vector3)
	var world_pos: Vector3 = HexMath.hex_to_world(hex_coord, GridManager.hex_size, GridManager.elevation_step)
	
	# Mise à jour absolue de la position (sans moteur physique)
	global_position = world_pos + Vector3(0, Y_OFFSET, 0)