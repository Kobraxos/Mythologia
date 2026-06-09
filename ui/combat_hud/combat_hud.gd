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
## Bouton permanent dédié à l'activation du mode déplacement.
@export var move_button: Button
## Bouton dédié à la fin de tour.
@export var end_turn_button: Button

# PRIVATE VARIABLES
var _tracked_economy: ActionEconomyComponent
var _tracked_caster: SkillCasterComponent
var _current_cooldowns: Dictionary = {}
var _current_active_unit: Unit = null
var _selected_unit: Unit = null

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
		move_button.visible = false
		move_button.pressed.connect(_on_move_button_pressed)
	if end_turn_button:
		end_turn_button.focus_mode = Control.FOCUS_NONE
		end_turn_button.visible = false
		end_turn_button.pressed.connect(_on_end_turn_button_pressed)

# SIGNAL HANDLERS
func _on_unit_selected(unit: Unit) -> void:
	# 0. Réinitialisation systématique de l'état interactif (Reset AAA)
	if action_bar:
		action_bar.clear()
	if move_button:
		move_button.visible = false
	if end_turn_button:
		end_turn_button.visible = false

	_untrack_action_economy()
	_untrack_skill_caster()
	_selected_unit = null

	if not is_instance_valid(unit):
		return

	_selected_unit = unit

	# 1. Habillage Dynamique (Data-Driven Faction UI)
	self.theme = default_theme

	if "stats" in unit and unit.stats is UnitStats:
		var myth_id: int = unit.stats.mythology
		if faction_themes.has(myth_id) and faction_themes[myth_id] is Theme:
			self.theme = faction_themes[myth_id]

	# 2. Tracking des statistiques (Visible pour alliés ET ennemis)
	_track_action_economy(unit)
	_track_skill_caster(unit)

	# 3. AAA : Guard Clause d'Autorité UI — On s'arrête ici si ce n'est pas le joueur
	if unit.faction != Unit.Faction.PLAYER:
		return

	# 4. Activation de l'Interface Interactive (Joueur uniquement)
	if move_button:
		move_button.visible = true
	if end_turn_button:
		end_turn_button.visible = true

	# Duck-typing sécurisé pour récupérer le composant lanceur de sort et sa liste
	if not unit.get("skill_caster"):
		return

	var skills: Array = unit.skill_caster.get("_known_skills") if "_known_skills" in unit.skill_caster else []
	if not skills.is_empty() and action_bar:
		action_bar.setup(skills, unit)

	# Initialisation de l'état interactif global (Boutons grisés si ce n'est pas le tour de l'unité)
	_update_interactivity()

func _on_unit_deselected() -> void:
	_selected_unit = null
	if action_bar:
		action_bar.clear()
	_untrack_action_economy()
	_untrack_skill_caster()
	if move_button:
		move_button.visible = false
	if end_turn_button:
		end_turn_button.visible = false

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
	# Le ResourcePanel se met à jour seul via ses propres connexions.
	# On garde ce handler uniquement pour mettre à jour l'usabilité de la barre d'actions.
	_update_interactivity()

func _on_mp_changed(_current: int, _max_val: int) -> void:
	# Le ResourcePanel se met à jour seul via ses propres connexions.
	# On garde ce handler uniquement pour mettre à jour l'usabilité du bouton de déplacement.
	_update_interactivity()

func _update_move_button_usability() -> void:
	if move_button and is_instance_valid(_tracked_economy):
		move_button.disabled = _tracked_economy.get_current_mp() <= 0

func _on_move_button_pressed() -> void:
	CombatEvents.move_button_clicked.emit()

func _on_end_turn_button_pressed() -> void:
	TurnEvents.turn_end_requested.emit()

func _on_active_unit_changed(unit: Unit) -> void:
	_current_active_unit = unit
	_update_interactivity()

func _update_interactivity() -> void:
	var is_active_turn: bool = false
	if is_instance_valid(_selected_unit) and is_instance_valid(_current_active_unit):
		is_active_turn = (_selected_unit == _current_active_unit)
	
	if move_button:
		if not is_active_turn:
			move_button.disabled = true
		else:
			_update_move_button_usability()
			
	if end_turn_button:
		end_turn_button.disabled = not is_active_turn
		
	if action_bar:
		if not is_active_turn:
			if action_bar.has_method("set_all_disabled"):
				action_bar.set_all_disabled(true)
		else:
			_update_action_bar_usability()