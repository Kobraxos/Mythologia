class_name UnitStats
extends Resource

enum MovementType { WALKING, FLYING, HOVERING, TELEPORTING }
enum Mythology { NONE, GREEK, NORSE, EGYPTIAN, JAPANESE, CELTIC }
enum Rarity { COMMON, UNCOMMON, RARE, EPIC, LEGENDARY, MYTHIC }
enum UnitClass { WARRIOR, TANK, MAGE, RANGER, ASSASSIN, SUPPORT }
enum UnitType { HUMANOID, BEAST, UNDEAD, DEMON, CONSTRUCT, ELEMENTAL, DRAGON }

@export_category("General")
@export_group("Identity")
@export var id: StringName = &""
@export var unit_name: String = "Unknown Unit"
@export_multiline var description: String = ""
@export_multiline var lore: String = ""
@export var icon: Texture2D
@export var portrait: Texture2D
@export var world_sprite: Texture2D

@export_group("Classification")
@export var level: int = 1
@export var mythology: Mythology = Mythology.NONE
@export var unit_type: UnitType = UnitType.HUMANOID
@export var rarity: Rarity = Rarity.COMMON
@export var unit_class: UnitClass = UnitClass.WARRIOR

@export_category("Economy & Vitals")
@export_group("Action Economy")
@export var action_points: int = 2
@export var initiative: int = 5

@export_group("Health & Shield")
@export var max_health: int = 10
@export var max_shield: int = 0
@export var hp_regen_per_turn: int = 0

@export_group("Mana Pool")
@export var max_mana: int = 10
@export var mana_regen_per_turn: int = 0

@export_category("Grid & Locomotion")
@export_group("Movement")
@export var movement_points: int = 3
@export var movement_type: MovementType = MovementType.WALKING
@export var max_elevation_jump: int = 1

@export_group("Spatial Physics")
@export var knockback_resistance: float = 0.0
@export var vision_range: int = 5

@export_category("Combat Matrix")
@export_group("Base Output")
@export var base_physical_damage: int = 3
@export var base_mythic_damage: int = 0
@export var damage_dealt_multiplier: float = 1.0

@export_group("Base Defense")
@export var physical_defense: int = 0
@export var mythic_defense: int = 0
@export var damage_taken_multiplier: float = 1.0

@export_group("Penetration & Accuracy")
@export var physical_penetration: float = 0.0
@export var mythic_penetration: float = 0.0
@export var base_accuracy: float = 1.0
@export var base_evasion: float = 0.0

@export_group("Elemental Resistances")
@export var res_fire: float = 0.0
@export var res_water: float = 0.0
@export var res_ice: float = 0.0
@export var res_lightning: float = 0.0
@export var res_earth: float = 0.0
@export var res_poison: float = 0.0
@export var res_light: float = 0.0
@export var res_shadow: float = 0.0

@export_group("Critical Hits")
@export var base_crit_chance: float = 0.05
@export var base_crit_multiplier: float = 1.5

@export_group("Support & Status")
@export var effect_focus: float = 0.0
@export var effect_resistance: float = 0.0
@export var outgoing_healing_multiplier: float = 1.0
@export var incoming_healing_multiplier: float = 1.0

@export_category("Skillset")
@export_group("Abilities")
@export var base_attack: Resource
@export var active_skills: Array[Resource] = []
@export var passive_skills: Array[Resource] = []