class_name HighlightManager
extends Node3D

# CONSTANTS
## Décalage vertical pour empêcher le Z-Fighting (clignotement) avec la tuile de sol.
const Z_FIGHTING_OFFSET: float = 0.05

# EXPORTS
@export_category("Prefabs")
## Le modèle 3D affiché pour les cases de déplacement accessibles (ex: Vert).
@export var move_highlight_prefab: PackedScene
## Le modèle 3D affiché pour les cases affectées par une compétence (ex: Rouge).
@export var attack_highlight_prefab: PackedScene
## Le modèle 3D affiché pour la portée d'une compétence (ex: Bordure Bleue).
@export var range_highlight_prefab: PackedScene
## Le modèle 3D affiché pour les étapes du chemin de déplacement (ex: Petit point blanc).
@export var path_highlight_prefab: PackedScene
## Le modèle 3D affiché pour relier les points du chemin (ex: Faisceau/Ligne dorée).
@export var path_line_prefab: PackedScene
## Le modèle 3D affiché pour représenter l'origine simulée (Ghost Stance).
@export var ghost_highlight_prefab: PackedScene

# PRIVATE VARIABLES
var _move_pool: Array[Node3D] = []
var _attack_pool: Array[Node3D] = []
var _range_pool: Array[Node3D] = []
var _path_pool: Array[Node3D] = []
var _path_line_pool: Array[Node3D] = []
var _ghost_pool: Array[Node3D] = []

# GODOT BUILT-IN FUNCTIONS
func _ready() -> void:
	GridEvents.unit_deselected.connect(_on_unit_deselected)
	
	if GridEvents.has_signal("movement_targeted"):
		GridEvents.movement_targeted.connect(_on_movement_targeted)
	if GridEvents.has_signal("movement_cleared"):
		GridEvents.movement_cleared.connect(_on_movement_cleared)
		
	if GridEvents.has_signal("movement_path_targeted"):
		GridEvents.movement_path_targeted.connect(_on_movement_path_targeted)
	if GridEvents.has_signal("movement_path_cleared"):
		GridEvents.movement_path_cleared.connect(_on_movement_path_cleared)
		
	if GridEvents.has_signal("skill_range_targeted"):
		GridEvents.skill_range_targeted.connect(_on_skill_range_targeted)
	if GridEvents.has_signal("skill_range_cleared"):
		GridEvents.skill_range_cleared.connect(_on_skill_range_cleared)
		
	if GridEvents.has_signal("ghost_stance_activated"):
		GridEvents.ghost_stance_activated.connect(_on_ghost_stance_activated)
	if GridEvents.has_signal("ghost_stance_cleared"):
		GridEvents.ghost_stance_cleared.connect(_on_ghost_stance_cleared)
		
	# AAA Fix : has_user_signal ne détecte que les signaux dynamiques. has_signal détecte les signaux déclarés.
	if GridEvents.has_signal("aoe_targeted"):
		GridEvents.aoe_targeted.connect(_on_aoe_targeted)
	if GridEvents.has_signal("aoe_cleared"):
		GridEvents.aoe_cleared.connect(_on_aoe_cleared)

# SIGNAL HANDLERS
func _on_movement_targeted(reachable_hexes: Array[Vector3i]) -> void:
	_on_movement_cleared()
	if not move_highlight_prefab:
		push_error("HighlightManager: 'move_highlight_prefab' manquant.")
		return
		
	_display_hexes(reachable_hexes, _move_pool, move_highlight_prefab)
	
func _on_movement_path_targeted(path_hexes: Array[Vector3i]) -> void:
	_on_movement_path_cleared()
	if not path_highlight_prefab:
		push_error("HighlightManager: 'path_highlight_prefab' manquant.")
		return
	# AAA : is_path = true (Applique un décalage Y pour flotter au-dessus du sol vert)
	_display_hexes(path_hexes, _path_pool, path_highlight_prefab, false, true)
	
	# AAA : Génération du Fil d'Ariane continu (Segments)
	if not path_line_prefab or path_hexes.size() < 2:
		return
		
	# AAA : Segment Splitting - 2 segments par déplacement pour éviter de traverser le sol
	var needed_lines: int = (path_hexes.size() - 1) * 2
	while _path_line_pool.size() < needed_lines:
		var mesh: Node3D = path_line_prefab.instantiate() as Node3D
		add_child(mesh)
		mesh.visible = false
		_path_line_pool.append(mesh)
		
	for i in range(path_hexes.size() - 1):
		var p1: Vector3 = HexMath.hex_to_world(path_hexes[i], GridManager.hex_size, GridManager.elevation_step)
		var p2: Vector3 = HexMath.hex_to_world(path_hexes[i+1], GridManager.hex_size, GridManager.elevation_step)
		p1.y += Z_FIGHTING_OFFSET + 0.05
		p2.y += Z_FIGHTING_OFFSET + 0.05
		
		# AAA : Calcul du point d'articulation (sur l'arête mitoyenne)
		var mid_p: Vector3 = (p1 + p2) / 2.0
		# Le secret : L'arête prend l'élévation de la case la plus haute pour faire un "pont"
		mid_p.y = maxf(p1.y, p2.y)
		
		# Segment 1 : Case de départ -> Arête mitoyenne
		var line1: Node3D = _path_line_pool[i * 2]
		line1.position = (p1 + mid_p) / 2.0 
		line1.look_at(mid_p, Vector3.UP)    
		line1.scale = Vector3(1, 1, p1.distance_to(mid_p)) 
		line1.visible = true
		
		# Segment 2 : Arête mitoyenne -> Case d'arrivée
		var line2: Node3D = _path_line_pool[i * 2 + 1]
		line2.position = (mid_p + p2) / 2.0 
		line2.look_at(p2, Vector3.UP)    
		line2.scale = Vector3(1, 1, mid_p.distance_to(p2)) 
		line2.visible = true

func _on_movement_path_cleared() -> void:
	_hide_pool(_path_pool)
	_hide_pool(_path_line_pool)

func _on_movement_cleared() -> void:
	_hide_pool(_move_pool)
	_on_movement_path_cleared()

func _on_unit_deselected() -> void:
	_on_movement_cleared()
	_on_aoe_cleared()
	_on_skill_range_cleared()
	_on_ghost_stance_cleared()

func _on_aoe_targeted(hexes: Array[Vector3i]) -> void:
	_on_aoe_cleared()
	
	if not attack_highlight_prefab:
		push_error("HighlightManager: 'attack_highlight_prefab' manquant.")
		return
		
	_display_hexes(hexes, _attack_pool, attack_highlight_prefab)

func _on_aoe_cleared() -> void:
	_hide_pool(_attack_pool)

func _on_skill_range_targeted(hexes: Array[Vector3i]) -> void:
	_on_skill_range_cleared()
	if not range_highlight_prefab:
		push_error("HighlightManager: 'range_highlight_prefab' manquant.")
		return
	# AAA : On active le décalage Y supplémentaire pour éviter le Z-Fighting avec l'AoE rouge
	_display_hexes(hexes, _range_pool, range_highlight_prefab, true)

func _on_skill_range_cleared() -> void:
	_hide_pool(_range_pool)

func _on_ghost_stance_activated(planned_hex: Vector3i) -> void:
	_on_ghost_stance_cleared()
	if not ghost_highlight_prefab:
		if path_highlight_prefab: # Fallback élégant si aucun prefab de ghost n'est fourni
			_display_hexes([planned_hex], _ghost_pool, path_highlight_prefab, false, true)
		return
		
	_display_hexes([planned_hex], _ghost_pool, ghost_highlight_prefab, false, true)

func _on_ghost_stance_cleared() -> void:
	_hide_pool(_ghost_pool)

# PRIVATE FUNCTIONS
func _display_hexes(hexes: Array[Vector3i], pool: Array[Node3D], prefab: PackedScene, is_range: bool = false, is_path: bool = false) -> void:
	while pool.size() < hexes.size():
		var mesh: Node3D = prefab.instantiate() as Node3D
		add_child(mesh)
		mesh.visible = false
		pool.append(mesh)

	for i in range(hexes.size()):
		var hex: Vector3i = hexes[i]
		var mesh: Node3D = pool[i]
		
		var world_pos: Vector3 = HexMath.hex_to_world(hex, GridManager.hex_size, GridManager.elevation_step)
		world_pos.y += Z_FIGHTING_OFFSET 
		
		if is_range:
			world_pos.y -= 0.01 # Place la portée très légèrement sous la zone d'effet
		elif is_path:
			world_pos.y += 0.05 # Place le point de chemin légèrement au-dessus de la zone verte
			
		mesh.position = world_pos
		mesh.visible = true

func _hide_pool(pool: Array[Node3D]) -> void:
	for mesh: Node3D in pool:
		if is_instance_valid(mesh):
			mesh.visible = false