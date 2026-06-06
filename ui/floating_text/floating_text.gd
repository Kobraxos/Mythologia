class_name FloatingText
extends Label

## Composant visuel d'un texte flottant. Géré par le FloatingTextManager (Object Pool).

# PRIVATE VARIABLES
var _target: Node3D
var _camera: Camera3D
var _base_offset: Vector2
var _float_offset: Vector2
var _height_offset: float = 2.0

func _ready() -> void:
	set_process(false) # Désactivé par défaut (Object Pool AAA)

# PUBLIC FUNCTIONS
func animate(target_node: Node3D, cam: Camera3D, text_val: String, text_color: Color, height_offset: float, is_crit: bool = false, is_dodge: bool = false) -> void:
	_target = target_node
	_camera = cam
	_height_offset = height_offset
	
	text = text_val
	modulate = text_color
	modulate.a = 1.0
	visible = true
	set_process(true)
	
	# AAA VFX : Centrage du pivot pour permettre un effet d'impact (Scale) depuis le centre
	pivot_offset = size / 2.0
	
	var initial_scale := Vector2.ONE if is_dodge else (Vector2(1.8, 1.8) if is_crit else Vector2(1.2, 1.2))
	var final_scale := Vector2(1.2, 1.2) if is_crit else Vector2.ONE
	var anim_duration: float = 0.6 if is_dodge else (1.2 if is_crit else 0.8)
	var float_dist: float = -10.0 if is_dodge else (-70.0 if is_crit else -40.0)
	var horizontal_slide: float = 50.0 if is_dodge else 0.0
	
	scale = initial_scale

	# Effet AAA : Léger décalage aléatoire pour éviter que les textes se superposent en cas d'AoE
	_base_offset = Vector2(randf_range(-20.0, 20.0), randf_range(-10.0, 10.0))
	_float_offset = Vector2.ZERO
	var random_sign: float = 1.0 if randf() > 0.5 else -1.0
	
	var tween := create_tween()
	tween.set_parallel(true)
	
	# 1. Pop In (Impact violent élastique)
	if not is_dodge:
		tween.tween_property(self, "scale", final_scale, 0.4).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	
	# 2. Montée fluide avec ralentissement
	tween.tween_property(self, "_float_offset", Vector2(0, float_dist), anim_duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	# 2.5. Glissement horizontal furtif (Exclusif à l'esquive)
	if is_dodge:
		tween.tween_property(self, "_base_offset:x", _base_offset.x + (horizontal_slide * random_sign), anim_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	# 3. Disparition (Fade out) uniquement sur la dernière portion de l'animation
	tween.tween_property(self, "modulate:a", 0.0, anim_duration * 0.4).set_trans(Tween.TRANS_LINEAR).set_delay(anim_duration * 0.6)
	
	# Fin de l'animation : Le texte se rend invisible (retourne au Pool)
	tween.chain().tween_callback(func() -> void:
		hide()
		set_process(false)
	)

func _process(_delta: float) -> void:
	if is_instance_valid(_target) and is_instance_valid(_camera):
		var world_pos: Vector3 = _target.global_position + Vector3(0, _height_offset, 0)
		if not _camera.is_position_behind(world_pos):
			position = _camera.unproject_position(world_pos) + _base_offset + _float_offset