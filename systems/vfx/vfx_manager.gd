extends Node

## Autoload gérant l'Object Pooling des particules pour éviter le Shader Stutter.

@export var vfx_library: Dictionary = {} # Clé: String (vfx_id), Valeur: PackedScene
@export var pool_size_per_vfx: int = 10

var _pools: Dictionary = {} # Clé: String (vfx_id), Valeur: Array[PooledVfx]

func _ready() -> void:
	CombatEvents.vfx_requested.connect(_on_vfx_requested)

	# Auto-instanciation des particules définies dans l'inspecteur
	for vfx_id: String in vfx_library:
		register_vfx(vfx_id, vfx_library[vfx_id])

func register_vfx(vfx_id: String, prefab: PackedScene) -> void:
	if _pools.has(vfx_id): return
	
	var pool: Array[PooledVfx] = []
	for i in range(pool_size_per_vfx):
		var instance := prefab.instantiate() as PooledVfx
		if instance:
			add_child(instance)
			pool.append(instance)
	_pools[vfx_id] = pool

func _on_vfx_requested(vfx_id: String, pos: Vector3, dir: Vector3, attached_target: Node3D) -> void:
	var vfx: PooledVfx = _get_available_vfx(vfx_id)
	if not vfx:
		return
		
	if is_instance_valid(attached_target):
		# Attachement dynamique : Le VFX suit l'unité (Idéal pour des auras, boucliers, etc.)
		var p = vfx.get_parent()
		if p: p.remove_child(vfx)
		attached_target.add_child(vfx)
		vfx.position = Vector3.ZERO # On centre la particule sur l'hôte
	else:
		# Placement global : Le VFX reste statique (Idéal pour une explosion au sol)
		vfx.global_position = pos
		
	if dir != Vector3.ZERO and not dir.is_equal_approx(Vector3.UP) and not dir.is_equal_approx(Vector3.DOWN):
		# Alignement mathématique (Gicle dans la direction opposée au coup)
		var target_look := vfx.global_position + dir
		vfx.look_at(target_look, Vector3.UP)
			
	vfx.play_vfx()

func _get_available_vfx(vfx_id: String) -> PooledVfx:
	if not _pools.has(vfx_id):
		return null
		
	for vfx: PooledVfx in _pools[vfx_id]:
		if not vfx.emitting:
			return vfx
	return null
