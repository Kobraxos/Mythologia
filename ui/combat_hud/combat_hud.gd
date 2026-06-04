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

@export_category("UI Elements")
## Label affichant les Points d'Action.
@export var ap_label: Label
## Label affichant les Points de Mouvement.
@export var mp_label: Label

# PRIVATE VARIABLES
var _tracked_economy: ActionEconomyComponent
var _tracked_caster: SkillCasterComponent
var _current_cooldowns: Dictionary = {}

# GODOT BUILT-IN FUNCTIONS
func _ready() -> void:
	GridEvents.unit_selected.connect(_on_unit_selected)
	GridEvents.unit_deselected.connect(_on_unit_deselected)
	if action_bar:
		action_bar.clear()

# SIGNAL HANDLERS
func _on_unit_selected(unit: Unit, _reachable_hexes: Array[Vector3i]) -> void:
	if action_bar:
		action_bar.clear()
	_untrack_action_economy()
	_untrack_skill_caster()
	
	if not is_instance_valid(unit):
		return
		
	# 1. Swapping de Thème Dynamique (Data-Driven Faction UI)
	self.theme = default_theme
	
	if "stats" in unit and unit.stats is UnitStats:
		var myth_id: int = unit.stats.mythology
		if faction_themes.has(myth_id) and faction_themes[myth_id] is Theme:
			self.theme = faction_themes[myth_id]

	_track_action_economy(unit)
	_track_skill_caster(unit)
			
	# Duck-typing sécurisé pour récupérer le composant lanceur de sort et sa liste
	if not unit.get("skill_caster"):
		return
		
	var skills: Array = unit.skill_caster.get("_known_skills") if "_known_skills" in unit.skill_caster else []
	if skills.is_empty():
		return
		
	if action_bar:
		action_bar.setup(skills)
		_update_action_bar_usability()

func _on_unit_deselected() -> void:
	if action_bar:
		action_bar.clear()
	_untrack_action_economy()
	_untrack_skill_caster()

func _track_action_economy(unit: Unit) -> void:
	if "action_economy" in unit and unit.action_economy is ActionEconomyComponent:
		_tracked_economy = unit.action_economy
		_tracked_economy.ap_changed.connect(_on_ap_changed)
		_tracked_economy.mp_changed.connect(_on_mp_changed)
		
		# Initialisation immédiate de l'affichage
		if ap_label:
			ap_label.visible = true
			_on_ap_changed(_tracked_economy.get_current_ap(), _tracked_economy.get_max_ap())
		if mp_label:
			mp_label.visible = true
			_on_mp_changed(_tracked_economy.get_current_mp(), _tracked_economy.get_max_mp())

func _untrack_action_economy() -> void:
	if is_instance_valid(_tracked_economy):
		if _tracked_economy.ap_changed.is_connected(_on_ap_changed):
			_tracked_economy.ap_changed.disconnect(_on_ap_changed)
		if _tracked_economy.mp_changed.is_connected(_on_mp_changed):
			_tracked_economy.mp_changed.disconnect(_on_mp_changed)
	_tracked_economy = null
	
	if ap_label:
		ap_label.visible = false
	if mp_label:
		mp_label.visible = false

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

func _on_ap_changed(current: int, max_val: int) -> void:
	if ap_label:
		ap_label.text = "PA: %d / %d" % [current, max_val]
	_update_action_bar_usability()

func _on_mp_changed(current: int, max_val: int) -> void:
	if mp_label:
		mp_label.text = "PM: %d / %d" % [current, max_val]