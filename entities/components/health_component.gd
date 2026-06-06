class_name HealthComponent
extends Node

# SIGNALS
signal health_changed(current: int, max_health: int)

# PRIVATE VARIABLES
var _stats: UnitStats
var _current_health: int = 0
var _is_dead: bool = false

# PUBLIC FUNCTIONS
func initialize(stats: UnitStats) -> void:
	_stats = stats
	_current_health = _stats.max_health
	health_changed.emit(_current_health, _stats.max_health)

# PUBLIC FUNCTIONS
func take_damage(amount: int) -> void:
	if _is_dead or amount <= 0:
		return

	_current_health -= amount

	if _current_health <= 0:
		# AAA : Vérification de la prévention de mort AVANT de déclarer le décès.
		# Le composant interroge son parent (l'Unité) via duck-typing.
		var parent: Node = get_parent()
		if parent and parent.get("status_receiver") != null:
			var sr: StatusReceiverComponent = parent.status_receiver
			var prevent_data: StatusEffectData = sr.consume_death_prevent()
			if prevent_data:
				# Le bouclier est consommé — l'unité survit à la valeur configurée.
				_current_health = clampi(prevent_data.set_health_on_prevent, 1, _stats.max_health)
				health_changed.emit(_current_health, _stats.max_health)
				return # Mort évitée, on s'arrête ici.

		_current_health = 0
		_is_dead = true

	health_changed.emit(_current_health, _stats.max_health)

	if _is_dead:
		# AAA : Annonce globale de la mort pour la Grille et le TurnManager
		CombatEvents.unit_died.emit(get_parent() as Unit)

func heal(amount: int) -> void:
	if _is_dead or amount <= 0:
		return
		
	_current_health += amount
	if _current_health > _stats.max_health:
		_current_health = _stats.max_health
		
	health_changed.emit(_current_health, _stats.max_health)

func get_current_health() -> int:
	return _current_health

func get_max_health() -> int:
	if _stats:
		return _stats.max_health
	return 1