class_name TimelinePortrait
extends Control

@export var portrait_rect: ColorRect

var _unit: Unit
var _is_active: bool = false
var _tween: Tween

const TOOLTIP_SCENE: PackedScene = preload("res://ui/components/simple_tooltip.tscn")

# GODOT BUILT-IN FUNCTIONS
func _ready() -> void:
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

## AAA : Surcharge de la méthode native Godot pour forcer notre design de Tooltip
func _make_custom_tooltip(for_text: String) -> Object:
	var tooltip: SimpleTooltip = TOOLTIP_SCENE.instantiate() as SimpleTooltip
	tooltip.set_text(for_text)
	return tooltip

# PUBLIC FUNCTIONS
func setup(unit: Unit, is_active: bool) -> void:
	_unit = unit
	_is_active = is_active
	
	var mat := portrait_rect.material as ShaderMaterial
	
	# AAA : Différenciation visuelle par faction
	var border_color := Color(0.85, 0.70, 0.25, 1.0) # Or Divin (Joueur)
	var ray_color := Color(1.0, 0.9, 0.5, 0.8) # Lumière Solaire
	
	if is_instance_valid(_unit):
		if _unit.faction == Unit.Faction.ENEMY:
			border_color = Color(0.45, 0.05, 0.15, 1.0) # Cramoisi Stygien / Sang Séché
			ray_color = Color(0.70, 0.10, 0.35, 0.8) # Feu du Tartare / Améthyste
		elif _unit.faction == Unit.Faction.ALLY:
			border_color = Color(0.20, 0.65, 0.60, 1.0) # Bronze Oxydé / Teal antique
			ray_color = Color(0.30, 0.85, 0.80, 0.8) # Lueur Élyséenne (Cyan)
			
	mat.set_shader_parameter("border_color", border_color)
	mat.set_shader_parameter("ray_color", ray_color)

	if is_instance_valid(_unit) and _unit.stats:
		tooltip_text = _unit.stats.unit_name # Renseigne la propriété native pour déclencher le survol
		if _unit.stats.portrait:
			mat.set_shader_parameter("portrait_tex", _unit.stats.portrait)
	else:
		mat.set_shader_parameter("portrait_tex", null)
		
	_animate_state()

# PRIVATE FUNCTIONS
func _animate_state() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
		
	_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SPRING).set_ease(Tween.EASE_OUT)
	var mat := portrait_rect.material as ShaderMaterial
	
	if _is_active:
		custom_minimum_size = Vector2(80, 80) # AAA : Ajustement parfait pour s'intégrer dans les 96px internes
		pivot_offset = Vector2(40, 40) # AAA : Recentrage dynamique du point de pivot
		_tween.tween_property(self, "scale", Vector2(1.15, 1.15), 0.3)
		_tween.tween_property(self, "modulate", Color.WHITE, 0.3)
		_tween.tween_property(mat, "shader_parameter/is_active", 1.0, 0.3)
	else:
		custom_minimum_size = Vector2(64, 64) # AAA : Taille de base augmentée pour une lisibilité parfaite
		pivot_offset = Vector2(32, 32) # AAA : Retour au pivot initial
		_tween.tween_property(self, "scale", Vector2.ONE, 0.3)
		_tween.tween_property(self, "modulate", Color(0.7, 0.7, 0.7, 0.9), 0.3) # S'assombrit légèrement
		_tween.tween_property(mat, "shader_parameter/is_active", 0.0, 0.3)

# SIGNAL HANDLERS
func _on_mouse_entered() -> void:
	if is_instance_valid(_unit) and GridEvents.has_signal("timeline_portrait_hovered"):
		GridEvents.timeline_portrait_hovered.emit(_unit, true)
		
	# AAA : On tween les éléments internes, JAMAIS la racine gérée par un BoxContainer
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_SPRING)
	if portrait_rect: tw.tween_property(portrait_rect, "position:y", -8.0, 0.2)

func _on_mouse_exited() -> void:
	if is_instance_valid(_unit) and GridEvents.has_signal("timeline_portrait_hovered"):
		GridEvents.timeline_portrait_hovered.emit(_unit, false)
		
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_SPRING)
	if portrait_rect: tw.tween_property(portrait_rect, "position:y", 0.0, 0.2)