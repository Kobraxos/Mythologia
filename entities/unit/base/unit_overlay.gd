class_name UnitOverlay
extends Control

@export var hp_bar: ProgressBar

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

func _process(_delta: float) -> void:
	if not is_instance_valid(_target) or not is_instance_valid(_camera):
		queue_free()
		return
		
	# Calcul de la projection AAA (Décalage de 2.5 mètres au-dessus de l'unité)
	var world_pos: Vector3 = _target.global_position + Vector3(0, 2.5, 0)
	
	if _camera.is_position_behind(world_pos):
		visible = false
	else:
		visible = true
		# On centre le Control sur le point projeté
		position = _camera.unproject_position(world_pos) - (size / 2.0)

func _on_health_changed(current: int, max_val: int) -> void:
	if hp_bar:
		hp_bar.max_value = max_val
		hp_bar.value = current