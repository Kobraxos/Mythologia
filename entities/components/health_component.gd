class_name HealthComponent
extends Node

# SIGNALS
signal health_changed(current: int, max_health: int)
signal shield_changed(current: int, max_shield: int)

# EXPORTS
## Référence au gestionnaire de statistiques pour lire hp_regen/max_shield modifiés par les buffs.
@export var stat_manager: StatManagerComponent

# PRIVATE VARIABLES
var _stats: UnitStats
var _current_health: int = 0
var _current_shield: int = 0
var _max_shield: int = 0
var _is_dead: bool = false
## Compte à rebours du délai de régénération de l'Aegis.
## Chargé à _stats.shield_regen_delay à chaque absorption. Décrémenté chaque tick.
var _shield_regen_cooldown: int = 0

# ─────────────────────────────────────────────
# PUBLIC API — Initialisation
# ─────────────────────────────────────────────

func initialize(stats: UnitStats) -> void:
	_stats = stats
	_current_health = _stats.max_health

	# Style Protoss : l'unité spawne avec son bouclier à plein.
	_max_shield = _stats.max_shield
	_current_shield = _max_shield

	health_changed.emit(_current_health, _stats.max_health)
	if _max_shield > 0:
		shield_changed.emit(_current_shield, _max_shield)

# ─────────────────────────────────────────────
# PUBLIC API — Dégâts
# ─────────────────────────────────────────────

## bypass_shield = true pour les dégâts "purs" (poison, DoT, dégâts ignores-bouclier).
func take_damage(amount: int, bypass_shield: bool = false) -> void:
	if _is_dead or amount <= 0:
		return

	var remaining: int = amount

	# 1. Absorption par le bouclier (sauf si bypass_shield)
	if not bypass_shield and _current_shield > 0:
		var absorbed: int = mini(remaining, _current_shield)
		_current_shield -= absorbed
		remaining -= absorbed

		# Chaque coup sur le bouclier recharge le délai de régénération.
		# Tant que l'ennemi frappe, la fenêtre reste ouverte.
		_shield_regen_cooldown = _stats.shield_regen_delay if _stats else 1

		shield_changed.emit(_current_shield, _max_shield)
		_emit_visual_shield_update()

		# Événement "Shield Break" : déclenche VFX / son de brisure.
		if _current_shield == 0:
			if CombatEvents.has_user_signal("visual_shield_broken"):
				CombatEvents.emit_signal("visual_shield_broken", get_parent())

	# 2. L'overflow (ou la totalité si bypass) frappe les HP.
	if remaining <= 0:
		return

	_current_health -= remaining

	if _current_health <= 0:
		# AAA : Vérification de la prévention de mort AVANT de déclarer le décès.
		var parent: Node = get_parent()
		if parent and parent.get("status_receiver") != null:
			var sr: StatusReceiverComponent = parent.status_receiver
			var prevent_data: StatusEffectData = sr.consume_death_prevent()
			if prevent_data:
				_current_health = clampi(prevent_data.set_health_on_prevent, 1, _stats.max_health)
				health_changed.emit(_current_health, _stats.max_health)
				return # Mort évitée, on s'arrête ici.

		_current_health = 0
		_is_dead = true

	health_changed.emit(_current_health, _stats.max_health)

	if _is_dead:
		# AAA : Annonce globale de la mort pour la Grille et le TurnManager.
		CombatEvents.unit_died.emit(get_parent() as Unit)

# ─────────────────────────────────────────────
# PUBLIC API — Soins & Restauration
# ─────────────────────────────────────────────

func heal(amount: int) -> void:
	if _is_dead or amount <= 0:
		return

	_current_health = mini(_current_health + amount, _stats.max_health)

	health_changed.emit(_current_health, _stats.max_health)
	# Notifie le Séquenceur Visuel pour déclencher le tween animé de la barre de vie.
	if CombatEvents.has_user_signal("visual_health_updated"):
		CombatEvents.emit_signal("visual_health_updated", get_parent(), _current_health, _stats.max_health)

## Restaure le bouclier (par une compétence ou un statut). Plafonné à _max_shield.
func restore_shield(amount: int) -> void:
	if _is_dead or amount <= 0 or _max_shield <= 0:
		return

	_current_shield = mini(_current_shield + amount, _max_shield)

	shield_changed.emit(_current_shield, _max_shield)
	_emit_visual_shield_update()

# ─────────────────────────────────────────────
# PUBLIC API — Getters
# ─────────────────────────────────────────────

func get_current_health() -> int:
	return _current_health

func get_max_health() -> int:
	return _stats.max_health if _stats else 1

func get_current_shield() -> int:
	return _current_shield

func get_max_shield() -> int:
	return _max_shield

# ─────────────────────────────────────────────
# TICK — Régénération de base
# ─────────────────────────────────────────────

## TICK ORDER (DÉBUT) : Applique la régénération de HP de base au début du tour.
## Consulte le StatManager pour prendre en compte les buffs/debuffs actifs.
func tick_regen() -> void:
	if _is_dead:
		return
	# Priorité : valeur modifiée via le StatManager (buffs, debuffs).
	# Fallback : valeur brute de la ressource si le StatManager n'est pas assigné.
	var regen_amount: int
	if stat_manager:
		regen_amount = roundi(stat_manager.get_stat(StatManagerComponent.StatType.HP_REGEN))
	else:
		regen_amount = _stats.hp_regen_per_turn if _stats else 0

	if regen_amount > 0:
		heal(regen_amount)

## TICK ORDER (DÉBUT) : Applique la régénération de l'Aegis (bouclier) au début du tour.
## Miroir exact de tick_regen() pour les HP — avec gestion du délai post-impact.
func tick_regen_shield() -> void:
	if _is_dead or _max_shield <= 0:
		return

	# Délai de régénération : si le bouclier a encaissé des dégâts récemment, on attend.
	if _shield_regen_cooldown > 0:
		_shield_regen_cooldown -= 1
		return

	var regen_amount: int
	if stat_manager:
		regen_amount = roundi(stat_manager.get_stat(StatManagerComponent.StatType.SHIELD_REGEN))
	else:
		regen_amount = _stats.shield_regen_per_turn if _stats else 0

	if regen_amount > 0:
		restore_shield(regen_amount)

# ─────────────────────────────────────────────
# PRIVATE FUNCTIONS
# ─────────────────────────────────────────────

## Notifie le bus visuel du nouvel état du bouclier pour déclencher le tween UI.
func _emit_visual_shield_update() -> void:
	if CombatEvents.has_user_signal("visual_shield_updated"):
		CombatEvents.emit_signal("visual_shield_updated", get_parent(), _current_shield, _max_shield, _current_health, _stats.max_health)