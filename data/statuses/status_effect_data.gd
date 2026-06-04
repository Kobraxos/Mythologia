class_name StatusEffectData
extends Resource

enum EffectType { BUFF, DEBUFF, NEUTRAL, HIDDEN_TRIGGER }
## Stratégie appliquée si la cible possède déjà ce statut.
enum MergeStrategy { STACK_DURATION, STACK_INTENSITY, REPLACE, IGNORE }
## Méthode de mise à l'échelle dynamique des modificateurs de stats.
enum StatScaling { NONE, MULTIPLY_BY_ELEVATION, MULTIPLY_BY_MISSING_HP }

@export_category("Identity & Visuals")
@export var id: StringName = &""
@export var effect_name: String = "New Status Effect"
@export_multiline var description: String = ""
@export var icon: Texture2D
## Particules persistantes à attacher à l'unité tant que l'effet est actif.
@export var vfx_persistent: PackedScene

@export_category("Mechanics")
@export var type: EffectType = EffectType.BUFF
## Durée de l'effet en tours (0 = Infini/Jusqu'à annulation).
@export var duration_in_turns: int = 1
@export var merge_strategy: MergeStrategy = MergeStrategy.REPLACE
## Si Vrai, peut être annulé par un sort de "Purification" ou de "Dissipation".
@export var is_dispellable: bool = true
## Si Vrai, l'unité ne peut pas être ciblée par des compétences ennemies à cible unique.
@export var is_untargetable: bool = false

@export_category("Stat Modifiers")
## Condition contextuelle requise pour que ces modificateurs s'appliquent en temps réel (ex: ELEVATION_GREATER_THAN_ZERO).
@export var activation_condition: StatusTriggerData.TriggerCondition = StatusTriggerData.TriggerCondition.ALWAYS
## Règle de calcul dynamique : multiplie les valeurs ci-dessous selon un contexte (ex: par le niveau de hauteur Z).
@export var stat_scaling: StatScaling = StatScaling.NONE
## Liste strictement typée des altérations de statistiques appliquées pendant la durée de l'effet.
@export var modifiers: Array[StatusModifierData] = []

@export_category("Hard Crowd Control")
## Empêche toute action (Passe le tour).
@export var is_stunned: bool = false
## Empêche le déplacement.
@export var is_rooted: bool = false
## Empêche l'utilisation de compétences actives (Magie/Skills).
@export var is_silenced: bool = false
## Empêche l'utilisation de l'attaque de base (Armes).
@export var is_disarmed: bool = false

@export_category("Over Time Effects (DoT / HoT)")
## Dégâts subis au début du tour de l'unité.
@export var damage_per_turn: int = 0
## Soins reçus au début du tour de l'unité.
@export var healing_per_turn: int = 0
@export var dot_element: SkillData.Element = SkillData.Element.NONE

@export_category("Reactive Triggers")
## Liste des compétences à déclencher en réaction à des événements de jeu.
@export var triggers: Array[Resource] = [] # Array[StatusTriggerData]

@export_category("Death Evasion")
## Si Vrai, ce statut est consommé à la place de la mort, annulant les dégâts mortels.
@export var prevents_death: bool = false
## Si prevents_death est Vrai, fixe les PV de l'unité à cette valeur après avoir survécu.
@export var set_health_on_prevent: int = 1
