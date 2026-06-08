class_name PooledVfx
extends GPUParticles3D

## Composant AAA attaché à un effet visuel (particules) pour permettre son recyclage.

func _ready() -> void:
	emitting = false
	one_shot = true # Requis pour que le signal "finished" s'émette de lui-même

func play_vfx() -> void:
	restart()
