class_name TurnManager
extends Node

# PRIVATE VARIABLES
var _units: Array[Unit] = []
var _active_unit_index: int = -1
var _current_round: int = 0

## AAA : Nombre minimum de portraits affichés (pour voir à l'avance quand il y a peu d'unités).
const MIN_TIMELINE_PREVIEW: int = 8
## AAA : Nombre maximum absolu de portraits affichés (pour éviter de casser l'interface s'il y a 20 unités).
const MAX_TIMELINE_PREVIEW: int = 12

# GODOT BUILT-IN FUNCTIONS
func _ready() -> void:
	# Le manager écoute le mégaphone, il se fiche de savoir qui a pressé le bouton.
	TurnEvents.turn_end_requested.connect(_on_turn_end_requested)
	CombatEvents.unit_died.connect(_on_unit_died)

# PUBLIC FUNCTIONS
func register_unit(unit: Unit) -> void:
	if not _units.has(unit):
		_units.append(unit)

func start_battle() -> void:
	if _units.is_empty():
		return
		
	# DDD : Tri du tableau par Initiative (ordre décroissant)
	_units.sort_custom(func(a: Unit, b: Unit) -> bool:
		var init_a: int = a.stats.initiative if a.stats else 0
		var init_b: int = b.stats.initiative if b.stats else 0
		return init_a > init_b
	)
	
	_current_round = 1
	TurnEvents.battle_started.emit()
	TurnEvents.round_changed.emit(_current_round)
	
	_active_unit_index = -1
	_generate_and_emit_timeline()
	next_turn()

func next_turn() -> void:
	if _units.is_empty():
		return
		
	var any_alive := false
	for u in _units:
		if _is_unit_alive(u):
			any_alive = true
			break
			
	if not any_alive:
		return
		
	if _active_unit_index >= 0 and _active_unit_index < _units.size():
		var previous: Unit = _units[_active_unit_index]
		if _is_unit_alive(previous):
			previous.end_turn()
			TurnEvents.turn_ended.emit(previous)
			
	while true:
		_active_unit_index += 1
		if _active_unit_index >= _units.size():
			_active_unit_index = 0
			_current_round += 1
			TurnEvents.round_changed.emit(_current_round)

		var active: Unit = _units[_active_unit_index]
		if not _is_unit_alive(active):
			continue

		active.start_turn()

		# ─── AAA : Gestion du Stun (Étourdissement) ───────────────────────────────
		# L'unité prend brièvement possession de son tour (active_unit_changed émis),
		# le signal turn_skipped_stun déclenche le feedback visuel (texte flottant, UI),
		# puis après un délai, le tour passe automatiquement.
		if active.status_receiver and active.status_receiver.is_stunned():
			TurnEvents.active_unit_changed.emit(active)
			TurnEvents.turn_skipped_stun.emit(active)
			_generate_and_emit_timeline()
			await get_tree().create_timer(1.0).timeout
			active.end_turn()
			TurnEvents.turn_ended.emit(active)
			next_turn()
			return

		TurnEvents.active_unit_changed.emit(active)
		break

	_generate_and_emit_timeline()

# PRIVATE FUNCTIONS
func _is_unit_alive(unit: Unit) -> bool:
	return is_instance_valid(unit) and unit.health_component and unit.health_component.get_current_health() > 0

func _generate_and_emit_timeline() -> void:
	var queue: Array[Unit] = []
	var round_breaks: Array[int] = []
	if _units.is_empty():
		TurnEvents.timeline_updated.emit(queue, round_breaks)
		return
		
	# 1. On ignore les unités mortes/invalides pour la prédiction
	var valid_units: Array[Unit] = _units.filter(func(u: Unit) -> bool: return is_instance_valid(u) and u.health_component and u.health_component.get_current_health() > 0)
	
	if valid_units.is_empty():
		TurnEvents.timeline_updated.emit(queue, round_breaks)
		return
		
	# 2. Retrouver l'index dynamique de l'unité jouant actuellement
	var current_idx: int = 0
	if _active_unit_index >= 0 and _active_unit_index < _units.size():
		current_idx = valid_units.find(_units[_active_unit_index])
		if current_idx == -1: current_idx = 0
		
	# 3. AAA : Calcul dynamique de la longueur (Au moins MIN, au plus MAX, idéalement le nombre d'unités)
	var preview_count: int = clampi(valid_units.size(), MIN_TIMELINE_PREVIEW, MAX_TIMELINE_PREVIEW)
		
	# 4. Remplissage prédictif de la timeline avec boucle modulaire
	for i: int in range(preview_count):
		queue.append(valid_units[current_idx])
		current_idx = (current_idx + 1) % valid_units.size()
		# Si l'index revient à 0, cela signifie que le round vient de se terminer.
		# On marque la position APRES le portrait actuel comme étant une fin de round.
		if current_idx == 0 and i < preview_count - 1:
			round_breaks.append(i)
		
	# 5. Émission des données pures (la file d'attente et les points de rupture) à destination de la Vue
	TurnEvents.timeline_updated.emit(queue, round_breaks)

# SIGNAL HANDLERS
func _on_turn_end_requested() -> void:
	next_turn()
	
func _on_unit_died(_unit: Unit) -> void:
	_generate_and_emit_timeline()