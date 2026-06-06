class_name PooledVfx
extends GPUParticles3D

## Composant AAA attaché à un effet visuel (particules) pour permettre son recyclage.

func _ready() -> void:
	emitting = false
	one_shot = true # Requis pour que le signal "finished" s'émette de lui-même
	if not finished.is_connected(_on_finished):
		finished.connect(_on_finished)

func play_vfx() -> void:
	restart()

func _on_finished() -> void:
	# Sécurité absolue : Si le VFX a été attaché (parenté dynamiquement) à une unité mobile, 
	# on le remet dans l'Autoload global pour éviter qu'il ne meure avec elle ou s'égare.
	var vfx_manager = get_tree().root.get_node_or_null("VfxManager")
	
	if vfx_manager and get_parent() != vfx_manager:
		get_parent().remove_child(self)
		vfx_manager.add_child(self)
		# Reset des transforms de sécurité optionnel ici
