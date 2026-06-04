class_name FloatingText
extends Label

## Composant visuel d'un texte flottant. Géré par le FloatingTextManager (Object Pool).

# PUBLIC FUNCTIONS
func animate(start_pos: Vector2, text_val: String, color: Color) -> void:
	position = start_pos
	text = text_val
	modulate = color
	modulate.a = 1.0
	visible = true
	
	# Effet AAA : Léger décalage aléatoire pour éviter que les textes se superposent en cas d'AoE
	var random_offset := Vector2(randf_range(-20.0, 20.0), randf_range(-10.0, 10.0))
	position += random_offset
	
	var target_pos: Vector2 = position + Vector2(0, -60) # Flotte vers le haut
	
	var tween := create_tween()
	tween.set_parallel(true)
	# Montée fluide avec ralentissement (Ease Out)
	tween.tween_property(self, "position", target_pos, 0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	# Fondu transparent
	tween.tween_property(self, "modulate:a", 0.0, 0.8).set_trans(Tween.TRANS_LINEAR).set_delay(0.2)
	
	# Fin de l'animation : Le texte se rend invisible (retourne au Pool)
	tween.chain().tween_callback(hide)