class_name StatusReceiverComponent
extends Node

## Autorité unique sur les statuts actifs d'une unité.
## Gère l'application (avec MergeStrategy), le tick de durée, les DoT/HoT,
## la prévention de mort, et expose l'API de Crowd Control pour les systèmes extérieurs.

# SIGNALS
signal status_applied(status: StatusEffectData)
signal status_removed(status: StatusEffectData)

# EXPORTS
@export_category("Dependencies")
@export var stat_manager: StatManagerComponent
@export var health_component: HealthComponent

# INNER CLASS
class ActiveStatus extends RefCounted:
	var data: StatusEffectData
	var remaining_turns: int
	var modifier_ids: Array[int] = []

	func _init(p_data: StatusEffectData) -> void:
		data = p_data
		remaining_turns = p_data.duration_in_turns

# PRIVATE VARIABLES
var _active_statuses: Array[ActiveStatus] = []

# ─────────────────────────────────────────────
# PUBLIC API — Application
# ─────────────────────────────────────────────

func apply_status(status_data: StatusEffectData) -> void:
	if not status_data:
		return

	# MergeStrategy : si le statut possède un ID unique, on cherche un doublon
	if status_data.id != &"":
		for i: int in range(_active_statuses.size()):
			var existing: ActiveStatus = _active_statuses[i]
			if existing.data.id == status_data.id:
				_apply_merge_strategy(existing, status_data, i)
				return

	# Aucun doublon trouvé → application fraîche
	_apply_new_status(status_data)

func clear_all_statuses() -> void:
	for i: int in range(_active_statuses.size() - 1, -1, -1):
		_remove_status_at(i)

## Consomme et retourne le premier statut de prévention de mort trouvé.
## Appelé par HealthComponent juste avant de déclarer la mort de l'unité.
func consume_death_prevent() -> StatusEffectData:
	for i: int in range(_active_statuses.size() - 1, -1, -1):
		if _active_statuses[i].data.prevents_death:
			var data: StatusEffectData = _active_statuses[i].data
			_remove_status_at(i)
			return data
	return null

# ─────────────────────────────────────────────
# PUBLIC API — Crowd Control (Query)
# ─────────────────────────────────────────────

## Retourne vrai si au moins un statut actif empêche toute action.
func is_stunned() -> bool:
	for s: ActiveStatus in _active_statuses:
		if s.data.is_stunned:
			return true
	return false

## Retourne vrai si au moins un statut actif empêche le déplacement.
func is_rooted() -> bool:
	for s: ActiveStatus in _active_statuses:
		if s.data.is_rooted:
			return true
	return false

## Retourne vrai si au moins un statut actif empêche l'utilisation de compétences actives.
func is_silenced() -> bool:
	for s: ActiveStatus in _active_statuses:
		if s.data.is_silenced:
			return true
	return false

## Retourne vrai si au moins un statut actif empêche l'utilisation d'attaques de base.
func is_disarmed() -> bool:
	for s: ActiveStatus in _active_statuses:
		if s.data.is_disarmed:
			return true
	return false

## Retourne vrai si l'unité porte un statut avec l'ID donné.
func has_status(id: StringName) -> bool:
	for s: ActiveStatus in _active_statuses:
		if s.data.id == id:
			return true
	return false

## Retourne une copie en lecture seule de la liste des statuts actifs.
func get_active_statuses() -> Array:
	return _active_statuses.duplicate()

# ─────────────────────────────────────────────
# PUBLIC API — Tick (appelé par Unit)
# ─────────────────────────────────────────────

## TICK ORDER (DÉBUT) : Déclenche les DoT et HoT avant l'action du joueur.
func apply_start_turn_effects() -> void:
	if not health_component:
		return

	for status: ActiveStatus in _active_statuses:
		if status.data.damage_per_turn > 0:
			var dmg: int = status.data.damage_per_turn
			health_component.take_damage(dmg)
			var unit := get_parent() as Node3D
			if unit:
				CombatEvents.visual_text_requested.emit(unit, dmg, CoreEnums.FloatingTextType.DAMAGE, status.data.dot_element as CoreEnums.Element)
				
		if status.data.healing_per_turn > 0:
			var heal: int = status.data.healing_per_turn
			health_component.heal(heal)
			var unit := get_parent() as Node3D
			if unit:
				CombatEvents.visual_text_requested.emit(unit, heal, CoreEnums.FloatingTextType.HEAL, CoreEnums.Element.NONE)

## TICK ORDER (FIN) : Réduit les durées et nettoie les effets expirés.
func tick_durations() -> void:
	# Boucle inversée obligatoire pour éviter le décalage d'index lors de la suppression.
	for i: int in range(_active_statuses.size() - 1, -1, -1):
		var status: ActiveStatus = _active_statuses[i]
		# Durée 0 = Infini (ne jamais expirer naturellement)
		if status.data.duration_in_turns == 0:
			continue
		status.remaining_turns -= 1
		if status.remaining_turns <= 0:
			_remove_status_at(i)

# ─────────────────────────────────────────────
# PRIVATE FUNCTIONS
# ─────────────────────────────────────────────

func _apply_new_status(status_data: StatusEffectData) -> void:
	var new_status: ActiveStatus = ActiveStatus.new(status_data)

	if stat_manager:
		for mod_data: StatusModifierData in status_data.modifiers:
			var mod_id: int = stat_manager.add_modifier(mod_data.stat, mod_data.type, mod_data.value)
			new_status.modifier_ids.append(mod_id)

	_active_statuses.append(new_status)
	status_applied.emit(status_data)

func _apply_merge_strategy(existing: ActiveStatus, new_data: StatusEffectData, index: int) -> void:
	match new_data.merge_strategy:
		StatusEffectData.MergeStrategy.IGNORE:
			# Le statut existant est conservé tel quel.
			return

		StatusEffectData.MergeStrategy.REPLACE:
			# On retire l'ancien et on applique un tout nouveau.
			_remove_status_at(index)
			_apply_new_status(new_data)

		StatusEffectData.MergeStrategy.STACK_DURATION:
			# On ajoute la durée du nouveau statut à l'existant.
			existing.remaining_turns += new_data.duration_in_turns
			status_applied.emit(new_data) # Notification pour rafraîchir l'UI

		StatusEffectData.MergeStrategy.STACK_INTENSITY:
			# On empile les deux instances (modificateurs cumulatifs).
			_apply_new_status(new_data)

func _remove_status_at(index: int) -> void:
	var status: ActiveStatus = _active_statuses[index]

	if stat_manager:
		for mod_id: int in status.modifier_ids:
			stat_manager.remove_modifier(mod_id)

	_active_statuses.remove_at(index)
	status_removed.emit(status.data)