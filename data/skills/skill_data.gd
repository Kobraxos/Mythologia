class_name SkillData
extends Resource

## Détermine l'entité géométrique que le joueur doit sélectionner.
enum TargetMode { SELF, UNIT, GROUND }
## Si le mode est UNIT, filtre les cibles valides sous la souris.
enum TargetAlignment { ENEMY, ALLY, ANY }

## Contraintes de verticalité (Z) pour le ciblage.
enum ElevationConstraint { NONE, MUST_BE_HIGHER, MUST_BE_LOWER, MUST_BE_SAME }
## Déplacement forcé du lanceur vers la cible.
enum CasterMovement { NONE, DASH_TO_TARGET, LEAP_TO_TARGET, TELEPORT_TO_TARGET }
## Déplacement forcé spécifique de la cible par rapport au lanceur.
enum TargetMovement { NONE, TELEPORT_TO_CASTER_ADJACENT, SWAP_POSITIONS }

## Formes de la zone d'effet (AoE) calculées par la grille.
enum AreaShape { SINGLE_TARGET, CIRCLE, LINE, CONE, RING, FLOOD_FILL }
## Contraintes de propagation de l'AoE (Utile pour les gaz, fluides, ou ondes de choc).
enum AoEHeightPropagation { IGNORE, DOWNWARD_ONLY, UPWARD_ONLY, SAME_LEVEL_ONLY, PROJECT_FLAT_IN_AIR }

## Éléments magiques pour les réactions avec l'environnement (Terrain/Surfaces).
enum Element { NONE, FIRE, WATER, ICE, LIGHTNING, EARTH, POISON, LIGHT, SHADOW }

## Modificateurs contextuels modifiant dynamiquement la puissance du sort.
enum DamageScaling { NONE, TARGET_MISSING_HP, TARGET_MAX_HP, CASTER_MAX_HP, CASTER_CURRENT_MANA, FLAT_HP_DIFFERENCE, ELEVATION_DIFFERENCE }

@export_category("Identity & UI")
@export var id: StringName = &""
@export var skill_name: String = "New Skill"
@export_multiline var description: String = ""
@export var icon: Texture2D
## Le nom de l'animation envoyée au système visuel (ex: "attack", "cast").
@export var animation_trigger: StringName = &"attack"
## Scène de particules (PackedScene) à instancier sur la cible à l'impact.
@export var vfx_impact: PackedScene
## Effet sonore (AudioStream) à jouer lors de l'exécution.
@export var sfx_cast: AudioStream

@export_category("Economy")
@export var ap_cost: int = 1
@export var mana_cost: int = 0
@export var cooldown: int = 0
## Nom système de la ressource spécifique consommée (ex: &"maat_feathers", &"rage"). Laisser vide si aucune.
@export var custom_resource_name: StringName = &""
@export var custom_resource_cost: int = 0

@export_category("Targeting & Range")
@export var target_mode: TargetMode = TargetMode.UNIT
@export var allowed_alignments: TargetAlignment = TargetAlignment.ENEMY
@export var min_range: int = 1
## Portée maximale (0 ou 999 pour une portée infinie).
@export var max_range: int = 1

@export_group("3D Range & Elevation")
@export var max_elevation_up: int = 1
@export var max_elevation_down: int = 1
## Bonus de portée horizontale accordé pour chaque niveau de hauteur d'avantage sur la cible (ex: 0.5 = +1 case de portée tous les 2 niveaux Z).
@export var elevation_range_bonus: float = 0.0

## Restriction de hauteur de la cible par rapport au lanceur.
@export var elevation_constraint: ElevationConstraint = ElevationConstraint.NONE
@export var requires_line_of_sight: bool = true
## Si Vrai, ce sort peut utiliser une entité "Proxy" (Totem, Clone, Allié lié) comme point d'origine pour le calcul de la portée et de la Ligne de Vue.
@export var can_cast_via_proxy: bool = false
## Si Vrai, la cible doit être dans un alignement strictement droit (Axial) par rapport au lanceur.
@export var is_linear_only: bool = false

@export_group("Skill Sequencing")
## Compétence "enfant" déclenchée automatiquement, gratuitement et instantanément après la résolution de celle-ci.
## Idéal pour des sorts à double effet (ex: Frappe Single Target au centre, suivie d'une AoE RING).
@export var follow_up_skill: SkillData

@export_category("Area of Effect")
@export var aoe_shape: AreaShape = AreaShape.SINGLE_TARGET
@export var aoe_radius: int = 0
## Règle de franchissement altimétrique pour la propagation de l'AoE (Surtout utile pour la forme FLOOD_FILL).
@export var aoe_height_propagation: AoEHeightPropagation = AoEHeightPropagation.IGNORE
## Si Vrai, l'onde de choc (Ligne, Cône) traverse les obstacles et entités au lieu de s'arrêter au premier impact.
@export var pierces_obstacles: bool = false
## Si Vrai : Dégâts appliqués qu'aux ennemis, Soins qu'aux alliés.
## Si Faux (Friendly Fire) : Dégâts et Soins appliqués à tout le monde.
@export var smart_targeting: bool = true

@export_category("Combat Matrix (Multipliers)")
@export_group("Offense")
## Tag élémentaire du sort (utilisé pour les réactions de terrain et résistances).
@export var skill_element: Element = Element.NONE
@export var physical_damage_multiplier: float = 1.0
@export var mythic_damage_multiplier: float = 0.0
## Bonus ponctuel de pénétration pour ignorer l'armure sur cette attaque spécifique.
@export var armor_penetration_bonus: float = 0.0
## Nombre de coups portés par l'attaque (Multi-hit).
@export var hit_count: int = 1
## Bonus/Malus ponctuel ajouté à la précision du lanceur (ex: -0.2 pour un coup lourd).
@export var accuracy_modifier: float = 0.0
## Bonus ponctuel ajouté aux chances de critique du lanceur (ex: 0.15 pour 15%).
@export var crit_chance_modifier: float = 0.0
## Si Vrai, et que le sort porte le coup de grâce, la cible ne peut pas être ressuscitée (Mort Définitive).
@export var is_execution: bool = false

@export_group("Contextual Scaling")
## Règle de mise à l'échelle dynamique des dégâts.
@export var contextual_scaling: DamageScaling = DamageScaling.NONE
## Ratio de puissance appliqué. (ex: scaling=TARGET_MISSING_HP, factor=0.5 -> +50% de dégâts par tranche de % de PV manquants).
@export var scaling_factor: float = 0.0

@export_group("Support")
## Soins bruts de base prodigués par la compétence (ex: Potion = 10).
@export var base_healing: int = 0
## Pourcentage des dégâts mythiques du lanceur ajouté aux soins (Scaling).
@export var healing_mythic_scaling: float = 0.0
@export var flat_shield_granted: int = 0

@export_group("Status & Effects")
## Liste des charges utiles. Injecter ici des "SkillEffectPayload" (qui définiront le % de proc et si l'effet cible l'ennemi ou le lanceur).
@export var effect_payloads: Array[SkillEffectPayload] = []

@export_group("Grid Manipulation")
## Ressource de terrain ou de surface (ex: TerrainData de Feu/Poison) à générer sur les cases touchées.
@export var spawned_surface: TerrainData
## Si Vrai, détruit le terrain ciblé (le remplace par du vide/gouffre). Déclenche les chutes si des unités s'y trouvent.
@export var destroys_terrain: bool = false

@export_group("Grid Physics & Displacement")
## Nombre d'hexagones dont la cible est repoussée (en s'éloignant du lanceur).
@export var knockback_distance: int = 0
## Nombre d'hexagones dont la cible est attirée (en se rapprochant du lanceur).
@export var pull_distance: int = 0
## Déplacement forcé de la cible modifiant radicalement sa position (prioritaire sur la poussée/attraction).
@export var target_movement: TargetMovement = TargetMovement.NONE
## Déplacement automatique du lanceur vers la case de la cible.
@export var caster_movement: CasterMovement = CasterMovement.NONE

@export_group("Summons & Mechanisms")
## Entité tactique (Totem, Piège, Illusion) à faire apparaître sur la case ciblée.
@export var summoned_entity: PackedScene