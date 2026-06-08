extends Node

## Autoload gérant l'Object Pooling des particules pour éviter le Shader Stutter.

@export var vfx_library: Dictionary = {} # Clé: int (CoreEnums.VfxType), Valeur: PackedScene
@export var pool_size_per_vfx: int = 10

var _pools: Dictionary = {} # Clé: int (CoreEnums.VfxType), Valeur: Array[PooledVfx]

func _ready() -> void:
	CombatEvents.vfx_requested.connect(_on_vfx_requested)

	# Auto-instanciation des particules définies dans l'inspecteur
	for vfx_type: int in vfx_library:
		register_vfx(vfx_type, vfx_library[vfx_type] as PackedScene)

func register_vfx(vfx_type: int, prefab: PackedScene) -> void:
	if _pools.has(vfx_type): return
	
	var pool: Array[PooledVfx] = []
	for i in range(pool_size_per_vfx):
		var instance := _instantiate_vfx(prefab)
		if instance:
			pool.append(instance)
	_pools[vfx_type] = pool

func _instantiate_vfx(prefab: PackedScene) -> PooledVfx:
	if not prefab: return null
	
	var instance := prefab.instantiate() as PooledVfx
	if not instance:
		push_error("Failed to instantiate VFX prefab.")
		return null
		
	add_child(instance)
	
	if not instance.finished.is_connected(_on_vfx_finished.bind(instance)):
		instance.finished.connect(_on_vfx_finished.bind(instance))
		
	return instance

func _on_vfx_requested(vfx_type: int, pos: Vector3, dir: Vector3, attached_target: Node3D) -> void:
	var vfx: PooledVfx = _get_available_vfx(vfx_type)
	if not vfx:
		return
		
	if is_instance_valid(attached_target):
		# Attachement dynamique : Le VFX suit l'unité (Idéal pour des auras, boucliers, etc.)
		var p: Node = vfx.get_parent()
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
			
	# Assurez-vous que le VFX est actif si on gère la visibilité
	vfx.visible = true
	vfx.process_mode = Node.PROCESS_MODE_INHERIT
	vfx.play_vfx()

func _get_available_vfx(vfx_type: int) -> PooledVfx:
	if not _pools.has(vfx_type):
		return null
		
	# On cherche une particule disponible
	for vfx: PooledVfx in _pools[vfx_type]:
		if not vfx.emitting:
			return vfx
			
	# Expansion dynamique du pool si tout est utilisé
	push_warning("Pool expanded dynamically for VFX type: %s" % vfx_type)
	var prefab: PackedScene = vfx_library.get(vfx_type)
	if prefab:
		var instance := _instantiate_vfx(prefab)
		if instance:
			_pools[vfx_type].append(instance)
			return instance
			
	return null

func _on_vfx_finished(vfx: PooledVfx) -> void:
	if vfx.get_parent() != self:
		vfx.call_deferred("reparent", self)
	
	# Optionnel : désactiver le nœud pour gagner en performance
	vfx.visible = false
	vfx.process_mode = Node.PROCESS_MODE_DISABLED
