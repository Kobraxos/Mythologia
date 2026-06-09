class_name UnitFrame
extends Control

## Composant visuel "Cockpit" affichant le portrait, le nom et la santé de l'unité active.
## Architecture AAA : Data-Driven, écoute les signaux du HealthComponent avec animation par Tween.

# EXPORTS
@export var portrait_label: Label
@export var health_bar: ProgressBar
@export var health_text: Label

# PRIVATE VARIABLES
var _tracked_health: HealthComponent
var _current_hp: int = 0
var _max_hp: int = 0
var _hp_tween: Tween

# GODOT BUILT-IN FUNCTIONS
func _ready() -> void:
	if not health_bar:
		push_warning("UnitFrame: health_bar non assignée.")
	if not health_text:
		push_warning("UnitFrame: health_text non assigné.")

# PUBLIC API
## Connecte le UnitFrame à une unité spécifique.
func track_unit(unit: Unit) -> void:
	_untrack_health()
	
	if not is_instance_valid(unit):
		visible = false
		return
		
	visible = true
	
	# Mise à jour du nom / portrait
	if portrait_label:
		# Utilise le nom de la node comme fallback si l'unité n'a pas de display_name
		portrait_label.text = unit.get("display_name") if "display_name" in unit else unit.name
	
	# Branchement au HealthComponent (Duck-typing sécurisé)
	if "health_component" in unit and unit.health_component is HealthComponent:
		_tracked_health = unit.health_component
		_max_hp = _tracked_health.get_max_health()
		_current_hp = _tracked_health.get_current_health()
		
		_tracked_health.health_changed.connect(_on_health_changed)
		
		# Initialisation immédiate (sans animation)
		if health_bar:
			health_bar.max_value = _max_hp
			health_bar.value = _current_hp
		_update_health_label()

# PRIVATE FUNCTIONS
func _untrack_health() -> void:
	if is_instance_valid(_tracked_health):
		if _tracked_health.health_changed.is_connected(_on_health_changed):
			_tracked_health.health_changed.disconnect(_on_health_changed)
	_tracked_health = null
	
	if _hp_tween and _hp_tween.is_valid():
		_hp_tween.kill()

func _on_health_changed(current: int, max_val: int) -> void:
	_max_hp = max_val
	var target_hp = current
	
	_update_health_label(target_hp)
	
	if health_bar:
		health_bar.max_value = _max_hp
		
		# AAA : Animation viscérale de la perte de PV
		if _hp_tween and _hp_tween.is_valid():
			_hp_tween.kill()
			
		_hp_tween = create_tween()
		_hp_tween.set_trans(Tween.TRANS_QUAD)
		_hp_tween.set_ease(Tween.EASE_OUT)
		_hp_tween.tween_property(health_bar, "value", target_hp, 0.3)

func _update_health_label(val: int = -1) -> void:
	if not health_text:
		return
		
	var display_val = _current_hp if val == -1 else val
	health_text.text = "%d / %d" % [display_val, _max_hp]
