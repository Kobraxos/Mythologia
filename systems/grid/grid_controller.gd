class_name GridController
extends Node

# CONSTANTS
## Valeur mathématique représentant l'absence de tuile (le vide absolu).
const INVALID_HEX: Vector3i = Vector3i(0, 0, -999)

# ENUMS
enum State { DEFAULT, SKILL_TARGETING, MOVE_TARGETING }

# EXPORTS
@export var camera: Camera3D

# PRIVATE VARIABLES
var _state: State = State.DEFAULT
var _targeted_skill: SkillData
var _hovered_hex: Vector3i = INVALID_HEX
var _selected_unit: Unit = null
var _reachable_hexes: Array[Vector3i] = []
var _valid_casting_hexes: Array[Vector3i] = []
var _planned_move_hex: Vector3i = INVALID_HEX
## L'unité qui possède l'autorité temporelle (dont c'est le tour).
var _active_turn_unit: Unit = null

# GODOT BUILT-IN FUNCTIONS
func _ready() -> void:
	CombatEvents.skill_button_clicked.connect(_on_skill_button_clicked)
	CombatEvents.move_button_clicked.connect(_on_move_button_clicked)
	TurnEvents.active_unit_changed.connect(_on_active_unit_changed)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		# AAA : Traite le survol (Hover) en permanence pour le curseur visuel global
		_process_hover()
	elif event.is_action_pressed("interact_select"):
		if _state == State.SKILL_TARGETING:
			_confirm_targeting()
		elif _state == State.MOVE_TARGETING:
			_confirm_movement()
		else:
			_perform_raycast()
	elif event.is_action_pressed("interact_cancel"):
		if _state != State.DEFAULT:
			cancel_targeting()
		else:
			_clear_selection()
	elif event.is_action_pressed("tactical_end_turn"):
		if _state == State.DEFAULT:
			if is_instance_valid(_active_turn_unit) and _active_turn_unit.faction == Unit.Faction.PLAYER:
				TurnEvents.turn_end_requested.emit()
		else:
			cancel_targeting()
	elif event.is_action_pressed("tactical_move"):
		_on_move_button_clicked()

# PUBLIC FUNCTIONS
## Annule la préparation (Sort ou Mouvement) et nettoie l'écran.
func cancel_targeting() -> void:
	if _state == State.SKILL_TARGETING:
		_targeted_skill = null
		_valid_casting_hexes.clear()
		_planned_move_hex = INVALID_HEX
		GridEvents.skill_range_cleared.emit()
		GridEvents.aoe_cleared.emit()
		GridEvents.ghost_stance_cleared.emit()
	elif _state == State.MOVE_TARGETING:
		_reachable_hexes.clear()
		GridEvents.movement_path_cleared.emit()
		GridEvents.movement_cleared.emit()
		
	_state = State.DEFAULT
	_hovered_hex = INVALID_HEX

# PRIVATE FUNCTIONS
func _get_hex_under_mouse() -> Vector3i:
	if not camera:
		camera = get_viewport().get_camera_3d()

	if not camera:
		return INVALID_HEX

	var mouse_pos: Vector2 = get_viewport().get_mouse_position()

	var origin: Vector3 = camera.project_ray_origin(mouse_pos)
	var normal: Vector3 = camera.project_ray_normal(mouse_pos)

	# AAA : Ray-Marching Mathématique sur les plans d'élévation (Zéro physique)
	# On teste l'intersection du rayon avec les différents "étages" de la grille, du plus haut vers le bas.
	for z: int in range(GridManager.max_elevation, -1, -1):
		var plane_height: float = z * GridManager.elevation_step
		var plane: Plane = Plane(Vector3.UP, plane_height)
		var hit_pos = plane.intersects_ray(origin, normal)
		
		if hit_pos != null:
			var hex_coord: Vector3i = HexMath.world_to_hex(hit_pos, GridManager.hex_size, GridManager.elevation_step)
			# Si on traverse la colonne d'un hexagone, on vérifie s'il existe une tuile physique à cette hauteur ou au-dessus (clic sur la falaise)
			for test_z: int in range(hex_coord.z, GridManager.max_elevation + 1):
				var check_hex: Vector3i = Vector3i(hex_coord.x, hex_coord.y, test_z)
				if GridManager.terrain_tiles.has(check_hex):
					return check_hex
			
	return INVALID_HEX

func _process_hover() -> void:
	var hex_coord: Vector3i = _get_hex_under_mouse()
	
	# Ne recalculer les maths complexes que si la souris a changé de case hexagonale
	if hex_coord == _hovered_hex:
		return
		
	_hovered_hex = hex_coord
	
	# AAA : Émission de l'événement pur "Fire & Forget" (Découplage visuel)
	GridEvents.hex_hovered.emit(_hovered_hex)
	
	if _state == State.SKILL_TARGETING:
		# AAA : Guard Clause UX - Cache l'AoE si on cible en dehors de la portée valide
		if _hovered_hex == INVALID_HEX or not _valid_casting_hexes.has(_hovered_hex):
			GridEvents.aoe_cleared.emit()
			return
			
		if is_instance_valid(_selected_unit) and _targeted_skill:
			var origin: Vector3i = _planned_move_hex if _planned_move_hex != INVALID_HEX else _selected_unit.current_hex
			var ignored: Vector3i = _selected_unit.current_hex if _planned_move_hex != INVALID_HEX else INVALID_HEX
			var affected: Array[Vector3i] = GridTargeting.get_affected_hexes(origin, _hovered_hex, _targeted_skill, ignored)
			GridEvents.aoe_targeted.emit(affected)
			
	elif _state == State.MOVE_TARGETING:
		# AAA : Guard Clause UX - Cache le chemin si la case survolée n'est pas atteignable
		if _hovered_hex == INVALID_HEX or not _reachable_hexes.has(_hovered_hex):
			GridEvents.movement_path_cleared.emit()
			return
			
		if is_instance_valid(_selected_unit) and GridManager.pathfinder:
			var path: Array[Vector3i] = GridManager.pathfinder.get_hex_path(_selected_unit.current_hex, _hovered_hex, _selected_unit.stats, _selected_unit.faction, GridManager.unit_positions)
			GridEvents.movement_path_targeted.emit(path)

func _confirm_targeting() -> void:
	# AAA : Bloque l'exécution si la cible n'est pas dans la portée
	if _hovered_hex == INVALID_HEX or not _valid_casting_hexes.has(_hovered_hex):
		return
		
	if is_instance_valid(_selected_unit) and _targeted_skill:
		# AAA : Prévention de l'exploit "Teleport Strike" (Ghost Stance)
		if _planned_move_hex != INVALID_HEX:
			# Le joueur tente d'attaquer depuis un hologramme.
			# L'approche "Strict Stance" valide le déplacement d'abord et force une nouvelle visée.
			_move_selected_unit_to(_planned_move_hex)
			cancel_targeting()
			return
			
		# L'unité est physiquement à la bonne place, on lance le sort
		var success: bool = _selected_unit.skill_caster.cast_skill(_targeted_skill, _hovered_hex)
		if success:
			cancel_targeting()

func _confirm_movement() -> void:
	var hex_coord: Vector3i = _get_hex_under_mouse()
	if hex_coord == INVALID_HEX:
		return
		
	if is_instance_valid(_selected_unit) and _reachable_hexes.has(hex_coord):
		_move_selected_unit_to(hex_coord)
		cancel_targeting()

func _move_selected_unit_to(target_hex: Vector3i) -> void:
	if not is_instance_valid(_selected_unit) or not GridManager.pathfinder:
		return

	# CC Guard : Un enracinement ou un étourdissement bloque tout déplacement.
	if _selected_unit.status_receiver:
		if _selected_unit.status_receiver.is_rooted() or _selected_unit.status_receiver.is_stunned():
			return

	var path: Array[Vector3i] = GridManager.pathfinder.get_hex_path(_selected_unit.current_hex, target_hex, _selected_unit.stats, _selected_unit.faction, GridManager.unit_positions)
	if path.is_empty():
		return
		
	if _selected_unit.action_economy:
		var path_cost: int = GridManager.pathfinder.get_path_cost(path, _selected_unit.stats)
		if not _selected_unit.action_economy.has_enough_mp(path_cost):
			return # Mouvement annulé : PM insuffisants.
		_selected_unit.action_economy.consume_mp(path_cost)
		
	_selected_unit.execute_path(path)

func _perform_raycast() -> void:
	var hex_coord: Vector3i = _get_hex_under_mouse()
	if hex_coord == INVALID_HEX:
		return
		
	# Logique d'interaction contextuelle (Déplacement et Sélection)
	if GridManager.unit_positions.has(hex_coord):
		var unit: Unit = GridManager.unit_positions[hex_coord]
		if not unit.stats:
			push_error("GridController: L'unité sélectionnée n'a pas de stats.")
			return
		
		_selected_unit = unit
		
		GridEvents.unit_selected.emit(unit)
	else:
		_clear_selection()

func _clear_selection() -> void:
	GridEvents.unit_deselected.emit()
	_selected_unit = null
	_reachable_hexes.clear()

# SIGNAL HANDLERS
func _on_skill_button_clicked(skill: SkillData) -> void:
	if not is_instance_valid(_selected_unit) or not _selected_unit.skill_caster:
		return

	# AAA : Guard Clause d'Autorité Spatiale
	if _selected_unit.faction != Unit.Faction.PLAYER or _selected_unit != _active_turn_unit:
		return

	# CC Guard : Un étourdissement ou un silence bloque le lancement de sorts.
	if _selected_unit.status_receiver:
		if _selected_unit.status_receiver.is_stunned() or _selected_unit.status_receiver.is_silenced():
			return

	# AAA : Transition pure vers le Ghost Stance
	if _state == State.MOVE_TARGETING and _hovered_hex != INVALID_HEX and _reachable_hexes.has(_hovered_hex):
		_planned_move_hex = _hovered_hex
		GridEvents.movement_path_cleared.emit()
		GridEvents.movement_cleared.emit()
	else:
		if _state != State.SKILL_TARGETING:
			cancel_targeting()
		_planned_move_hex = INVALID_HEX
		
	_targeted_skill = skill
	_state = State.SKILL_TARGETING
	
	var previous_hover: Vector3i = _hovered_hex
	_hovered_hex = INVALID_HEX # Force l'actualisation de la zone même si la souris n'a pas bougé
	
	var origin_hex: Vector3i = _selected_unit.current_hex
	var ignored_hex: Vector3i = INVALID_HEX
	
	if _planned_move_hex != INVALID_HEX:
		origin_hex = _planned_move_hex
		ignored_hex = _selected_unit.current_hex
		GridEvents.ghost_stance_activated.emit(_planned_move_hex)
	else:
		GridEvents.ghost_stance_cleared.emit()
		
	# AAA : Calcul Just-In-Time de la portée de la compétence
	_valid_casting_hexes = GridTargeting.get_valid_casting_range(origin_hex, _targeted_skill, ignored_hex)
	GridEvents.skill_range_targeted.emit(_valid_casting_hexes)
	
	_hovered_hex = previous_hover
	_process_hover() # Force un premier dessin de l'AoE immédiatement

func _on_move_button_clicked() -> void:
	if not is_instance_valid(_selected_unit) or not _selected_unit.stats:
		return

	# AAA : Guard Clause d'Autorité Spatiale
	if _selected_unit.faction != Unit.Faction.PLAYER or _selected_unit != _active_turn_unit:
		return

	# CC Guard : Un étourdissement ou un enracinement bloque le déplacement.
	if _selected_unit.status_receiver:
		if _selected_unit.status_receiver.is_stunned() or _selected_unit.status_receiver.is_rooted():
			return

	if _state != State.DEFAULT:
		cancel_targeting()

	var available_mp: int = _selected_unit.stats.movement_points
	if _selected_unit.action_economy:
		available_mp = _selected_unit.action_economy.get_current_mp()
		
	# AAA : Guard clause pour empêcher le mouvement si la touche 'M' est pressée sans PM
	if available_mp <= 0:
		return
		
	_reachable_hexes = GridManager.pathfinder.get_reachable_hexes(_selected_unit.current_hex, _selected_unit.stats, available_mp, _selected_unit.faction, GridManager.unit_positions)
	
	_state = State.MOVE_TARGETING
	GridEvents.movement_targeted.emit(_reachable_hexes)

# SIGNAL HANDLERS (Events Globaux)
func _on_active_unit_changed(unit: Unit) -> void:
	_active_turn_unit = unit