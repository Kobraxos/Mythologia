extends Node

## Le CombatVisualInterpreter est "l'Oreille" et "l'Architecte Visuel".
## Il écoute les événements bruts du combat en 0 ms, construit une file d'attente
## de VisualCommand, et déploie le CombatSequencer.

const DASH_ANIM_DURATION := 0.3
const LEAP_ANIM_DURATION := 0.4
const MULTI_HIT_DELAY := 0.3

var _is_recording := false
var _sequence: Array[VisualCommandGroup] = []
var _current_group: VisualCommandGroup = null

var _caster: Node3D
var _skill: SkillData
var _target_hex: Vector3i

func _ready() -> void:
	CombatEvents.skill_execution_started.connect(_on_execution_started)
	CombatEvents.skill_hit_started.connect(_on_hit_started)
	CombatEvents.skill_execution_finished.connect(_on_execution_finished)
	
	CombatEvents.damage_dealt.connect(_on_damage_dealt)
	CombatEvents.healing_done.connect(_on_healing_done)
	CombatEvents.shield_granted.connect(_on_shield_granted)
	CombatEvents.attack_dodged.connect(_on_attack_dodged)
	GridEvents.unit_moved.connect(_on_unit_moved)

func _on_execution_started(caster: Node3D, skill: SkillData, target_hex: Vector3i) -> void:
	_is_recording = true
	_sequence.clear()
	_current_group = null
	
	_caster = caster
	_skill = skill
	_target_hex = target_hex
	
	# Groupe initial pour les mouvements du lanceur (pré-frappe)
	_current_group = VisualCommandGroup.new()

func _on_hit_started(hit_index: int) -> void:
	if not _is_recording: return
	
	if _current_group and not _current_group.commands.is_empty():
		_sequence.append(_current_group)
		
	_current_group = VisualCommandGroup.new()
	
	var anim_cmd := VisualCommand.new()
	anim_cmd.type = VisualCommand.Type.PLAY_ANIMATION
	anim_cmd.target = _caster
	anim_cmd.string_payload = _skill.animation_trigger
	anim_cmd.duration = MULTI_HIT_DELAY
	_current_group.commands.append(anim_cmd)

func _on_execution_finished() -> void:
	if not _is_recording: return
	
	if _current_group and not _current_group.commands.is_empty():
		_sequence.append(_current_group)
		
	_is_recording = false
	_current_group = null
	
	if not _sequence.is_empty():
		var sequencer := CombatSequencer.new()
		get_tree().root.add_child(sequencer) # Ou l'ajouter en enfant de ce nœud
		sequencer.play_sequence(_sequence, _caster, _skill, _target_hex)
	else:
		# Fallback de sécurité si aucun effet visuel n'a été produit
		CombatEvents.skill_resolved.emit(_caster, _skill, _target_hex)

# --- TRADUCTION DES ÉVÉNEMENTS LOGIQUES EN COMMANDES VISUELLES ---

func _on_damage_dealt(target: Node3D, amount: int, is_crit: bool) -> void:
	if not _is_recording or not _current_group: return
	
	var cmd := VisualCommand.new()
	cmd.type = VisualCommand.Type.DAMAGE_NUMBER
	cmd.target = target
	cmd.int_payload = amount
	cmd.element_payload = _skill.skill_element
	cmd.text_type = CoreEnums.FloatingTextType.CRIT if is_crit else CoreEnums.FloatingTextType.DAMAGE
	_current_group.commands.append(cmd)
	
	var hp_cmd := VisualCommand.new()
	hp_cmd.type = VisualCommand.Type.UPDATE_HEALTH_BAR
	hp_cmd.target = target
	var unit := target as Unit
	if is_instance_valid(unit) and unit.health_component:
		hp_cmd.int_payload = unit.health_component.get_current_health()
	_current_group.commands.append(hp_cmd)
	
	var vfx_cmd := VisualCommand.new()
	vfx_cmd.type = VisualCommand.Type.SPAWN_VFX
	vfx_cmd.vfx_type = CoreEnums.VfxType.IMPACT_HIT
	vfx_cmd.target = target
	vfx_cmd.source = _caster
	_current_group.commands.append(vfx_cmd)

func _on_healing_done(target: Node3D, amount: int) -> void:
	if not _is_recording or not _current_group: return
	
	var cmd := VisualCommand.new()
	cmd.type = VisualCommand.Type.DAMAGE_NUMBER
	cmd.target = target
	cmd.int_payload = amount
	cmd.text_type = CoreEnums.FloatingTextType.HEAL
	_current_group.commands.append(cmd)
	
	var hp_cmd := VisualCommand.new()
	hp_cmd.type = VisualCommand.Type.UPDATE_HEALTH_BAR
	hp_cmd.target = target
	var unit := target as Unit
	if is_instance_valid(unit) and unit.health_component:
		hp_cmd.int_payload = unit.health_component.get_current_health()
	_current_group.commands.append(hp_cmd)
	
	var vfx_cmd := VisualCommand.new()
	vfx_cmd.type = VisualCommand.Type.SPAWN_VFX
	vfx_cmd.vfx_type = CoreEnums.VfxType.HEAL_EFFECT
	vfx_cmd.target = target
	vfx_cmd.direction_payload = Vector3.UP
	_current_group.commands.append(vfx_cmd)

func _on_shield_granted(target: Node3D, amount: int) -> void:
	if not _is_recording or not _current_group: return
	
	var cmd := VisualCommand.new()
	cmd.type = VisualCommand.Type.DAMAGE_NUMBER
	cmd.target = target
	cmd.int_payload = amount
	cmd.text_type = CoreEnums.FloatingTextType.SHIELD
	_current_group.commands.append(cmd)
	
	var hp_cmd := VisualCommand.new()
	hp_cmd.type = VisualCommand.Type.UPDATE_HEALTH_BAR
	hp_cmd.target = target
	var unit := target as Unit
	if is_instance_valid(unit) and unit.health_component:
		hp_cmd.int_payload = unit.health_component.get_current_health()
	_current_group.commands.append(hp_cmd)
	
	var vfx_cmd := VisualCommand.new()
	vfx_cmd.type = VisualCommand.Type.SPAWN_VFX
	vfx_cmd.vfx_type = CoreEnums.VfxType.SHIELD_GRANTED
	vfx_cmd.target = target
	vfx_cmd.direction_payload = Vector3.UP
	_current_group.commands.append(vfx_cmd)

func _on_attack_dodged(target: Node3D) -> void:
	if not _is_recording or not _current_group: return
	
	var cmd := VisualCommand.new()
	cmd.type = VisualCommand.Type.DAMAGE_NUMBER
	cmd.target = target
	cmd.text_type = CoreEnums.FloatingTextType.DODGE
	_current_group.commands.append(cmd)
	
	var vfx_cmd := VisualCommand.new()
	vfx_cmd.type = VisualCommand.Type.SPAWN_VFX
	vfx_cmd.vfx_type = CoreEnums.VfxType.DODGE_DUST
	vfx_cmd.target = target
	_current_group.commands.append(vfx_cmd)

func _on_unit_moved(unit: Node, _from_hex: Vector3i, to_hex: Vector3i) -> void:
	if not _is_recording or not _current_group: return
	
	var cmd := VisualCommand.new()
	cmd.type = VisualCommand.Type.FORCED_MOVEMENT
	cmd.target = unit as Node3D
	cmd.target_hex = to_hex
	
	# Est-ce le lanceur qui se déplace avant de frapper ?
	if unit == _caster:
		if _skill.caster_movement == SkillData.CasterMovement.DASH_TO_TARGET:
			cmd.duration = DASH_ANIM_DURATION
			_add_movement_vfx(unit as Node3D, to_hex, CoreEnums.VfxType.DASH_TRAIL)
		elif _skill.caster_movement == SkillData.CasterMovement.LEAP_TO_TARGET:
			cmd.duration = LEAP_ANIM_DURATION
			cmd.is_leap = true
			_add_movement_vfx(unit as Node3D, to_hex, CoreEnums.VfxType.LEAP_TRAIL)
		elif _skill.caster_movement == SkillData.CasterMovement.TELEPORT_TO_TARGET:
			cmd.duration = 0.0
			var vfx_out := VisualCommand.new()
			vfx_out.type = VisualCommand.Type.SPAWN_VFX
			vfx_out.vfx_type = CoreEnums.VfxType.TELEPORT_OUT
			vfx_out.target = unit as Node3D
			_current_group.commands.append(vfx_out)
			_add_movement_vfx(unit as Node3D, to_hex, CoreEnums.VfxType.TELEPORT_IN)
	else:
		# C'est un déplacement forcé de la cible (Knockback / Pull)
		cmd.duration = DASH_ANIM_DURATION
		_add_movement_vfx(unit as Node3D, to_hex, CoreEnums.VfxType.DASH_TRAIL)
		
	_current_group.commands.append(cmd)

func _add_movement_vfx(target: Node3D, target_hex: Vector3i, vfx_type: int) -> void:
	var vfx_cmd := VisualCommand.new()
	vfx_cmd.type = VisualCommand.Type.SPAWN_VFX
	vfx_cmd.vfx_type = vfx_type
	vfx_cmd.target = target
	vfx_cmd.target_hex = target_hex
	_current_group.commands.append(vfx_cmd)
