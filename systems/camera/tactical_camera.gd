## Gestionnaire de la caméra tactique avec déplacements sur grille, rotation orbitale et zoom
class_name TacticalCamera
extends Node3D

const ACTION_CAM_FORWARD = "camera_forward"
const ACTION_CAM_BACKWARD = "camera_backward"
const ACTION_CAM_LEFT = "camera_left"
const ACTION_CAM_RIGHT = "camera_right"
const ACTION_CAM_ROT_LEFT = "camera_rotate_left"
const ACTION_CAM_ROT_RIGHT = "camera_rotate_right"
const ACTION_CAM_ZOOM_IN = "camera_zoom_in"
const ACTION_CAM_ZOOM_OUT = "camera_zoom_out"
const ACTION_CAM_RESET = "camera_reset"

@export_category("Vitesse & Mouvement")
## Vitesse de déplacement panoramique sur l'axe horizontal
@export var move_speed: float = 15.0
## Vitesse de rotation autour de l'axe vertical Y
@export var rot_speed: float = 3.0
## Force d'interpolation pour adoucir les mouvements de la caméra
@export var smoothing: float = 8.0

@export_category("Zoom")
## Distance minimale de rapprochement de la caméra
@export var min_zoom: float = 10.0
## Distance maximale d'éloignement de la caméra
@export var max_zoom: float = 60.0
## Valeur ajoutée/soustraite à chaque cran de zoom
@export var zoom_step: float = 4.0

@onready var _spring_arm: SpringArm3D = $Elevation/SpringArm3D

## Variables de cibles pour l'interpolation (Game Feel / Smoothing)
var _target_position: Vector3 = Vector3.ZERO
var _target_rotation: float = 0.0
var _target_zoom: float = 30.0

func _ready() -> void:
	_target_position = position
	_target_rotation = rotation.y
	
	if not is_instance_valid(_spring_arm):
		push_error("TacticalCamera: Nœud SpringArm3D manquant dans la hiérarchie.")
		return
		
	_target_zoom = _spring_arm.spring_length
		
	# AAA : Le "Regard Divin" (Auto-Panning)
	TurnEvents.active_unit_changed.connect(_on_active_unit_changed)

func _on_active_unit_changed(unit: Unit) -> void:
	if not is_instance_valid(unit):
		return
		
	# Recadre la cible de la caméra sur l'unité active. Le _apply_smoothing fera glisser la caméra en douceur.
	_target_position = unit.global_position

func _process(delta: float) -> void:
	_handle_movement(delta)
	_handle_rotation(delta)
	_apply_smoothing(delta)

func _unhandled_input(event: InputEvent) -> void:
	# Gestion du zoom et du recentrage via nos actions personnalisées de l'Input Map
	if event.is_action_pressed(ACTION_CAM_ZOOM_IN):
		_target_zoom = clampf(_target_zoom - zoom_step, min_zoom, max_zoom)
	elif event.is_action_pressed(ACTION_CAM_ZOOM_OUT):
		_target_zoom = clampf(_target_zoom + zoom_step, min_zoom, max_zoom)
	elif event.is_action_pressed(ACTION_CAM_RESET):
		# TODO: Placeholder pour recentrer la caméra sur l'unité active plus tard
		pass

func _handle_movement(delta: float) -> void:
	# Récupère les entrées directionnelles découplées de l'interface (DDD)
	var input_dir: Vector2 = Input.get_vector(ACTION_CAM_LEFT, ACTION_CAM_RIGHT, ACTION_CAM_FORWARD, ACTION_CAM_BACKWARD)
	
	if input_dir == Vector2.ZERO:
		return
		
	# Calcul des axes relatifs à la rotation Y actuelle de la caméra
	var forward: Vector3 = -transform.basis.z
	var right: Vector3 = transform.basis.x
	
	# Contrainte stricte sur le plan XZ (pas de vol)
	forward.y = 0.0
	right.y = 0.0
	forward = forward.normalized()
	right = right.normalized()
	
	# input_dir.y est négatif quand "ui_up" est pressé. On l'inverse pour avancer (forward).
	var move_dir: Vector3 = (right * input_dir.x + forward * -input_dir.y).normalized()
	_target_position += move_dir * move_speed * delta

func _handle_rotation(delta: float) -> void:
	# Remarque : Tu devras ajouter ces deux actions virtuelles dans l'Input Map de Godot.
	var rot_dir: float = Input.get_axis(ACTION_CAM_ROT_LEFT, ACTION_CAM_ROT_RIGHT)
	
	if rot_dir == 0.0:
		return
		
	# Soustraction pour qu'appuyer à droite fasse tourner la caméra vers la droite autour du centre
	_target_rotation -= rot_dir * rot_speed * delta

func _apply_smoothing(delta: float) -> void:
	# Interpolation de la position panoramique
	position = position.lerp(_target_position, smoothing * delta)
	
	# Interpolation de la rotation orbitale (lerp_angle gère proprement le passage de 359° à 0°)
	rotation.y = lerp_angle(rotation.y, _target_rotation, smoothing * delta)
	
	# Interpolation de la distance de zoom
	if not is_instance_valid(_spring_arm):
		return
		
	_spring_arm.spring_length = lerp(_spring_arm.spring_length, _target_zoom, smoothing * delta)