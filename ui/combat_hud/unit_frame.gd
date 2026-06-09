class_name UnitFrame
extends Control

## Composant visuel "Cockpit" affichant le portrait, le nom et la santé de l'unité active.
## Architecture AAA : Data-Driven, écoute les signaux du HealthComponent avec animation par Tween.

# EXPORTS
@export var portrait_label: Label
@export var portrait_rect: TextureRect
@export var health_bar: ProgressBar
@export var health_text: Label
@export var shield_bar: ProgressBar
@export var mana_bar: ProgressBar

# PRIVATE VARIABLES
var _tracked_health: HealthComponent
var _tracked_economy: ActionEconomyComponent
var _current_hp: int = 0
var _max_hp: int = 0
var _hp_tween: Tween

var _current_shield: int = 0
var _max_shield: int = 0
var _shield_tween: Tween

var _current_mana: int = 0
var _max_mana: int = 0
var _mana_tween: Tween
var _low_hp_tween: Tween

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
		
	if portrait_rect:
		if "stats" in unit and unit.stats != null and "portrait" in unit.stats:
			portrait_rect.texture = unit.stats.portrait
			if portrait_label:
				portrait_label.visible = false
		else:
			portrait_rect.texture = null
			if portrait_label:
				portrait_label.visible = true
	
	# Branchement au HealthComponent (Duck-typing sécurisé)
	if "health_component" in unit and unit.health_component is HealthComponent:
		_tracked_health = unit.health_component
		_max_hp = _tracked_health.get_max_health()
		_current_hp = _tracked_health.get_current_health()
		_max_shield = _tracked_health.get_max_shield()
		_current_shield = _tracked_health.get_current_shield()
		
		_tracked_health.health_changed.connect(_on_health_changed)
		_tracked_health.shield_changed.connect(_on_shield_changed)
		
		# Initialisation immédiate (sans animation)
		if health_bar:
			health_bar.max_value = _max_hp
			health_bar.value = _current_hp
		if shield_bar:
			shield_bar.max_value = _max_shield
			shield_bar.value = _current_shield
			shield_bar.visible = _max_shield > 0
			
		_update_health_label()
		_check_low_health_state()
		
	# Branchement au ActionEconomyComponent (pour le Mana)
	if "action_economy" in unit and unit.action_economy is ActionEconomyComponent:
		_tracked_economy = unit.action_economy
		_max_mana = _tracked_economy.get_max_mana()
		_current_mana = _tracked_economy.get_current_mana()
		
		_tracked_economy.mana_changed.connect(_on_mana_changed)
		
		if mana_bar:
			mana_bar.max_value = _max_mana
			mana_bar.value = _current_mana
			mana_bar.visible = _max_mana > 0

# PRIVATE FUNCTIONS
func _untrack_health() -> void:
	if is_instance_valid(_tracked_health):
		if _tracked_health.health_changed.is_connected(_on_health_changed):
			_tracked_health.health_changed.disconnect(_on_health_changed)
		if _tracked_health.shield_changed.is_connected(_on_shield_changed):
			_tracked_health.shield_changed.disconnect(_on_shield_changed)
	_tracked_health = null
	
	if is_instance_valid(_tracked_economy):
		if _tracked_economy.mana_changed.is_connected(_on_mana_changed):
			_tracked_economy.mana_changed.disconnect(_on_mana_changed)
	_tracked_economy = null
	
	if _hp_tween and _hp_tween.is_valid():
		_hp_tween.kill()
	if _shield_tween and _shield_tween.is_valid():
		_shield_tween.kill()
	if _mana_tween and _mana_tween.is_valid():
		_mana_tween.kill()
	if _low_hp_tween and _low_hp_tween.is_valid():
		_low_hp_tween.kill()
	if portrait_rect:
		portrait_rect.modulate = Color(1, 1, 1, 1)

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
		
	_check_low_health_state()

func _on_shield_changed(current: int, max_val: int) -> void:
	_max_shield = max_val
	var target_shield = current
	
	if shield_bar:
		shield_bar.visible = _max_shield > 0
		shield_bar.max_value = _max_shield
		
		if _shield_tween and _shield_tween.is_valid():
			_shield_tween.kill()
			
		_shield_tween = create_tween()
		_shield_tween.set_trans(Tween.TRANS_QUAD)
		_shield_tween.set_ease(Tween.EASE_OUT)
		_shield_tween.tween_property(shield_bar, "value", target_shield, 0.3)

func _on_mana_changed(current: int, max_val: int) -> void:
	_max_mana = max_val
	var target_mana = current
	
	if mana_bar:
		mana_bar.visible = _max_mana > 0
		mana_bar.max_value = _max_mana
		
		if _mana_tween and _mana_tween.is_valid():
			_mana_tween.kill()
			
		_mana_tween = create_tween()
		_mana_tween.set_trans(Tween.TRANS_QUAD)
		_mana_tween.set_ease(Tween.EASE_OUT)
		_mana_tween.tween_property(mana_bar, "value", target_mana, 0.3)

func _update_health_label(val: int = -1) -> void:
	if not health_text:
		return
		
	var display_val = _current_hp if val == -1 else val
	health_text.text = "%d / %d" % [display_val, _max_hp]

func _check_low_health_state() -> void:
	if not is_instance_valid(portrait_rect):
		return
		
	var ratio: float = float(_current_hp) / float(_max_hp) if _max_hp > 0 else 1.0
	var is_low: bool = (ratio <= 0.25) and (_current_hp > 0)
	
	if is_low:
		if not _low_hp_tween or not _low_hp_tween.is_valid():
			_low_hp_tween = create_tween().set_loops()
			# AAA UX: Battement de coeur visuel d'urgence
			_low_hp_tween.tween_property(portrait_rect, "modulate", Color(1.8, 0.5, 0.5, 1.0), 0.6).set_trans(Tween.TRANS_SINE)
			_low_hp_tween.tween_property(portrait_rect, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.6).set_trans(Tween.TRANS_SINE)
	else:
		if _low_hp_tween and _low_hp_tween.is_valid():
			_low_hp_tween.kill()
			portrait_rect.modulate = Color(1.0, 1.0, 1.0, 1.0)
