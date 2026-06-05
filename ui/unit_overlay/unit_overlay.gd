class_name UnitOverlay
extends Control

@export var hp_bar: ProgressBar

@export_category("Depth Scaling")
## La distance (ou taille de caméra) où l'échelle est exactement à 100%.
@export var reference_distance: float = 15.0
## Échelle minimum (Zoom arrière max).
@export var min_scale: float = 0.5
## Échelle maximum (Zoom avant max).
@export var max_scale: float = 2.0

@export_category("Positioning")
## Hauteur en mètres au-dessus du point d'origine de l'unité (ajuster selon la taille du sprite 2D).
@export var height_offset: float = 2.5

var _target: Unit
var _camera: Camera3D

func setup(unit: Unit) -> void:
	_target = unit
	_camera = get_viewport().get_camera_3d()
	
	# Branchement dynamique au composant de vie
	if _target.health_component:
		# Duck-typing sécurisé pour éviter un crash si le signal s'appelle autrement chez toi
		if _target.health_component.has_signal("health_changed"):
			_target.health_component.connect("health_changed", _on_health_changed)
		
		# Initialisation immédiate (Requiert des getters dans ton HealthComponent)
		if _target.health_component.has_method("get_current_health") and _target.health_component.has_method("get_max_health"):
			_on_health_changed(_target.health_component.get_current_health(), _target.health_component.get_max_health())
			
	if hp_bar:
		var fill_style := StyleBoxFlat.new()
		# AAA UX : La barre de vie reste universellement rouge pour la clarté cognitive
		fill_style.bg_color = Color(0.8, 0.15, 0.15)
		hp_bar.add_theme_stylebox_override("fill", fill_style)
		
		var bg_style := StyleBoxFlat.new()
		bg_style.bg_color = Color(0.1, 0.1, 0.1, 0.8) # Fond de la barre assombri pour le contraste
		# AAA UX : La couleur de faction est subtilement reléguée à la bordure du conteneur
		bg_style.border_width_left = 2
		bg_style.border_width_top = 2
		bg_style.border_width_right = 2
		bg_style.border_width_bottom = 2
		bg_style.border_color = Color(0.1, 0.1, 0.1) # Bordure noire/neutre
		hp_bar.add_theme_stylebox_override("background", bg_style)
			
	# AAA : Le pivot au centre garantit que le zoom s'applique uniformément depuis le milieu de la barre
	pivot_offset = size / 2.0

func _process(_delta: float) -> void:
	if not is_instance_valid(_target) or not is_instance_valid(_camera):
		queue_free()
		return
		
	# Calcul de la projection AAA avec offset ajustable pour les sprites 2D
	var world_pos: Vector3 = _target.global_position + Vector3(0, height_offset, 0)
	
	# AAA : Si l'unité est cachée (ex: elle est morte), on cache l'overlay
	if not _target.visible or _camera.is_position_behind(world_pos):
		visible = false
	else:
		visible = true
		
		# AAA : Calcul de l'échelle par rapport à la profondeur (Depth Scaling)
		var scale_factor: float = 1.0
		if _camera.projection == Camera3D.PROJECTION_ORTHOGONAL:
			scale_factor = reference_distance / _camera.size
		else:
			var dist: float = _camera.global_position.distance_to(world_pos)
			scale_factor = reference_distance / dist
			
		scale = Vector2.ONE * clamp(scale_factor, min_scale, max_scale)
		
		# On centre le Control sur le point projeté
		position = _camera.unproject_position(world_pos) - (size / 2.0)

func _on_health_changed(current: int, max_val: int) -> void:
	if hp_bar:
		hp_bar.max_value = max_val
		hp_bar.value = current
