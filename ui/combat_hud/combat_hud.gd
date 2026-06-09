class_name CombatHUD
extends Control

## Interface utilisateur de combat. Data-Driven et Event-Driven.

# EXPORTS
@export_category("Themes")
## Le thème par défaut si l'unité n'a pas de mythologie définie.
@export var default_theme: Theme
## Dictionnaire liant une faction (UnitStats.Mythology) à son Thème UI. (Clé: Int, Valeur: Theme)
@export var faction_themes: Dictionary = {}

@export_category("UI Widgets")
## Le widget gérant la barre d'action et les raccourcis.
@export var action_bar: ActionBar
## Panneau PA/PM à pips (ResourcePanel).
@export var resource_panel: ResourcePanel
## Le cadre d'unité (Portrait, PV).
@export var unit_frame: UnitFrame
## Bouton permanent dédié à l'activation du mode déplacement.
@export var move_button: Button
## Bouton dédié à la fin de tour.
@export var end_turn_button: Button

# PRIVATE VARIABLES
var _tracked_economy: ActionEconomyComponent
var _tracked_caster: SkillCasterComponent
var _current_cooldowns: Dictionary = {}
var _end_turn_tween: Tween

var _active_turn_unit: Unit = null
var _inspected_unit: Unit = null
var _cockpit_unit: Unit = null

# GODOT BUILT-IN FUNCTIONS
func _ready() -> void:
	GridEvents.unit_selected.connect(_on_unit_selected)
	GridEvents.unit_deselected.connect(_on_unit_deselected)
	if TurnEvents.has_signal("active_unit_changed"):
		TurnEvents.active_unit_changed.connect(_on_active_unit_changed)
	
	if action_bar:
		action_bar.clear()
	if move_button:
		move_button.focus_mode = Control.FOCUS_NONE
		move_button.visible = true
		move_button.pressed.connect(_on_move_button_pressed)
	if end_turn_button:
		end_turn_button.focus_mode = Control.FOCUS_NONE
		end_turn_button.visible = true
		end_turn_button.pressed.connect(_on_end_turn_button_pressed)

# SIGNAL HANDLERS
func _on_unit_selected(unit: Unit) -> void:
	if not is_instance_valid(unit):
		_on_unit_deselected()
		return
	_inspected_unit = unit
	_evaluate_cockpit_state()

func _on_unit_deselected() -> void:
	_inspected_unit = null
	_evaluate_cockpit_state()

func _on_active_unit_changed(unit: Unit) -> void:
	_active_turn_unit = unit
	_evaluate_cockpit_state()

func _evaluate_cockpit_state() -> void:
	# 1. Masquage total si c'est au tour d'un monstre
	if is_instance_valid(_active_turn_unit) and _active_turn_unit.faction != Unit.Faction.PLAYER:
		if has_node("BottomConsole"):
			$BottomConsole.hide()
		return
		
	# 2. C'est le tour d'un joueur, la console doit être visible
	if has_node("BottomConsole"):
		$BottomConsole.show()
		
	# 3. Déterminer l'unité à afficher dans le Cockpit
	var target_cockpit_unit: Unit = null
	
	if is_instance_valid(_inspected_unit):
		if _inspected_unit.faction == Unit.Faction.PLAYER:
			# On inspecte un de nos propres héros (que ce soit son tour ou non)
			target_cockpit_unit = _inspected_unit
		else:
			# On inspecte un monstre pendant notre tour : on maintient l'affichage sur notre héros actif
			target_cockpit_unit = _active_turn_unit
	else:
		# Pas d'inspection : on affiche l'unité active par défaut
		target_cockpit_unit = _active_turn_unit

	# 4. Appliquer les changements si l'unité du cockpit a changé
	if target_cockpit_unit != _cockpit_unit:
		_cockpit_unit = target_cockpit_unit
		_setup_cockpit_for(_cockpit_unit)

	# 5. Mettre à jour l'interactivité (boutons grisés si le cockpit affiche qqn dont ce n'est pas le tour)
	_update_interactivity()

func _setup_cockpit_for(unit: Unit) -> void:
	_untrack_action_economy()
	_untrack_skill_caster()
	if action_bar:
		action_bar.clear()
		
	if not is_instance_valid(unit):
		return
		
	# Habillage Dynamique (Data-Driven Faction UI)
	self.theme = default_theme
	if "stats" in unit and unit.stats is UnitStats:
		var myth_id: int = unit.stats.mythology
		if faction_themes.has(myth_id) and faction_themes[myth_id] is Theme:
			self.theme = faction_themes[myth_id]

	# Tracking des statistiques pour l'unité du cockpit
	_track_action_economy(unit)
	_track_skill_caster(unit)
	
	if unit_frame:
		unit_frame.track_unit(unit)
	
	# Initialisation de l'Action Bar
	if unit.get("skill_caster"):
		var skills: Array = unit.skill_caster.get("_known_skills") if "_known_skills" in unit.skill_caster else []
		if not skills.is_empty() and action_bar:
			action_bar.setup(skills, unit)

func _update_interactivity() -> void:
	var is_active_turn: bool = false
	if is_instance_valid(_cockpit_unit) and is_instance_valid(_active_turn_unit):
		is_active_turn = (_cockpit_unit == _active_turn_unit)
	
	if move_button:
		if not is_active_turn:
			move_button.disabled = true
		else:
			_update_move_button_usability()
			
	if end_turn_button:
		end_turn_button.disabled = not is_active_turn
		
		# Reset du tween s'il y en a un
		if _end_turn_tween and _end_turn_tween.is_valid():
			_end_turn_tween.kill()
			end_turn_button.scale = Vector2(1, 1)
			
		# AAA : Pulse (Scale) si 0 PA et 0 PM
		if is_active_turn and is_instance_valid(_tracked_economy):
			if _tracked_economy.get_current_ap() == 0 and _tracked_economy.get_current_mp() == 0:
				end_turn_button.pivot_offset = end_turn_button.size / 2.0
				_end_turn_tween = create_tween().set_loops()
				_end_turn_tween.tween_property(end_turn_button, "scale", Vector2(1.08, 1.08), 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
				_end_turn_tween.tween_property(end_turn_button, "scale", Vector2(1.0, 1.0), 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		
	if action_bar:
		if not is_active_turn:
			if action_bar.has_method("set_all_disabled"):
				action_bar.set_all_disabled(true)
		else:
			_update_action_bar_usability()

func _track_action_economy(unit: Unit) -> void:
	if "action_economy" in unit and unit.action_economy is ActionEconomyComponent:
		_tracked_economy = unit.action_economy
		_tracked_economy.ap_changed.connect(_on_ap_changed)
		_tracked_economy.mp_changed.connect(_on_mp_changed)

		# Initialisation immédiate du ResourcePanel
		if resource_panel:
			resource_panel.track_unit(unit)

func _untrack_action_economy() -> void:
	if is_instance_valid(_tracked_economy):
		if _tracked_economy.ap_changed.is_connected(_on_ap_changed):
			_tracked_economy.ap_changed.disconnect(_on_ap_changed)
		if _tracked_economy.mp_changed.is_connected(_on_mp_changed):
			_tracked_economy.mp_changed.disconnect(_on_mp_changed)
	_tracked_economy = null

func _track_skill_caster(unit: Unit) -> void:
	if "skill_caster" in unit and unit.skill_caster is SkillCasterComponent:
		_tracked_caster = unit.skill_caster
		_tracked_caster.cooldowns_updated.connect(_on_cooldowns_updated)
		_current_cooldowns = _tracked_caster.get_cooldowns()

func _untrack_skill_caster() -> void:
	if is_instance_valid(_tracked_caster):
		if _tracked_caster.cooldowns_updated.is_connected(_on_cooldowns_updated):
			_tracked_caster.cooldowns_updated.disconnect(_on_cooldowns_updated)
	_tracked_caster = null
	_current_cooldowns.clear()

func _on_cooldowns_updated(cooldowns: Dictionary) -> void:
	_current_cooldowns = cooldowns
	_update_action_bar_usability()

func _update_action_bar_usability() -> void:
	if action_bar and is_instance_valid(_tracked_economy):
		action_bar.update_usable_skills(_tracked_economy.get_current_ap(), _current_cooldowns)

func _on_ap_changed(_current: int, _max_val: int) -> void:
	_update_interactivity()

func _on_mp_changed(_current: int, _max_val: int) -> void:
	_update_interactivity()

func _update_move_button_usability() -> void:
	if move_button and is_instance_valid(_tracked_economy):
		move_button.disabled = _tracked_economy.get_current_mp() <= 0

func _on_move_button_pressed() -> void:
	CombatEvents.move_button_clicked.emit()

func _on_end_turn_button_pressed() -> void:
	TurnEvents.turn_end_requested.emit()