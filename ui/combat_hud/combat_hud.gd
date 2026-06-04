class_name CombatHUD
extends Control

## Interface utilisateur de combat. Data-Driven et Event-Driven.

# EXPORTS
@export_category("Prefabs")
## Le modèle de bouton instancié pour chaque compétence.
@export var skill_button_prefab: PackedScene

@export_category("Themes")
## Le thème par défaut si l'unité n'a pas de mythologie définie.
@export var default_theme: Theme
## Dictionnaire liant une faction (UnitStats.Mythology) à son Thème UI. (Clé: Int, Valeur: Theme)
@export var faction_themes: Dictionary = {}

@export_category("References")
## Le conteneur (HBoxContainer) qui va recevoir les boutons générés.
@export var skills_container: Control

# GODOT BUILT-IN FUNCTIONS
func _ready() -> void:
	GridEvents.unit_selected.connect(_on_unit_selected)
	GridEvents.unit_deselected.connect(_on_unit_deselected)
	_clear_skills() # Cache l'UI de compétences au démarrage

# SIGNAL HANDLERS
func _on_unit_selected(unit: Unit, _reachable_hexes: Array[Vector3i]) -> void:
	_clear_skills()
	
	if not is_instance_valid(unit):
		return
		
	# 1. Swapping de Thème Dynamique (Data-Driven Faction UI)
	self.theme = default_theme
	
	if "stats" in unit and unit.stats is UnitStats:
		var myth_id: int = unit.stats.mythology
		if faction_themes.has(myth_id) and faction_themes[myth_id] is Theme:
			self.theme = faction_themes[myth_id]
		
	# Duck-typing sécurisé pour récupérer le composant lanceur de sort et sa liste
	if not unit.get("skill_caster"):
		return
		
	var skills: Array = unit.skill_caster.get("_known_skills") if "_known_skills" in unit.skill_caster else []
	if skills.is_empty():
		return
		
	_populate_skills(skills)

func _on_unit_deselected() -> void:
	_clear_skills()

# PRIVATE FUNCTIONS
func _populate_skills(skills: Array) -> void:
	if not skill_button_prefab or not skills_container:
		push_error("CombatHUD: Dépendances UI manquantes (Prefab ou Container).")
		return
		
	for skill in skills:
		var skill_res := skill as SkillData
		if not skill_res:
			continue
			
		var skill_button: SkillButton = skill_button_prefab.instantiate() as SkillButton
		skills_container.add_child(skill_button)
		skill_button.setup(skill_res)
			
	skills_container.visible = true

func _clear_skills() -> void:
	if is_instance_valid(skills_container):
		for child: Node in skills_container.get_children():
			child.queue_free()
		skills_container.visible = false